# Platform SDK Observability Flow

## Plain-Language Boardroom and Service-Team Guide

## 1. Purpose

This guide explains, point by point, what the observability utility does, what
`downstream.py` does, where it is used, and how one request moves through the
complete flow.

The key message is:

```text
observability_utility.py = core observability functions
downstream.py            = public access to the downstream workflow
```

`downstream.py` is not a second observability utility. It exposes a workflow
that uses the core utility.

## 2. Business Value

The capability gives support and operations teams one connected view of a
request across services. It helps answer:

- Which service received the request?
- Which services, agents, and tools handled it next?
- Did each step succeed or fail?
- Where did a failure occur?
- Which logs and trace spans belong to the same request?
- Was permitted log information protected before delivery?

The result is faster investigation, clearer ownership, and consistent
operational evidence.

## 3. The Two-Layer Design

### Layer 1: Core observability utility

File: `observability_utility.py`

Main class: `GenAIObservabilityUtility`

It:

1. validates incoming trace headers;
2. creates a root trace or child span;
3. carries business identifiers;
4. creates approved headers for the next service;
5. validates structured log payloads;
6. protects eligible log values through DLP;
7. sends protected logs to Sumo Logic and Google Cloud Logging; and
8. sends completed spans to Google Cloud Trace.

### Layer 2: Governed downstream workflow

Public file: `downstream.py`

Implementation: `downstream_runtime/pipeline.py`

Main class: `DownstreamObservabilityPipeline`

It:

1. validates the service-to-service request;
2. creates request-local context;
3. calls the service's business coordinator;
4. handles a local result or approved downstream request;
5. creates an approved downstream header carrier;
6. invokes the next service through a transport adapter; and
7. records completion evidence through the core utility.

## 4. Why `downstream.py` Looks Unused

`downstream.py` contains imports and an `__all__` list, but little processing
logic. This is intentional. It is a stable public doorway:

```text
Service code
    |
    | imports the supported API
    v
downstream.py
    |
    | re-exports classes and functions
    v
downstream_runtime/pipeline.py
    |
    | runs the workflow
    v
observability_utility.py
    handles trace, log, DLP, and cloud operations
```

Services normally import it as follows:

```python
from platform_sdk.observability.downstream import (
    DownstreamInboundRequest,
    DownstreamObservabilityPipeline,
    WorkflowDecision,
)
```

The downstream API is actively used by the orchestrator, incident agent,
action service, ServiceNow tool, RCA service, resolution store, and log service.

## 5. Common Application Pattern

```text
Application startup
    1. Build GenAIObservabilityUtility.
    2. Build DownstreamObservabilityPipeline.
    3. Store it on app.state.downstream_observability.

Request processing
    4. Read the stored pipeline.
    5. Call pipeline.execute(...).
    6. Return the pipeline result.
```

## 6. Complete Flow at a Glance

```text
1. Load settings
        |
2. Build the core utility
        |
3. Build and store the downstream pipeline
        |
4. Receive a request
        |
5. Validate headers and payload
        |
6. Create business and request context
        |
7. Continue or create the trace
        |
8. Activate context for this request
        |
9. Run the business coordinator
        |
        +--> Local result -------------------------+
        |                                          |
        +--> Downstream request                    |
                  |                                |
10. Build approved propagation headers             |
                  |                                |
11. Authenticate and call the next service         |
                  |                                |
                  +--------------------------------+
                                                   |
12. Build completion event <-----------------------+
        |
13. Protect and deliver the log
        |
14. Write the completed trace span
        |
15. Clear request context and return
```

## 7. Detailed Step-by-Step Flow

### Step 1: Load observability settings

What happens:

- The service loads `ObservabilitySettings`.
- It reads whether context and cloud logging are enabled.
- It reads the log name, project ID, and business process.
- It reads whether a missing trace may start a new trace.

Why it matters:

- Every service follows the same rules.
- Invalid configuration is rejected early.

Result:

- The service has validated instructions for observability.

### Step 2: Build the core utility

What happens:

- The service calls `build_observability_utility(settings)`.
- The builder returns `GenAIObservabilityUtility` when context is enabled.
- The cloud runtime prepares DLP, logging, tracing, and Sumo configuration.
- Cloud clients are created later when first needed.

Why it matters:

- Business code does not need to construct cloud clients.
- Services share the same protection and delivery rules.

Result:

- The service has one utility for context, logs, and spans.

### Step 3: Build the downstream pipeline

What happens:

- The application creates one `DownstreamObservabilityPipeline`.
- It supplies trusted service name, version, environment, role, and core
  utility.
- It usually stores the pipeline on `app.state.downstream_observability`.

Why it matters:

- The pipeline is configured once and reused.
- Trusted service identity does not come from the request body.

Result:

- The application is ready to process governed requests.

### Step 4: Receive a request

What happens:

- An HTTP endpoint receives headers and a payload.
- It creates a `DownstreamInboundRequest` with the operation name.
- It calls the pipeline:

```python
observed = await pipeline.execute(
    inbound=inbound_request,
    coordinate=coordinate,
    invoke=invoke,
)
```

Why it matters:

- Endpoints use one shared flow instead of recreating observability logic.

Result:

- The request enters the governed pipeline.

### Step 5: Validate the governed request

What happens:

- The pipeline checks request, correlation, tenant, capability, operation,
  workflow, policy, and service-lineage headers.
- It rejects missing required values.
- It rejects payload values that conflict with governed headers.

Why it matters:

- A request body cannot replace trusted governance information.
- Bad context is stopped before business work begins.

Result:

- Only consistent request information moves forward.

### Step 6: Create business and request context

What happens:

- The pipeline creates an immutable `RequestContext`.
- It records service, request, correlation, tenant, workflow, and policy
  identity.
- It emits a safe context-continuation log.

Why it matters:

- Later events use the same trusted identity.
- Immutable context cannot be accidentally changed.

Result:

- The service has reliable local context for this request.

### Step 7: Continue or create the trace

What happens:

- The pipeline calls `GenAIObservabilityUtility.create_context()`.
- The utility checks for a W3C `traceparent` header.

If a valid upstream trace exists:

```text
Upstream: trace=T, span=A
Current:  trace=T, span=B, parent=A
```

- The trace ID remains the same.
- The current service receives a new span ID.
- The upstream span becomes its parent.

If no trace exists and creation is allowed:

```text
Current: trace=T, span=A, parent=none
```

- The utility creates a new trace and root span.

If no trace exists and creation is disabled:

- The utility raises `InvalidTraceContextError`.
- Processing stops.

Why it matters:

- One trace ID connects all participating services.
- A separate span identifies each service's work.

Result:

- The current service has a trace ID, span ID, and optional parent span ID.

Important: this step creates identifiers. It does not send a Cloud Trace span.

### Step 8: Activate context for this request

What happens:

- The pipeline stores the request context, observability context, and active
  pipeline in request-local variables.
- Code and normal Python logs can use the same active context.

Why it matters:

- Developers do not need to pass context through every method.
- Logs created during the request use consistent identifiers.

Result:

- Context is available throughout this request only.

### Step 9: Run the business coordinator

What happens:

- The pipeline calls the service-provided `coordinate()` function.
- The coordinator returns exactly one outcome:

```python
WorkflowDecision(response=local_result)
```

or:

```python
WorkflowDecision(downstream_request=approved_request)
```

Why it matters:

- Business policy stays in the service application.
- Observability records the decision; it does not make it.
- Exactly one outcome prevents ambiguous execution.

Result:

- The pipeline returns locally or prepares one downstream call.

### Step 10: Build downstream headers when needed

What happens:

- The pipeline records the selected downstream route.
- It creates an allowlisted enterprise carrier.
- It calls `inject_headers()` to add approved trace and business context.
- Important headers include `traceparent`, request ID, correlation ID, tenant,
  business process, user ID, and current service.

Why it matters:

- The next service can join the same journey.
- Only approved context is propagated.
- Credentials are not included.

Result:

- The pipeline has a safe header carrier for the next service.

This step is skipped for a local response.

### Step 11: Authenticate and call the next service

What happens:

- The pipeline passes the request and carrier to `invoke()`.
- The outbound adapter adds authentication and network timeout controls.
- The adapter performs the request.
- The receiving service repeats this same flow.

Why it matters:

- Authentication remains the transport adapter's responsibility.
- Observability never handles credentials or access tokens.

Result:

- The pipeline receives a downstream result or exception.

This step is skipped for a local response.

### Step 12: Build the completion event

What happens:

- The service uses `PlatformServiceLogPayload`, `AgentLogPayload`, or
  `ToolLogPayload`, according to its role.
- It records approved operational facts and the outcome.
- The utility adds the trace ID, span ID, and parent span ID.

Why it matters:

- Services, agents, and tools produce consistent evidence.
- Technical lineage comes from validated context, not user input.

Result:

- A structured completion event is ready for protection.
- The pipeline schedules log and span delivery as a tracked background task.
- Cloud-provider response time does not delay or change the business result.

### Step 13: Protect and deliver the log

What happens:

1. The utility verifies matching request and correlation identifiers.
2. It adds trace and span fields.
3. It adds Google trace-correlation metadata.
4. It protects eligible string values through DLP.
5. It sends protected JSON to Sumo Logic when configured.
6. It adds the Sumo delivery result.
7. It sends the protected event to Google Cloud Logging.

Why it matters:

- Permitted content is protected before external delivery.
- Trace fields remain exact so logs and spans can be joined.
- Cloud Logging records the Sumo delivery outcome.

Result:

- Operations receives a protected, trace-linked log event.

Safety rule: if DLP fails, the raw event is not sent as a fallback.

### Step 14: Write the completed trace span

What happens:

- The utility calls `write_trace_span()` at operation completion.
- It sends trace ID, span ID, parent span ID, operation name, start time, and
  end time.

Why it matters:

- A trace ID in a log does not create a Cloud Trace span.
- This explicit call creates the completed service span.
- Matching IDs connect the log and trace views.

Result:

- Google Cloud Trace shows the work completed by this service.

### Step 15: Clear context and return

What happens:

- The pipeline clears request-local context in a `finally` block.
- Cleanup occurs after success and failure.
- A successful result returns to the HTTP endpoint.
- On failure, failure evidence is attempted and the exception is re-raised.
- During graceful application shutdown, `drain()` waits for tracked
  observability delivery tasks to finish.

Why it matters:

- Context from one request cannot leak into another.
- Pending provider delivery is tracked without keeping request context active.

Result:

- The request ends with clean runtime state and connected evidence.

## 8. Three-Service Example

Assume a request moves through three services.

### Service 1: Orchestrator

1. No upstream trace exists.
2. It creates trace `T` and root span `A`.
3. It sends `traceparent` containing `T` and `A`.

### Service 2: Incident agent

1. It receives trace `T` and span `A`.
2. It creates local span `B`.
3. It records `A` as the parent of `B`.
4. It sends `traceparent` containing `T` and `B`.

### Service 3: ServiceNow tool

1. It receives trace `T` and span `B`.
2. It creates local span `C`.
3. It records `B` as the parent of `C`.

```text
Trace T
|
+-- Span A: Orchestrator
    |
    +-- Span B: Incident agent
        |
        +-- Span C: ServiceNow tool
```

All services keep trace `T`; each owns a different span. Shared request and
correlation IDs connect the same business journey in logs.

## 9. Responsibility Boundaries

The core utility does:

- validate and propagate trace context;
- create trace and span identifiers;
- protect eligible log values;
- deliver protected logs; and
- write completed trace spans.

The core utility does not authenticate, authorize, choose a downstream
destination, calculate model cost, retry provider calls, or approve sensitive
content for logging.

The downstream pipeline does:

- validate the governed request;
- create request-local context;
- run the coordinator;
- build an allowlisted carrier;
- invoke an injected adapter; and
- coordinate completion evidence.

The pipeline does not define business policy, add authentication, replace the
transport adapter, or independently implement DLP and cloud delivery.

## 10. Which API Should a Developer Use?

Use `GenAIObservabilityUtility` directly for core functions such as creating
context, injecting standard headers, writing a protected event, or writing a
completed span.

Use `DownstreamObservabilityPipeline` for the complete governed request flow:
validation, request-local context, one workflow decision, an optional
downstream call, and consistent completion evidence.

Most governed HTTP services use the pipeline and give it a configured
`GenAIObservabilityUtility`.

## 11. Boardroom Takeaway

```text
Core utility
    Creates protected and connected operational evidence

Downstream pipeline
    Applies the utility during governed service-to-service work
```

This design provides one traceable journey across services, agents, and tools.
It improves investigation and accountability while keeping business policy,
authentication, and authorization in the components that own them.

## 12. Implementation Checklist

- [ ] Settings are validated during startup.
- [ ] One core utility is created when context is enabled.
- [ ] Governed services create and reuse one downstream pipeline.
- [ ] Required enterprise headers are validated.
- [ ] Conflicting payload and header values are rejected.
- [ ] The upstream trace ID is retained and a local span is created.
- [ ] Only approved headers are sent downstream.
- [ ] The outbound adapter adds authentication.
- [ ] The correct platform, agent, or tool payload is used.
- [ ] Eligible log values pass through DLP before delivery.
- [ ] Completion logs and spans contain matching IDs.
- [ ] Request-local context is cleared after success or failure.