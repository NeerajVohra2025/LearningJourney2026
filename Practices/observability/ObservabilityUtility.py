"""Provide shared observability for responsible GenAI applications.

Orchestrators, agents and governed tools use this module to keep one business
request connected across every participating service. It carries trace and
business identifiers, validates structured events, protects log content through
the enterprise DLP service and can write protected entries to Google Cloud
Logging.

The utility works with standard Python mappings and models. Business code does
not need to depend on FastAPI, OpenTelemetry or a specific agent framework.
Applications decide which events matter. This utility keeps their identifiers
consistent and manages the Google Cloud Logging boundary.

The utility exports a span only when the service explicitly calls
``write_trace_span``. It does not calculate model prices, retry failed provider
calls or make business-policy decisions. Prompts, model responses,
credentials, authorization headers and complete tool results must never be
included in log payloads.
"""

from __future__ import annotations

import json
import re
from collections.abc import Callable, Mapping
from datetime import UTC, datetime
from threading import Lock
from typing import Any, Literal, Protocol
from uuid import uuid4

from google.api_core.exceptions import GoogleAPICallError, RetryError
from google.auth.exceptions import GoogleAuthError
from google.cloud import logging as cloud_logging
from google.cloud import trace_v2
from pydantic import BaseModel, ConfigDict, Field, model_validator


# Standard values keep dashboards, alerts and audit reports consistent.
Severity = Literal["DEBUG", "INFO", "WARNING", "ERROR", "CRITICAL"]
Outcome = Literal["success", "rejected", "failure", "partial"]
LoggingFailureMode = Literal["continue", "raise"]


class DlpUtilityProtocol(Protocol):
    """Define the DLP operation required before a log can be written."""

    def deidentify_content(self, text: str) -> str:
        """Return text protected by the enterprise DLP policy."""
        ...

# Compile the approved header formats once and reject partial matches.
TRACEPARENT = re.compile(
    r"^(?P<version>[0-9a-f]{2})-(?P<trace>[0-9a-f]{32})-"
    r"(?P<span>[0-9a-f]{16})-(?P<flags>[0-9a-f]{2})$"
)
CLOUD_TRACE = re.compile(
    r"^(?P<trace>[0-9a-f]{32})/(?P<span>[0-9]{1,20})(?:;o=(?P<sampled>[01]))?$"
)

# Technical lineage must remain exact and searchable. These values are created
# by the utility from validated context and must never be changed by DLP.
TECHNICAL_LINEAGE_FIELDS = frozenset(
    {
        "trace_id",
        "span_id",
        "parent_span_id",
        "logging.googleapis.com/trace",
        "logging.googleapis.com/spanId",
        "timestamp",
        "severity",
        "event_name",
        "logger",
        "current_service",
        "parent_service",
        "operation",
        "outcome",
        "agent_name",
        "agent_framework",
        "tool_name",
        "target_system",
        "downstream_service",
        "model_provider",
        "model_name",
        "error_code",
    }
)


class InvalidTraceContextError(ValueError):
    """Report missing or invalid trace information without exposing its value.

    The exception message identifies the invalid header category but never
    repeats the supplied header value. Applications can therefore report the
    failure without accidentally copying untrusted input into a log.
    """


class FrozenModel(BaseModel):
    """Provide validated records that cannot change after creation.

    Unknown fields are rejected and validated instances cannot be changed.
    A service creates a new record when the request moves to its next stage.
    Earlier operational evidence remains unchanged.
    """

    model_config = ConfigDict(frozen=True, extra="forbid")


class TraceContext(FrozenModel):
    """Identify the current service step within an end-to-end trace.

    The model stores W3C-compatible identifiers without depending on a tracing
    SDK. The trace ID remains the same for the complete business journey. Each
    service receives its own span ID and retains the previous span as its
    parent.

    Attributes:
        trace_id: Lowercase 32-character hexadecimal distributed trace ID.
        span_id: Lowercase 16-character hexadecimal ID for the current span.
        parent_span_id: Optional span ID belonging to the upstream service.
        trace_flags: W3C trace options, including the sampling decision.
        tracestate: Optional provider information forwarded unchanged.
    """

    trace_id: str = Field(pattern=r"^[0-9a-f]{32}$")
    span_id: str = Field(pattern=r"^[0-9a-f]{16}$")
    parent_span_id: str | None = Field(default=None, pattern=r"^[0-9a-f]{16}$")
    trace_flags: str = Field(default="00", pattern=r"^[0-9a-f]{2}$")
    tracestate: str | None = Field(default=None, max_length=512)

    @model_validator(mode="after")
    def reject_reserved_zero_identifiers(self) -> "TraceContext":
        """Reject the all-zero identifiers that W3C reserves as invalid.

        Returns:
            The validated immutable context.

        Raises:
            ValueError: If the trace ID, current span ID, or supplied parent
                span ID contains only zeros.
        """

        if int(self.trace_id, 16) == 0 or int(self.span_id, 16) == 0:
            raise ValueError("trace and span identifiers cannot be all zeros")
        if self.parent_span_id and int(self.parent_span_id, 16) == 0:
            raise ValueError("parent span identifier cannot be all zeros")
        return self

    @property
    def sampled(self) -> bool:
        """Report whether the upstream service selected this trace for sampling.

        Returns:
            ``True`` when bit zero of ``trace_flags`` is set; otherwise
            ``False``. This utility preserves the upstream decision.
        """

        return bool(int(self.trace_flags, 16) & 1)

    @property
    def traceparent(self) -> str:
        """Build the standard W3C header for the next service call.

        Returns:
            A ``00-<trace-id>-<span-id>-<flags>`` header value ready for the
            next downstream HTTP request.
        """

        return f"00-{self.trace_id}-{self.span_id}-{self.trace_flags}"

    def child(self) -> "TraceContext":
        """Keep the journey trace ID and create a span for the next service.

        Returns:
            A new immutable context whose parent is this context's current
            span. Trace flags and trace state are preserved.

        Notes:
            This creates identifiers only. It does not send a span to Cloud
            Trace or measure elapsed time.
        """

        return TraceContext(
            trace_id=self.trace_id,
            parent_span_id=self.span_id,
            span_id=uuid4().hex[:16],
            trace_flags=self.trace_flags,
            tracestate=self.tracestate,
        )

    @classmethod
    def root(cls, *, sampled: bool = False) -> "TraceContext":
        """Start a new trace when the caller did not provide one.

        Args:
            sampled: Whether the new root should set the W3C sampled bit.

        Returns:
            A new root context with secure random trace and span identifiers
            and no parent span.

        Notes:
            Service configuration decides whether a missing trace may start a
            new journey. ``GenAIObservabilityUtility`` applies that decision.
        """

        return cls(
            trace_id=uuid4().hex,
            span_id=uuid4().hex[:16],
            trace_flags="01" if sampled else "00",
        )


class BusinessContext(FrozenModel):
    """Carry the business identity shared by the complete workflow.

    The Business Orchestrator creates this context once and propagates it to
    every selected agent and tool wrapper. These identifiers support business
    audit, reporting and incident investigation. They complement, but do not
    replace, the technical identifiers used for distributed tracing.

    Attributes:
        execution_id: Identifies one complete workflow run.
        correlation_id: Connects related events for support and reporting.
        request_id: Identifies the original application request.
        tenant_id: Identifies the approved tenant or business boundary.
        business_process: Names the governed business workflow.
        user_id: Identifies the calling user or workload, never an access token.
        conversation_id: Optionally identifies a multi-turn conversation.
        incident_number: Optionally identifies the related business incident.
    """

    execution_id: str = Field(default_factory=lambda: uuid4().hex, min_length=1, max_length=128)
    correlation_id: str = Field(default_factory=lambda: uuid4().hex, min_length=1, max_length=128)
    request_id: str = Field(default_factory=lambda: uuid4().hex, min_length=1, max_length=128)
    tenant_id: str = Field(min_length=1, max_length=128)
    business_process: str = Field(min_length=1, max_length=128)
    user_id: str = Field(min_length=1, max_length=128)
    conversation_id: str | None = Field(default=None, min_length=1, max_length=128)
    incident_number: str | None = Field(default=None, min_length=1, max_length=128)


class ObservabilityContext(FrozenModel):
    """Combine technical tracing and business identity for one service step.

    A service creates this record when work arrives and passes it through the
    application. It is independent of web, agent and logging frameworks, so the
    same contract supports HTTP services, background workers and embedded use.

    Attributes:
        trace: Locates the service within the distributed trace.
        business: Business identity shared across the workflow.
        parent_service: Optional name of the authenticated upstream service.
        current_service: Stable name of the service performing the work.
        current_operation: Optional name of the current operation.
        current_agent: Optional name of the responsible agent.
        current_step: Optional workflow step name or number.
        started_at: UTC time when this service context was created.
    """

    trace: TraceContext
    business: BusinessContext
    parent_service: str | None = Field(default=None, min_length=1, max_length=128)
    current_service: str = Field(min_length=1, max_length=128)
    current_operation: str | None = Field(default=None, min_length=1, max_length=128)
    current_agent: str | None = Field(default=None, min_length=1, max_length=128)
    current_step: str | None = Field(default=None, min_length=1, max_length=128)
    started_at: datetime = Field(default_factory=lambda: datetime.now(UTC))


class EnterpriseLogPayload(FrozenModel):
    """Define the common, audit-safe information required for every event.

    The payload contains business-safe operational evidence. The utility adds
    Google trace fields only when it prepares the final log entry.

    Attributes:
        timestamp: UTC time at which the payload model was created.
        severity: Operational importance of the event.
        event_name: Stable name used by searches, dashboards and alerts.
        message: Short, non-sensitive summary for support teams.
        logger: Name of the component that produced the event.
        execution_id: Identifies the complete workflow run.
        correlation_id: Connects events across services.
        request_id: Identifies the original request.
        tenant_id: Identifies the approved tenant boundary.
        business_process: Names the governed workflow.
        parent_service: Names the upstream service when one exists.
        current_service: Names the service that owns the event.
        conversation_id: Optionally identifies a conversation.
        incident_number: Optionally identifies a business incident.
    """

    timestamp: datetime = Field(default_factory=lambda: datetime.now(UTC))
    severity: Severity
    event_name: str = Field(min_length=1, pattern=r"^[a-z0-9]+(?:[._-][a-z0-9]+)*$")
    message: str = Field(min_length=1, max_length=256)
    logger: str = Field(min_length=1, max_length=256)
    execution_id: str = Field(min_length=1, max_length=128)
    correlation_id: str = Field(min_length=1, max_length=128)
    request_id: str = Field(min_length=1, max_length=128)
    tenant_id: str = Field(min_length=1, max_length=128)
    business_process: str = Field(min_length=1, max_length=128)
    parent_service: str | None = Field(default=None, min_length=1, max_length=128)
    current_service: str = Field(min_length=1, max_length=128)
    conversation_id: str | None = Field(default=None, min_length=1, max_length=128)
    incident_number: str | None = Field(default=None, min_length=1, max_length=128)

    @classmethod
    def common_fields(
        cls,
        context: ObservabilityContext,
        *,
        severity: Severity,
        event_name: str,
        message: str,
        logger_name: str,
    ) -> dict[str, object]:
        """Copy the approved common fields from the current request context.

        Args:
            context: Validated context for the current service step.
            severity: Operational importance of the event.
            event_name: Stable event identifier such as
                ``agent.inference.completed``.
            message: Short, non-sensitive description for support teams.
            logger_name: Component that owns the event.

        Returns:
            Common values ready for a platform, agent or tool event.

        Notes:
            This method copies approved identifiers only. It never copies HTTP headers,
            prompts, model responses, tool payloads, or credentials.
        """

        business = context.business
        return {
            "severity": severity,
            "event_name": event_name,
            "message": message,
            "logger": logger_name,
            "execution_id": business.execution_id,
            "correlation_id": business.correlation_id,
            "request_id": business.request_id,
            "tenant_id": business.tenant_id,
            "business_process": business.business_process,
            "parent_service": context.parent_service,
            "current_service": context.current_service,
            "conversation_id": business.conversation_id,
            "incident_number": business.incident_number,
        }


class PlatformServiceLogPayload(EnterpriseLogPayload):
    """Describe an event from an orchestrator or other platform service.

    Attributes:
        operation: Stable name of the operation.
        outcome: Approved result category.
        downstream_service: Optional name of the selected downstream service.
        http_method: Optional HTTP method, without headers or body.
        http_path: Optional HTTP path, without query parameters.
        http_status: Optional HTTP response status.
        duration_ms: Optional elapsed time in milliseconds.
    """

    operation: str = Field(min_length=1, max_length=128)
    outcome: Outcome
    downstream_service: str | None = Field(default=None, min_length=1, max_length=128)
    http_method: str | None = Field(default=None, min_length=1, max_length=16)
    http_path: str | None = Field(default=None, pattern=r"^/", max_length=512)
    http_status: int | None = Field(default=None, ge=100, le=599)
    duration_ms: float | None = Field(default=None, ge=0)


class AgentLogPayload(EnterpriseLogPayload):
    """Describe responsible-agent activity without recording sensitive content.

    A service may include token counts reported by its model provider and costs
    calculated by its approved billing process. The utility validates supplied
    values but never estimates missing usage or pricing.

    Attributes:
        agent_name: Stable responsible-agent name.
        agent_framework: Runtime framework such as Google ADK or LangGraph.
        operation: Approved agent operation.
        outcome: Approved result category.
        downstream_service: Optional service selected by the agent.
        tool_name: Optional governed tool used by the agent.
        model_provider: Optional model provider name.
        model_name: Optional provider model identifier.
        input_tokens: Optional provider-reported input-token count.
        output_tokens: Optional provider-reported output-token count.
        total_tokens: Optional provider-reported total-token count.
        cost: Optional cost supplied by the approved billing process.
        cost_micros: Preferred exact cost in millionths of a currency unit.
        currency_code: Three-letter uppercase billing currency code.
        duration_ms: Optional elapsed time in milliseconds.
    """

    agent_name: str = Field(min_length=1, max_length=128)
    agent_framework: str = Field(min_length=1, max_length=64)
    operation: str = Field(min_length=1, max_length=128)
    outcome: Outcome
    downstream_service: str | None = Field(default=None, min_length=1, max_length=128)
    tool_name: str | None = Field(default=None, min_length=1, max_length=128)
    model_provider: str | None = Field(default=None, min_length=1, max_length=64)
    model_name: str | None = Field(default=None, min_length=1, max_length=128)
    input_tokens: int | None = Field(default=None, ge=0)
    output_tokens: int | None = Field(default=None, ge=0)
    total_tokens: int | None = Field(default=None, ge=0)
    cost: float | None = Field(default=None, ge=0)
    cost_micros: int | None = Field(default=None, ge=0)
    currency_code: str | None = Field(default=None, pattern=r"^[A-Z]{3}$")
    duration_ms: float | None = Field(default=None, ge=0)

    @model_validator(mode="after")
    def validate_token_total(self) -> "AgentLogPayload":
        """Reject inconsistent token totals and incomplete cost information.

        Returns:
            The validated immutable agent payload.

        Raises:
            ValueError: If input, output, and total tokens are all present but
                input plus output does not equal total.

        Notes:
            Partial provider information is accepted without modification. The
            utility never estimates a missing token value.
        """

        if None not in (self.input_tokens, self.output_tokens, self.total_tokens):
            if self.input_tokens + self.output_tokens != self.total_tokens:
                raise ValueError("total_tokens must equal input_tokens + output_tokens")
        if (self.cost_micros is None) != (self.currency_code is None):
            raise ValueError("cost_micros and currency_code must be supplied together")
        return self


class ToolLogPayload(EnterpriseLogPayload):
    """Describe a governed tool call without recording its request or result.

    Attributes:
        tool_name: Stable registered tool name.
        operation: Approved tool operation.
        target_system: External system, such as ServiceNow or Kafka Connect.
        outcome: Approved result category.
        duration_ms: Optional elapsed time in milliseconds.
        attempt_number: Attempt number, beginning with one.
        error_code: Optional stable error category without sensitive details.
    """

    tool_name: str = Field(min_length=1, max_length=128)
    operation: str = Field(min_length=1, max_length=128)
    target_system: str = Field(min_length=1, max_length=128)
    outcome: Outcome
    duration_ms: float | None = Field(default=None, ge=0)
    attempt_number: int = Field(default=1, ge=1)
    error_code: str | None = Field(default=None, min_length=1, max_length=128)


class GenAIObservabilityUtility:
    """Provide one consistent observability process for every service.

    Create one instance during service startup and share it through dependency
    injection. Existing business logic and logging frameworks remain under the
    service's control. Operations are synchronous, and log preparation calls the
    injected enterprise DLP service.

    Attributes:
        project_id: Google Cloud project used for trace-to-log correlation.
        accept_cloud_trace_context: Allows the older Google trace header when
            the standard W3C header is unavailable.
        generate_context_when_missing: Allows a service to start a trace when no
            supported trace header was received. The default is ``True`` so
            services can run and test independently.
        dlp_utility: Enterprise DLP service used to protect log values.
        log_name: Destination log name in Google Cloud Logging.
        logging_client: Optional preconfigured Google Cloud Logging client.
        trace_client: Optional preconfigured Google Cloud Trace client.
        logging_failure_mode: Determines whether a logging-provider failure is
            returned as ``False`` or raised to the service.
        dlp_fields: Optional field names to protect. The default protects every
            string content value while preserving field names and excluding
            utility-owned technical lineage.
    """

    def __init__(
        self,
        project_id: str,
        *,
        accept_cloud_trace_context: bool = True,
        generate_context_when_missing: bool = True,
        dlp_utility: DlpUtilityProtocol | None = None,
        log_name: str = "genai-application",
        logging_client: cloud_logging.Client | None = None,
        trace_client: trace_v2.TraceServiceClient | None = None,
        logging_failure_mode: LoggingFailureMode = "continue",
        dlp_fields: tuple[str, ...] | None = None,
    ) -> None:
        """Set trace, data-protection and log-delivery options.

        Args:
            project_id: Google Cloud project used to form
                ``logging.googleapis.com/trace``. Supply an empty string for
                local or cloud-neutral output.
            accept_cloud_trace_context: Permit ``X-Cloud-Trace-Context`` as a
                fallback only when ``traceparent`` is absent.
            generate_context_when_missing: Permit creation of a new sampled
                root trace when no upstream trace was supplied. It defaults to
                ``True`` and may be disabled by service policy.
            dlp_utility: Optional reusable ``DlpUtility`` instance. Injection
                keeps this package independent of the Google DLP SDK while
                ensuring log content is protected before a caller receives it.
            log_name: Non-empty Google Cloud Logging log name.
            logging_client: Optional preconfigured client supplied during
                dependency injection. When omitted, ``write_log`` creates one
                using Application Default Credentials.
            trace_client: Optional preconfigured Cloud Trace client supplied
                during dependency injection. When omitted, ``write_trace_span``
                creates one using Application Default Credentials.
            logging_failure_mode: ``continue`` returns ``False`` when log
                delivery fails; ``raise`` reports the provider error. DLP
                failures always stop processing to prevent raw-data fallback.
            dlp_fields: Optional non-empty tuple of payload field names to
                protect. The default protects every string content value except
                utility-owned technical lineage fields.

        Notes:
            Construction stores configuration only. It does not read environment
            variables, create credentials or contact Google Cloud.
        """

        if not log_name.strip():
            raise ValueError("log_name is required")
        if logging_failure_mode not in ("continue", "raise"):
            raise ValueError("logging_failure_mode must be 'continue' or 'raise'")
        if dlp_fields is not None and (
            not dlp_fields or any(not field.strip() for field in dlp_fields)
        ):
            raise ValueError("dlp_fields must contain non-empty field names")
        self.project_id = project_id.strip()
        self.accept_cloud_trace_context = accept_cloud_trace_context
        self.generate_context_when_missing = generate_context_when_missing
        self.dlp_utility = dlp_utility
        self.log_name = log_name.strip()
        self.logging_client = logging_client
        self.trace_client = trace_client
        self.logging_failure_mode = logging_failure_mode
        self.dlp_fields = tuple(dict.fromkeys(dlp_fields)) if dlp_fields else None
        self._cloud_logger: Any | None = None
        self._logging_failure_count = 0
        self._failure_count_lock = Lock()

    @property
    def logging_failure_count(self) -> int:
        """Return the number of Cloud Logging delivery failures.

        The counter contains no event content or business identifiers. A service
        may publish it through health monitoring without creating another log.
        """

        with self._failure_count_lock:
            return self._logging_failure_count

    @staticmethod
    def _headers(headers: Mapping[str, str]) -> dict[str, str]:
        """Standardize HTTP headers for reliable, case-insensitive lookup.

        Args:
            headers: Header mapping supplied by the calling service.

        Returns:
            A new dictionary with lowercase names and trimmed values. The
            original mapping remains unchanged.
        """

        return {str(key).lower(): str(value).strip() for key, value in headers.items()}

    def extract_trace_context(self, headers: Mapping[str, str]) -> TraceContext | None:
        """Read and validate supported trace information from HTTP headers.

        The standard ``traceparent`` header takes priority. The older Google
        header is used only when configured and the standard header is absent.

        Args:
            headers: Incoming HTTP headers.

        Returns:
            Validated upstream trace information, or ``None`` when no
            supported header is present.

        Raises:
            InvalidTraceContextError: If a supplied supported header has an
                invalid format or identifier.

        Notes:
            Invalid supplied trace information is rejected rather than silently
            replaced. Error messages never repeat the original header value.
        """

        values = self._headers(headers)
        # Prefer the enterprise-standard W3C header when both formats are present.
        raw = values.get("traceparent")
        if raw:
            match = TRACEPARENT.fullmatch(raw)
            if match is None or match.group("version") == "ff":
                raise InvalidTraceContextError("invalid traceparent header")
            try:
                return TraceContext(
                    trace_id=match.group("trace"),
                    span_id=match.group("span"),
                    trace_flags=match.group("flags"),
                    tracestate=values.get("tracestate") or None,
                )
            except ValueError as exc:
                raise InvalidTraceContextError("invalid traceparent header") from exc

        raw = values.get("x-cloud-trace-context")
        if raw and self.accept_cloud_trace_context:
            match = CLOUD_TRACE.fullmatch(raw)
            if match is None:
                raise InvalidTraceContextError("invalid X-Cloud-Trace-Context header")
            span_number = int(match.group("span"))
            if span_number == 0 or span_number > 2**64 - 1:
                raise InvalidTraceContextError("invalid X-Cloud-Trace-Context header")
            try:
                return TraceContext(
                    trace_id=match.group("trace"),
                    span_id=f"{span_number:016x}",
                    trace_flags="01" if match.group("sampled") == "1" else "00",
                )
            except ValueError as exc:
                raise InvalidTraceContextError("invalid X-Cloud-Trace-Context header") from exc
        return None

    def create_context(
        self,
        headers: Mapping[str, str],
        *,
        service_name: str,
        business: BusinessContext,
        operation: str | None = None,
        agent_name: str | None = None,
        step: str | None = None,
    ) -> ObservabilityContext:
        """Create the trace and business context for the current service step.

        Args:
            headers: Incoming request headers with optional trace information.
            service_name: Stable name of the current service.
            business: Enterprise context created by the Business Orchestrator
                or reconstructed from trusted downstream headers.
            operation: Optional name of the current operation.
            agent_name: Optional responsible-agent name.
            step: Optional workflow step name or number.

        Returns:
            A validated record containing business identity and either a new
            trace or the next span in the existing trace.

        Raises:
            InvalidTraceContextError: If a trace header is malformed, or when
                context is absent and root generation is disabled.
            pydantic.ValidationError: If service or optional operation metadata
                violates its model contract.

        Notes:
            The supplied business context remains unchanged. This method creates
            identifiers but does not send a span to Cloud Trace.
        """

        incoming = self.extract_trace_context(headers)
        normalized_headers = self._headers(headers)
        if incoming is None:
            # Only an entry service configured for new journeys may start a trace.
            if not self.generate_context_when_missing:
                raise InvalidTraceContextError("trace context is required")
            # A service that owns a new journey must create trace evidence that
            # Cloud Logging and Cloud Trace can retain and correlate.
            trace = TraceContext.root(sampled=True)
        else:
            trace = incoming.child()
        return ObservabilityContext(
            trace=trace,
            business=business,
            parent_service=(
                normalized_headers.get("x-current-service")
                if incoming is not None else None
            ),
            current_service=service_name,
            current_operation=operation,
            current_agent=agent_name,
            current_step=step,
        )

    @staticmethod
    def inject_headers(context: ObservabilityContext) -> dict[str, str]:
        """Build approved trace and business headers for the next service.

        Args:
            context: Validated context for the calling service.

        Returns:
            A new header dictionary containing trace information, required
            business identifiers and any available optional business fields.

        Notes:
            Authentication and credentials are deliberately excluded. The host
            service remains responsible for authentication. The receiving
            service calls ``create_context`` to create its own span.
        """

        trace, business = context.trace, context.business
        # Required identifiers connect the downstream service to the same journey.
        result = {
            "traceparent": trace.traceparent,
            "X-Execution-Id": business.execution_id,
            "X-Correlation-Id": business.correlation_id,
            "X-Request-Id": business.request_id,
            "X-Tenant-Id": business.tenant_id,
            "X-Business-Process": business.business_process,
            "X-User-Id": business.user_id,
            "X-Current-Service": context.current_service,
        }
        optional = {
            "tracestate": trace.tracestate,
            "X-Conversation-Id": business.conversation_id,
            "X-Incident-Number": business.incident_number,
            "X-Agent-Name": context.current_agent,
            "X-Current-Operation": context.current_operation,
            "X-Current-Step": context.current_step,
        }
        # Do not transmit optional headers when no value is available.
        result.update({key: value for key, value in optional.items() if value is not None})
        return result

    def build_cloud_logging_metadata(self, trace: TraceContext) -> dict[str, object]:
        """Build Google fields that connect a log entry to its trace.

        Args:
            trace: Trace information for the current service.

        Returns:
            Google trace, span and sampling fields when a project is configured;
            otherwise an empty dictionary.

        Notes:
            This method formats identifiers only. It does not create or send a
            Cloud Trace span.
        """

        if not self.project_id:
            return {}
        return {
            "logging.googleapis.com/trace": (
                f"projects/{self.project_id}/traces/{trace.trace_id}"
            ),
            "logging.googleapis.com/spanId": trace.span_id,
            "logging.googleapis.com/trace_sampled": trace.sampled,
        }

    @staticmethod
    def _build_trace_lineage_metadata(trace: TraceContext) -> dict[str, str]:
        """Build portable technical lineage from validated request context.

        The utility, rather than the calling service, owns these values. A root
        span has no parent, so ``parent_span_id`` is omitted instead of being
        represented by an empty or invented identifier.
        """

        metadata = {
            "trace_id": trace.trace_id,
            "span_id": trace.span_id,
        }
        if trace.parent_span_id is not None:
            metadata["parent_span_id"] = trace.parent_span_id
        return metadata

    def build_log_entry(
        self, payload: EnterpriseLogPayload, context: ObservabilityContext,
    ) -> dict[str, Any]:
        """Prepare one protected, structured log entry.

        Args:
            payload: Validated platform, agent or tool event.
            context: Service context associated with the event.

        Returns:
            A JSON-compatible dictionary containing populated event values,
            portable technical lineage and, when configured, Google-native
            trace-correlation fields.

        Raises:
            ValueError: If the event belongs to a different request, DLP is not
                configured or DLP returns an invalid result.

        Notes:
            Identity checks prevent an event from being assigned to the wrong
            request. DLP protects configured string values before the entry is
            returned. A DLP failure stops processing, so raw content is never
            returned as a fallback. This method prepares but does not send the
            entry.
        """

        if payload.correlation_id != context.business.correlation_id:
            raise ValueError("payload correlation_id does not match context")
        if payload.request_id != context.business.request_id:
            raise ValueError("payload request_id does not match context")
        # Convert the validated event into values accepted by structured logging.
        entry = payload.model_dump(mode="json", exclude_none=True)
        entry.update(self._build_trace_lineage_metadata(context.trace))
        entry.update(self.build_cloud_logging_metadata(context.trace))
        if self.dlp_utility is None:
            raise ValueError("dlp_utility is required before building logs")

        # Protect content values only. Technical lineage must remain exact so
        # Logs Explorer and Trace Explorer can join the same service operation.
        protected_keys = [
            key for key, value in entry.items()
            if isinstance(value, str)
            and key not in TECHNICAL_LINEAGE_FIELDS
            and (self.dlp_fields is None or key in self.dlp_fields)
        ]
        protected_text = self.dlp_utility.deidentify_content(
            json.dumps(
                [entry[key] for key in protected_keys],
                ensure_ascii=False,
                separators=(",", ":"),
            )
        )
        try:
            protected_values = json.loads(protected_text)
        except (TypeError, json.JSONDecodeError) as exc:
            raise ValueError("DLP returned an invalid protected log entry") from exc
        if (
            not isinstance(protected_values, list)
            or len(protected_values) != len(protected_keys)
            or any(not isinstance(value, str) for value in protected_values)
        ):
            raise ValueError("DLP returned an invalid protected log entry")
        entry.update(dict(zip(protected_keys, protected_values, strict=True)))
        return entry

    def write_log(
        self,
        payload: EnterpriseLogPayload,
        context: ObservabilityContext,
    ) -> bool:
        """Protect and send one structured event to Google Cloud Logging.

        Args:
            payload: Validated platform, agent or tool event.
            context: Service context associated with the event.

        Returns:
            ``True`` when the logging request succeeds. ``False`` when delivery
            fails and the configured failure mode is ``continue``.

        Raises:
            ValueError: If required configuration is missing or DLP returns an
                invalid result.
            google.api_core.exceptions.GoogleAPICallError: If Google Cloud DLP
                fails, or log delivery fails while failure mode is ``raise``.

        Notes:
            DLP protection always finishes before delivery begins. If DLP is
            unavailable or fails, the original event is never sent.
        """

        return self.write_log_with_entry(payload, context) is not None

    def write_log_with_entry(
        self,
        payload: EnterpriseLogPayload,
        context: ObservabilityContext,
        *,
        on_prepared: Callable[[Mapping[str, Any]], None] | None = None,
    ) -> dict[str, Any] | None:
        """Protect once, expose safely for local output, then deliver exactly once."""

        if not self.project_id and self.logging_client is None:
            raise ValueError("project_id is required before writing logs")

        entry = self.build_log_entry(payload, context)
        if on_prepared is not None:
            on_prepared(entry)
        try:
            if self.logging_client is None:
                self.logging_client = cloud_logging.Client(project=self.project_id)
            if self._cloud_logger is None:
                self._cloud_logger = self.logging_client.logger(self.log_name)
            native_trace_metadata = (
                {
                    "trace": (
                        f"projects/{self.project_id}/traces/{context.trace.trace_id}"
                    ),
                    "span_id": context.trace.span_id,
                    "trace_sampled": context.trace.sampled,
                }
                if self.project_id else {}
            )
            self._cloud_logger.log_struct(
                entry, severity=payload.severity, **native_trace_metadata,
            )
        except (GoogleAPICallError, GoogleAuthError, RetryError):
            with self._failure_count_lock:
                self._logging_failure_count += 1
            if self.logging_failure_mode == "raise":
                raise
            return None
        return entry

    def write_trace_span(
        self,
        context: ObservabilityContext,
        *,
        display_name: str | None = None,
        end_time: datetime | None = None,
    ) -> None:
        """Send the completed service span to Google Cloud Trace.

        Call this once when the service operation finishes. Log events and the
        exported span use the same trace and span identifiers, allowing Google
        Cloud Console to connect Logs Explorer with Trace Explorer.

        Args:
            context: Context created at the start of the service operation.
            display_name: Optional stable operation name shown in Trace Explorer.
            end_time: Optional UTC completion time. The current UTC time is used
                when no value is supplied.

        Raises:
            ValueError: If no Google Cloud project is configured.
            google.api_core.exceptions.GoogleAPICallError: If Cloud Trace rejects
                the span.
        """

        if not self.project_id:
            raise ValueError("project_id is required before writing trace spans")
        if self.trace_client is None:
            self.trace_client = trace_v2.TraceServiceClient()
        trace = context.trace
        span = trace_v2.Span(
            name=(
                f"projects/{self.project_id}/traces/{trace.trace_id}"
                f"/spans/{trace.span_id}"
            ),
            span_id=trace.span_id,
            parent_span_id=trace.parent_span_id or "",
            display_name={
                "value": display_name or context.current_operation
                or context.current_service,
            },
            start_time=context.started_at,
            end_time=end_time or datetime.now(UTC),
        )
        self.trace_client.create_span(request=span)