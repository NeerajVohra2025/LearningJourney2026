# Platform SDK Observability Utility

## Stakeholder Demo and Service Integration Guide

## 1. Summary

The Platform SDK Observability Utility gives every Python service one standard
way to create and distribute operational evidence:

- DLP-protected JSON events delivered to Sumo Logic and Google Cloud Logging;
  and
- connected service spans in Google Cloud Trace.

It follows one business request across APIs, orchestrators, agents, tools, and
utility services. Support teams can use the same request, correlation, trace,
and span identifiers to understand what happened and where a failure occurred.

```text
Business request
    |
    v
Python service
    |
    |  GenAIObservabilityUtility.create_context()
    v
Validated business + trace context
    |
    +--> GenAIObservabilityUtility.write_log()
    |        |
    |        +--> 1. build_log_entry()
    |        |       +--> validate payload and context identity
    |        |       +--> GoogleDlpDeidentifier.deidentify_content()
    |        |       +--> protected JSON event
    |        |
    |        +--> 2. _deliver_to_sumo()
    |        |       +--> Sumo Logic HTTP Collector API
    |        |       +--> return delivery status + HTTP status code
    |        |
    |        +--> 3. update protected JSON event
    |        |       +--> sumo_delivery_status
    |        |       +--> sumo_http_status
    |        |
    |        +--> 4. Google Cloud Logging log_struct()
    |                +--> stores protected JSON with Sumo delivery result
    |
    +--> GenAIObservabilityUtility.write_trace_span()
             +--> Google Cloud Trace
```

The Sumo delivery result is part of the final Cloud Logging JSON. Its value is
`accepted`, `failed`, or `unavailable`; `sumo_http_status` contains the HTTP
status code when the collector returned a response, otherwise it is `null`.

### How a downstream service joins the same journey

```text
Request received by downstream service
    |
    +--> GenAIObservabilityUtility.extract_trace_context(headers)
             |
             +--> Valid parent trace found
             |       +--> TraceContext.child()
             |       +--> keep the same trace_id
             |       +--> create a new span_id
             |       +--> upstream span_id becomes parent_span_id
             |
             +--> No parent trace found
                     |
                     +--> generation allowed
                     |       +--> TraceContext.root()
                     |       +--> create a new trace journey
                     |
                     +--> generation disabled
                             +--> raise InvalidTraceContextError
```

Therefore, a downstream service joins the existing journey whenever a valid
parent trace is supplied. It starts a new journey only when no parent exists
and its configuration explicitly permits root-trace generation.

The utility records operational evidence. It does not authenticate users,
authorize actions, approve agent decisions, or decide which tool may run. Each
service remains responsible for those controls.

## Business Capability Summary

The Observability capability provides a consistent way to follow a business
request as it moves across APIs, AI agents, tools, and supporting services. It
connects operational records from each participating service into one
end-to-end journey, helping authorized teams understand what happened, where
it happened, and whether each step completed successfully.

From a business perspective, the capability:

- **Speeds up incident investigation** by connecting activity across multiple
  services with shared request, correlation, and trace identifiers.
- **Improves operational transparency** by showing which service, agent, or
  tool handled each part of a request and the outcome of that work.
- **Supports audit and compliance reviews** through structured, consistent
  evidence that links the business purpose to the technical execution path.
- **Protects permitted log information** by applying Google Sensitive Data
  Protection before events are sent to Sumo Logic or Google Cloud Logging.
- **Provides delivery visibility** by recording whether Sumo Logic accepted an
  event while retaining the protected record in Cloud Logging.
- **Creates reusable enterprise standards** so product teams can adopt the
  same logging, tracing, and context-propagation approach instead of building
  separate solutions.
- **Improves service accountability** by distinguishing the role and outcome
  of each API, agent, tool, or platform service involved in a request.
- **Keeps governance responsibilities clear** because the utility records
  operational evidence but does not replace authentication, authorization,
  retention policy, alerting, business controls, or human oversight.

In simple terms, this capability gives the business a connected and protected
record of a request's journey. It enables faster support, clearer ownership,
and stronger evidence without collecting prohibited information such as
credentials, prompts, model responses, or complete customer payloads.

## 2. What stakeholders gain

| Stakeholder question | Utility capability |
|---|---|
| Which request was processed? | Records request, execution, and correlation IDs |
| Which business process or incident was involved? | Records tenant, process, user, conversation, and incident context |
| Which service handled the request? | Records current service, parent service, operation, and role |
| Which agent or tool participated? | Provides validated agent and tool log models |
| Where did the request fail? | Records outcome, severity, safe error code, and duration |
| Can logs and traces be viewed together? | Adds matching trace and span IDs to both |
| Is permitted text protected before logging? | Sends permitted string values through Google Sensitive Data Protection first |
| Was the protected event accepted by Sumo Logic? | Records the Sumo delivery result and HTTP status in Cloud Logging |

## 3. Packages used

### Google Cloud packages

| Python package | Google service | Purpose |
|---|---|---|
| `google-cloud-logging` | Cloud Logging | Writes structured operational log entries |
| `google-cloud-trace` | Cloud Trace | Creates completed service spans |
| `google-cloud-dlp` | Sensitive Data Protection | De-identifies permitted log text before Cloud Logging |
| `google-auth` | Application Default Credentials | Supports runtime authentication error handling |
| `google-api-core` | Google API common runtime | Supports API and retry error handling |
| `httpx` | Sumo Logic HTTP Collector API | Posts protected JSON and receives the delivery HTTP status |

### Core Python packages

| Package | Purpose |
|---|---|
| `pydantic` | Validates and freezes context and log models |
| `json` | Builds structured log entries and validates the protected response |
| `uuid` | Generates request, correlation, trace, and span identifiers |
| `datetime` | Creates UTC event and span timestamps |
| `re` | Validates W3C and Google trace-header formats |
| `threading` | Protects the logging failure counter |

The implementation supports Python 3.11 through 3.13.

## 4. Package, class, and method map

This plain-text diagram remains visible in GitLab, editors, PDFs, and slides.

```text
platform_sdk.observability
|
+-- config.py
|   +-- class ObservabilitySettings
|   +-- build_observability_utility(settings)
|
+-- cloud_runtime.py
|   +-- class GoogleDlpDeidentifier
|   |   +-- deidentify_content(text)
|   +-- build_cloud_observability_utility(...)
|
+-- observability_utility.py
    +-- class BusinessContext
    +-- class TraceContext
    |   +-- root()
    |   +-- child()
    |   +-- traceparent
    +-- class ObservabilityContext
    +-- class PlatformServiceLogPayload
    +-- class AgentLogPayload
    +-- class ToolLogPayload
    +-- class GenAIObservabilityUtility
        +-- create_context(...)
        +-- inject_headers(context)
        +-- build_log_entry(payload, context)
        +-- write_log(payload, context)
        +-- write_log_with_entry(payload, context)
        +-- _deliver_to_sumo(entry)
        +-- write_trace_span(context, ...)
        +-- logging_failure_count
```

| Class | User-friendly meaning |
|---|---|
| `ObservabilitySettings` | Configuration for context and Google Cloud delivery |
| `BusinessContext` | Business identity shared across the request journey |
| `TraceContext` | Trace, span, parent span, and sampling identity |
| `ObservabilityContext` | Business and technical identity for this service operation |
| `PlatformServiceLogPayload` | Log contract for an API, orchestrator, or platform service |
| `AgentLogPayload` | Log contract for an AI or deterministic agent |
| `ToolLogPayload` | Log contract for a governed tool or utility adapter |
| `GoogleDlpDeidentifier` | Protects permitted text using enterprise DLP templates |
| `GenAIObservabilityUtility` | Main API used to create context, logs, headers, and spans |

## 5. Information carried across services

### Business identifiers

| Field | Purpose |
|---|---|
| `execution_id` | One complete workflow execution |
| `correlation_id` | Related events across services |
| `request_id` | The original request |
| `tenant_id` | The approved tenant boundary |
| `business_process` | The governed business workflow |
| `user_id` | The authenticated user or workload |
| `conversation_id` | Optional multi-turn conversation |
| `incident_number` | Optional business incident |

### Technical identifiers

| Field | Purpose |
|---|---|
| `trace_id` | Remains the same across the complete distributed request |
| `span_id` | Identifies the current service operation |
| `parent_span_id` | Connects the current service to the upstream operation |
| `trace_flags` | Preserves the W3C sampling decision |

Business identifiers explain why the work happened. Trace identifiers explain
where and in what order the technical work happened.

## 6. End-to-end sequence

The diagrams below show one request crossing two services. Service A is the
trusted entry service and may create a root trace. Service B is a downstream
service and creates a child span from Service A's propagated `traceparent`.
Each service writes its own completion log and trace span.

### End-to-end implementation flow

This flow diagram uses plain text so it remains visible in GitLab, editors,
PDF exports, and presentation tools.

```text
CALLER
  |
  | request carrying an authentication header
  v
SERVICE A - trusted entry service
  |  1. Extract the authentication header from the incoming request.
  |  2. Validate the credential and establish the trusted caller identity.
  |  3. Construct BusinessContext from the validated identity and approved values.
  |  4. create_context(incoming headers)
  |       No traceparent + generation enabled -> create root trace/span A.
  |  5. Execute approved business work.
  |
  |  Downstream call required?
  |       |
  |       +-- no -------------------------------------------------------+
  |       |                                                             |
  |       +-- yes                                                       |
  |            6. inject_headers(context A)                             |
  |               -> traceparent carries trace ID + span A as parent    |
  |               -> X-* headers carry approved business context       |
  |               -> authentication is added by Service A separately   |
  |            7. Call Service B                                       |
  |                    |                                                |
  |                    v                                                |
  |              SERVICE B - downstream service                        |
  |                8. Extract the authentication header from the        |
  |                   downstream request.                               |
  |                9. Validate Service A's credential and establish     |
  |                   its trusted workload identity.                    |
  |               10. Reconstruct/validate BusinessContext from trusted |
  |                   propagated values.                                |
  |               11. create_context(propagated headers)                |
  |                   -> keep the same trace ID                         |
  |                   -> create span B                                  |
  |                   -> set parent of span B = span A                  |
  |               12. Execute approved downstream work.                 |
  |               13. Complete Service B observability:                 |
  |                   write_log() -> DLP -> Sumo -> Cloud Logging       |
  |                   write_trace_span() -> Cloud Trace                 |
  |               14. Return downstream result                          |
  |                    |                                                |
  |<-------------------+                                                |
  |                                                                     |
  +<--------------------------------------------------------------------+
  |
  | 15. Complete Service A observability:
  |     write_log() -> DLP -> Sumo -> Cloud Logging
  |     write_trace_span() -> Cloud Trace
  | 16. Return the business response.
  v
CALLER

Result: logs and spans from both services share one trace ID. Each service has
its own span ID, and span B names span A as its parent.
```

Extracting an authentication header does not authenticate the caller. Each
receiving service must validate the extracted credential before it trusts the
caller identity or any propagated business values. The observability utility
does not perform this authentication.

### Runtime sequence diagram

The sequence separates context propagation from completion telemetry. In
particular, `inject_headers()` occurs before the downstream request, while
`write_log()` and `write_trace_span()` occur when each service operation ends.

```text
Participants:
  C=Caller   SA=Service A   UA=SDK utility in A   SB=Service B
  UB=SDK utility in B   DLP=Google DLP   SL=Sumo Logic
  CL=Cloud Logging   CT=Cloud Trace

C  -> SA : authenticated business request
SA -> UA : create_context(incoming headers)
UA -> SA : root context [trace=T, span=A, no parent]

SA -> UA : inject_headers(context A)
UA -> SA : traceparent [trace=T, parent span=A] + approved X-* headers
SA -> SB : authenticated downstream request + propagated headers
SB -> UB : create_context(propagated headers)
UB -> SB : child context [trace=T, span=B, parent=A]
SB -> SB : execute approved downstream work

SB  -> UB  : write_log(payload, context B)
UB  -> DLP : deidentify permitted string fields
DLP -> UB  : protected values
UB  -> SL  : POST protected JSON
SL  -> UB  : HTTP status, or UB handles a network failure
UB  -> CL  : log_struct(protected JSON + Sumo delivery result, trace=T, span=B)
CL  -> UB  : accepted, or UB applies configured logging failure mode
UB  -> SB  : True/False or configured exception
SB  -> UB  : write_trace_span(context B)
UB  -> CT  : create completed span B [trace=T, parent=A]
SB  -> SA  : downstream business result

SA  -> UA  : write_log(payload, context A)
UA  -> DLP : deidentify permitted string fields
DLP -> UA  : protected values
UA  -> SL  : POST protected JSON
SL  -> UA  : HTTP status, or UA handles a network failure
UA  -> CL  : log_struct(protected JSON + Sumo delivery result, trace=T, span=A)
CL  -> UA  : accepted, or UA applies configured logging failure mode
UA  -> SA  : True/False or configured exception
SA  -> UA  : write_trace_span(context A)
UA  -> CT  : create completed root span A [trace=T]
SA  -> C   : business response
```

`T` is the trace ID shared by the complete journey. `A` and `B` are different
span IDs. The apparent long arrows represent calls made by the SDK instance
inside the corresponding service; SDK A and SDK B are not remote services.

### What each SDK operation does

1. The service authenticates the caller before trusting business headers.
2. `create_context()` validates trace input. With no parent it creates a root
   span only when `generate_context_when_missing=True`; with a valid parent it
   creates a child span under the same trace ID. It does not export the span.
3. `inject_headers()` prepares trace and approved business headers before a
   downstream call. It never adds authentication or credentials.
4. `write_log()` verifies payload/context identity and calls DLP before any log
   delivery. There is no raw-event fallback if DLP fails.
5. The protected JSON is posted to Sumo Logic. The resulting
   `sumo_delivery_status` and `sumo_http_status` are appended to the protected
   event. A disabled collector or network failure does not prevent the Cloud
   Logging attempt.
6. The SDK calls Cloud Logging `log_struct()` with the final protected event and
   native trace metadata. `write_log()` returns `True` on success; in
   `logging_failure_mode="continue"`, a Cloud Logging failure returns `False`.
7. `write_trace_span()` separately exports the completed service span to Cloud
   Trace. The application should call it once per service operation, including
   the appropriate completion/error path.

## 7. One integration flow for every service

```text
STARTUP
  build one GenAIObservabilityUtility
       |
REQUEST ENTRY
  authenticate -> BusinessContext -> create_context()
       |
BUSINESS WORK
  run the existing service use case
       +--> if a downstream call is needed:
       |      inject_headers() -> add authentication -> call next service
       |      -> receive downstream result
       |
COMPLETION
  role payload -> write_log() -> write_trace_span() -> return response
```

Build the utility once when the service starts. Do not create a new utility for
every request.

## 8. Step-by-step service integration

### Step 1: Add the Platform SDK

Use the approved dependency and lock-file process:

```toml
[project]
dependencies = ["platform-sdk"]
```

### Step 2: Configure observability

```python
from platform_sdk.observability import ObservabilitySettings

settings = ObservabilitySettings(
    context_enabled=True,
    cloud_logging=True,
    project_id="my-gcp-project",
    log_name="my-service",
    log_level="INFO",
    generate_context_when_missing=True,
    business_process="incident-remediation",
)
```

Use `generate_context_when_missing=True` for a trusted entry service. A
downstream-only service can use `False` when an upstream trace is mandatory.

### Step 3: Create one utility at startup

```python
from platform_sdk.observability import build_observability_utility

observability = build_observability_utility(settings)
if observability is None:
    raise RuntimeError("Observability must be enabled")
```

Google clients are initialized only when needed and use Application Default
Credentials. Configure the Sumo Logic HTTP collector through protected runtime
configuration:

```dotenv
SUMO_LOGIC_ENABLED=true
SUMO_LOGIC_ENDPOINT=<SECRET_HTTP_COLLECTOR_URL>
SUMO_LOGIC_TIMEOUT_SECONDS=2
```

`SUMO_LOGIC_ENDPOINT` is credential-bearing and must come from the approved
secret-management boundary. Never commit or print it.

### Step 4: Authenticate and create business context

```python
from platform_sdk.observability import BusinessContext

business = BusinessContext(
    tenant_id=authenticated_identity.tenant_id,
    business_process="incident-remediation",
    user_id=authenticated_identity.subject,
    incident_number=approved_incident_number,
)
```

Use only authenticated, approved values. Never place credentials, prompts,
model responses, or complete request bodies in this context.

### Step 5: Create the service context

```python
context = observability.create_context(
    request.headers,
    service_name="my-service",
    business=business,
    operation="process-request",
)
```

For an agent, also supply `agent_name="action-agent"`.

### Step 6: Run existing business logic

```python
started = time.perf_counter()
outcome = "success"
error_code = None

try:
    result = await existing_service.execute(request_data)
except Exception:
    outcome = "failure"
    error_code = "SERVICE_OPERATION_FAILED"
    raise
finally:
    duration_ms = (time.perf_counter() - started) * 1000
```

Use a stable error code, not unrestricted exception text.

### Step 7: Build the correct payload

#### API, orchestrator, or platform service

```python
from platform_sdk.observability import PlatformServiceLogPayload

payload = PlatformServiceLogPayload(
    **PlatformServiceLogPayload.common_fields(
        context,
        severity="INFO" if outcome == "success" else "ERROR",
        event_name=f"service.operation.{outcome}",
        message=f"my-service operation {outcome}",
        logger_name="my_service.observability",
    ),
    operation="process-request",
    outcome=outcome,
    duration_ms=duration_ms,
)
```

#### Agent service

```python
from platform_sdk.observability import AgentLogPayload

payload = AgentLogPayload(
    **AgentLogPayload.common_fields(
        context,
        severity="INFO" if outcome == "success" else "ERROR",
        event_name=f"agent.execution.{outcome}",
        message=f"action-agent execution {outcome}",
        logger_name="agent_action.observability",
    ),
    agent_name="action-agent",
    agent_framework="google-adk",
    operation="execute-action",
    outcome=outcome,
    duration_ms=duration_ms,
)
```

Add token fields only when the model provider supplies authoritative values.

#### Tool or utility service

```python
from platform_sdk.observability import ToolLogPayload

payload = ToolLogPayload(
    **ToolLogPayload.common_fields(
        context,
        severity="INFO" if outcome == "success" else "ERROR",
        event_name=f"tool.execution.{outcome}",
        message=f"servicenow operation {outcome}",
        logger_name="tool_servicenow.observability",
    ),
    tool_name="servicenow",
    operation="create-incident",
    target_system="servicenow",
    outcome=outcome,
    duration_ms=duration_ms,
    error_code=error_code,
)
```

### Step 8: Write the protected log

```python
written = observability.write_log(payload, context)
if not written:
    service_health.record_observability_delivery_failure()
```

```text
Pydantic validation
  -> context identity check
  -> DLP de-identification
  -> protected JSON validation
  -> Sumo Logic HTTP Collector API
  -> add Sumo delivery status and HTTP status to protected JSON
  -> Google Cloud Logging log_struct(final protected JSON)
```

There is no raw-log fallback when DLP fails.

### Step 9: Write the completed trace span

```python
observability.write_trace_span(
    context,
    display_name="my-service:process-request",
)
```

Call this once when the operation finishes. A trace ID in a log does not by
itself create a Cloud Trace span.

### Step 10: Propagate context downstream

```python
headers = observability.inject_headers(context)
headers["Authorization"] = await workload_identity_token()

response = await http_client.post(
    downstream_url,
    headers=headers,
    json=safe_request_payload,
)
```

The utility supplies context headers only. The service adds workload
authentication separately.

## 9. Google Cloud setup

Enable:

```text
dlp.googleapis.com
logging.googleapis.com
cloudtrace.googleapis.com
```

The implementation defaults to these DLP templates:

```text
projects/<PROJECT_ID>/locations/us-central1/inspectTemplates/mattel-inspect-template
projects/<PROJECT_ID>/locations/us-central1/deidentifyTemplates/mattel-de-identity-template
```

The platform team must provision these templates in the selected project and
location before enabling cloud logging. This guide uses the standard Platform
SDK defaults; any environment-specific template override must be managed by the
platform deployment configuration.

Use the Cloud Run, GKE, VM, or Workload Identity service account. Do not store a
service-account key in code or an image. The identity needs only permission to
use approved DLP templates, write logs, and create trace spans. Viewing access
should be granted separately.

## 10. Failure behavior

| Condition | Result |
|---|---|
| Invalid `traceparent` | Raises `InvalidTraceContextError` without repeating its value |
| Missing trace when generation is disabled | Raises `InvalidTraceContextError` |
| Payload does not match request context | Rejects log construction |
| DLP is missing, fails, or returns invalid JSON | Fails closed; raw content is not sent |
| Sumo endpoint is not configured | Adds `sumo_delivery_status="unavailable"` and `sumo_http_status=null`, then continues to Cloud Logging |
| Sumo network request fails | Adds unavailable/null status, then continues to Cloud Logging |
| Sumo returns HTTP 2xx | Adds `accepted` and the HTTP status code, then continues to Cloud Logging |
| Sumo returns non-2xx | Adds `failed` and the HTTP status code, then continues to Cloud Logging |
| Cloud Logging fails in default `continue` mode | Returns `False` and increases `logging_failure_count` |
| Cloud Trace fails | Returns the exception to the service |

The service decides whether an observability failure should fail the business
request, be retried outside the utility, or appear as degraded health.

## 11. Information that must never be logged

- passwords, tokens, API keys, cookies, or authorization headers;
- prompts, model responses, or chain-of-thought;
- complete customer request or response bodies;
- complete tool inputs or outputs;
- unrestricted exception text or stack traces in business event fields;
- service-account keys or secret values.

DLP is extra protection, not permission to collect prohibited information.
Use only approved, non-sensitive scalar values in free-form `attributes`. The
utility protects top-level strings; it does not recursively de-identify nested
attribute values.

## 12. Verification checklist

### Code

- [ ] One utility is created at startup and reused.
- [ ] Authentication happens before business headers are trusted.
- [ ] One business and observability context is created per operation.
- [ ] The correct platform, agent, or tool payload is used.
- [ ] No prohibited content is included.
- [ ] `write_log()` and `write_trace_span()` are called at completion.
- [ ] `inject_headers()` supplies downstream context.
- [ ] Downstream authentication is added separately.

### Google Cloud

- [ ] The protected structured event exists in Cloud Logging.
- [ ] The completed span exists in Cloud Trace.
- [ ] Log and trace contain the same `trace_id` and `span_id`.
- [ ] A downstream service retains the trace ID and creates a child span.
- [ ] DLP failure produces no raw log entry.
- [ ] Runtime IAM is least privilege.

## 13. Stakeholder demonstration

1. Submit one authenticated test request with a known incident number.
2. Show its request ID, correlation ID, trace ID, and service span ID.
3. Show the protected event in Cloud Logging.
4. Open the matching span in Cloud Trace using the same trace ID.
5. Call a downstream service and show the same trace ID with a new child span.
6. Demonstrate a test DLP failure and confirm no raw log is delivered.

```text
One request
  -> one trusted business identity
  -> one connected trace across services
  -> one validated log shape for each service role
  -> permitted text protected before Cloud Logging
  -> faster support, audit, and operational investigation
```

The utility provides the common logging and tracing foundation. Authentication,
authorization, safe event selection, IAM, retention, dashboards, alerting, and
business policy remain owned by the appropriate enterprise teams.