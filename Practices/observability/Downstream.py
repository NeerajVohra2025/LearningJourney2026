"""Expose downstream context continuation from the canonical utility package.

Existing services use this module while adopting the newer W3C and business
context APIs exposed at ``genai_observability``. Keeping the bridge inside the
same distribution removes the duplicate observability package without changing
service business behavior.
"""

from .downstream_runtime.domain.log_events import OperationalEvent
from .downstream_runtime.domain.log_payloads import (
    AgentLogPayload,
    EnterpriseLogPayload,
    PlatformServiceLogPayload,
    ToolLogPayload,
)
from .downstream_runtime.domain.models import (
    BusinessContext,
    DownstreamInboundRequest,
    DownstreamPipelineResult,
    DownstreamTarget,
    GovernedDownstreamRequest,
    LoggingContext,
    ObservabilityContext,
    RequestContext,
    WorkflowDecision,
)
from .downstream_runtime.logging_runtime import (
    ObservabilityRuntimeConfig,
    configure_observability_runtime,
)
from .downstream_runtime.pipeline import (
    DownstreamObservabilityPipeline,
    active_observability_pipeline,
    active_observability_context,
    active_request_context,
    build_enterprise_carrier,
)

__all__ = [
    "AgentLogPayload",
    "BusinessContext",
    "DownstreamInboundRequest",
    "DownstreamObservabilityPipeline",
    "DownstreamPipelineResult",
    "DownstreamTarget",
    "EnterpriseLogPayload",
    "GovernedDownstreamRequest",
    "LoggingContext",
    "ObservabilityContext",
    "ObservabilityRuntimeConfig",
    "OperationalEvent",
    "PlatformServiceLogPayload",
    "RequestContext",
    "ToolLogPayload",
    "WorkflowDecision",
    "active_observability_context",
    "active_observability_pipeline",
    "active_request_context",
    "build_enterprise_carrier",
    "configure_observability_runtime",
]