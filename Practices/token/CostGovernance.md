# Platform SDK Token Usage Utility

## Stakeholder Demo and Service Integration Guide

## 1. Summary

The Platform SDK token usage utility records provider-reported token counts for
LLM generation, agent invocations, and embeddings in one structured event
shape. Events carry service, request, trace, operation, agent, provider, and
model identity so usage can be correlated with an operational journey.

```text
Model, agent, or embedding call
    |
    v
Provider response/events
    |
    | extract authoritative usage when present
    v
log_token_usage()
    |
    +--> validated agent observability event when configured
    |
    +--> standard structured logger fallback otherwise
```

The utility records counts; it does not estimate missing tokens, calculate
cost, enforce quotas, perform billing reconciliation, or retain prompt and
response content.

## Business Capability Summary

The Token Usage capability gives the organization a consistent way to record
how many tokens AI providers report for model generation, agent activity, and
embedding operations. It connects that usage to the responsible service,
operation, provider, model, request, and trace so business and technology teams
can understand where AI consumption occurs.

From a business perspective, the capability:

- **Improves AI cost transparency** by recording available input, output, and
  total token counts in one standard event format.
- **Shows where consumption occurs** by linking usage to a service, business or
  technical operation, AI agent, provider, and model.
- **Supports FinOps reporting** by creating consistent usage records that can
  be combined with an approved, effective-dated pricing catalog.
- **Enables operational investigation** by correlating token usage with the
  same request and trace identifiers used in service observability.
- **Distinguishes missing data from zero usage** so dashboards do not present
  unavailable provider telemetry as actual zero consumption.
- **Reduces duplicate implementation** through shared SDK integrations for
  direct model generation, agent invocations, and embeddings.
- **Protects business and customer content** because the usage event records
  metadata and token counts—not prompts, responses, embeddings, credentials,
  or chain-of-thought.
- **Keeps financial accountability clear** because the utility records
  provider-reported usage but does not calculate cost, set budgets, enforce
  quotas, reconcile invoices, or replace provider billing records.

In simple terms, this capability answers: **which AI service used which model,
for which operation, and how many tokens did the provider report?** It provides
the trusted usage foundation needed for reporting and future cost governance,
while pricing, budgets, billing reconciliation, and enforcement remain owned
by the appropriate platform and FinOps teams.

## 2. What stakeholders gain

| Stakeholder question | Utility capability |
|---|---|
| Which operation consumed tokens? | Records service, agent, and operation identity |
| Can usage be tied to a request? | Records request and trace IDs |
| Which provider and model reported usage? | Records provider and model names |
| Are input and output counts separated? | Records available input, output, and total counts |
| Is missing provider telemetry visible? | Sets `token_usage_available=false` |
| Are prompts or responses logged? | No; the token event contains metadata and counts only |

## 3. Package, class, and method map

```text
platform_sdk.token_usage
|
+-- TokenUsageContext
|   +-- service_name
|   +-- request_id
|   +-- trace_id
|   +-- operation_name
|   +-- agent_name
|   +-- agent_framework
|   +-- extra
|
+-- log_token_usage(...)
    +-- normalize optional integer counts
    +-- derive token_usage_available
    +-- try log_agent_observability_event(...)
    +-- fall back to logger.info(..., extra=structured_fields)
```

Automatic integrations currently include:

| Integration | Event name |
|---|---|
| Direct LLM generation runtime | `llm_token_usage_recorded` |
| Shared agent invocation helper | `agent_token_usage_recorded` |
| Google/OpenAI embedding adapters | `embedding_token_usage_recorded` |

### Google API and SDK method map

There are two distinct sources of token evidence. The current Platform SDK
implements post-call usage logging. The referenced GenAI Cost Governor also
demonstrates a separate pre-call counting operation.

| Purpose | Google Python SDK method or field | Result used | Current Platform SDK behavior |
|---|---|---|---|
| Count prompt tokens without generation | `google.genai.Client.models.count_tokens(model=..., contents=...)` (`models.countTokens`) | `CountTokensResponse.total_tokens` | Not currently called by `platform_sdk.token_usage` |
| Generate content | `google.genai.Client.models.generate_content(...)` (`models.generateContent`) | `response.usage_metadata` | Generation adapters normalize provider usage into `LLMGenerationResult` |
| Gemini input usage | `usage_metadata.prompt_token_count` | Provider-reported input tokens | Logged as `input_tokens` when available |
| Gemini output usage | `usage_metadata.candidates_token_count` | Provider-reported output tokens | Logged as `output_tokens` when available |
| Gemini total usage | `usage_metadata.total_token_count` when supplied | Provider-reported total tokens | Logged as `total_tokens` when available |
| Gemini cached usage | `usage_metadata.cached_content_token_count` | Provider-reported cached tokens | Not a field in the current common token-usage event |

The Google method is `models.count_tokens`, commonly wrapped by an application
method named `count_tokens`; it is not `get_count`. Counting before a request
and recording post-response usage answer different questions and may produce
different values because generated output, system instructions, tools,
thinking, and cached content can affect billed usage.

## 4. Event fields

| Field | Meaning |
|---|---|
| `service_name` | Service producing the usage event |
| `request_id` | Request correlation identity |
| `trace_id` | Distributed trace identity |
| `operation_name` / `operation` | Business or technical operation |
| `agent_name` | Agent identity, when applicable |
| `agent_framework` | Runtime/framework; defaults to `platform-sdk` |
| `model_provider` | Provider reported or selected by the adapter |
| `model_name` | Model reported or selected by the adapter |
| `input_tokens` | Provider-reported input count, when available |
| `output_tokens` | Provider-reported output count, when available |
| `total_tokens` | Provider-reported total count, when available |
| `token_usage_available` | True when any normalized count is present |

`log_token_usage` accepts only actual Python integers as counts; booleans,
strings, and other values normalize to `None`. It does not infer missing fields
or require `total_tokens` to equal the other fields in its logger fallback.
The enterprise `AgentLogPayload` path applies its own validation when all three
counts are present.

## 5. End-to-end flows

### Direct generation

```text
LLMGenerationRequest + TokenUsageContext
  -> provider runtime
  -> LLMGenerationResult with usage
  -> UsageLoggingLLMGenerationRuntime
  -> llm_token_usage_recorded
```

### Optional preflight count (not implemented by this module)

```text
Approved prompt
  -> google.genai Client.models.count_tokens(model, contents)
  -> CountTokensResponse.total_tokens
  -> host-owned threshold or review decision
  -> generation only when host policy permits
```

An owning service may add this through a reviewed cost-governance adapter. It
should not be presented as an existing capability of `log_token_usage`.

### Agent invocation

```text
ADK event stream
  -> extract usage from each event
  -> merge invocation totals
  -> agent_token_usage_recorded after stream completion
```

### Embedding

```text
embedding provider response
  -> extract response usage
  -> EmbeddingResult
  -> embedding_token_usage_recorded
```

If a model call fails before producing a usable response, the normal automatic
generation and embedding wrappers do not emit a successful usage event.

## 6. Service integration

### Step 1: Create context from trusted request metadata

```python
from platform_sdk.token_usage import TokenUsageContext

usage_context = TokenUsageContext(
    service_name="rca-service",
    request_id=request_id,
    trace_id=trace_id,
    operation_name="generate-root-cause",
    agent_name="rca-agent",
    agent_framework="google_adk",
)
```

Pass this context to the shared generation or embedding API. The adapters log
usage after they receive the provider response. The shared agent invocation
helper constructs its context from its service, agent, request, trace, and
runtime arguments.

### Step 2: Use the shared runtime wherever possible

```python
request = LLMGenerationRequest(
    prompt=approved_prompt,
    usage_context=usage_context,
)
result = await runtime.generate_text(request)
```

The runtime built by the Platform SDK factory includes the usage-logging
wrapper, so services should not log a second event for the same call.

### Step 3: Log custom provider usage when needed

```python
import logging

from platform_sdk.token_usage import log_token_usage

log_token_usage(
    logger=logging.getLogger("my_service.llm"),
    event_name="llm_token_usage_recorded",
    usage_context=usage_context,
    model_provider="GEMINI",
    model_name="approved-model-name",
    input_tokens=provider_usage.input_tokens,
    output_tokens=provider_usage.output_tokens,
    total_tokens=provider_usage.total_tokens,
)
```

Use only counts returned by the provider or SDK response. Do not tokenize
prompts locally and present estimates as authoritative provider usage.

For a host-owned preflight check using the Google Gen AI SDK, the provider call
has this shape:

```python
count_response = genai_client.models.count_tokens(
    model=model_name,
    contents=approved_prompt,
)
input_token_count = count_response.total_tokens
```

This call is intentionally separate from `log_token_usage`. The host owns
empty-input validation, timeout and retry policy, threshold enforcement, and
provider error handling.

### Step 4: Route structured events

When enterprise observability is configured,
`log_agent_observability_event` handles the event. If it returns false, the
utility emits `logger.info` with structured `extra` fields. Configure handlers
and formatters so this fallback remains structured in the service's logging
destination.

## 7. Aggregation guidance

Aggregate using event name, service, operation, provider, and model. Use
request and trace IDs for investigation, not as long-term cost centers. Keep
the distinction between unavailable counts and zero counts:

```text
token_usage_available=false -> provider supplied no usable count
token_usage_available=true + count=0 -> provider explicitly reported zero
```

Pricing changes independently of these events. Cost dashboards should join
usage to a governed, effective-dated price catalog rather than embedding price
assumptions in application code.

## 8. Failure and boundary behavior

| Condition | Result |
|---|---|
| One or more integer counts supplied | `token_usage_available=true` |
| No valid integer count supplied | Counts are null/omitted and availability is false |
| Enterprise observability accepts event | No fallback log is emitted |
| Enterprise observability is unavailable/disabled | Structured standard logger fallback is emitted |
| Provider call fails before a result | Automatic success-path event is generally not emitted |
| Provider omits output usage for embeddings | Input/total may still be recorded |

The utility currently returns `None`; callers do not receive a delivery
acknowledgement from `log_token_usage`.

## 9. Information that must never be added

- prompts, model responses, embeddings, or chain-of-thought;
- credentials, authorization headers, API keys, or cookies;
- complete customer request or response bodies;
- unrestricted exception text;
- sensitive values placed in `TokenUsageContext.extra`.

The `extra` mapping is caller-controlled and is included only in the standard
logger fallback. Restrict it to approved, non-sensitive scalar metadata.

## 10. Verification checklist

- [ ] Every model call has one trusted `TokenUsageContext`.
- [ ] Shared wrappers are used instead of duplicate manual logging.
- [ ] Counts come from provider responses/events.
- [ ] Missing counts produce `token_usage_available=false`.
- [ ] Request and trace IDs correlate with operational telemetry.
- [ ] Enterprise and fallback logging paths preserve structured fields.
- [ ] No prompt, response, embedding, credential, or sensitive extra is logged.
- [ ] Dashboards do not interpret missing usage as zero.
- [ ] Cost reports use a governed effective-dated price source.

## 11. Stakeholder demonstration

1. Execute one approved LLM request with known request and trace IDs.
2. Show the `llm_token_usage_recorded` event and its provider/model/counts.
3. Open the related operational event using the same trace ID.
4. Run an agent invocation and show one merged invocation usage event.
5. Run an embedding request and show its available input/total usage.
6. Use a test provider response without counts and show availability is false.

```text
Provider-reported counts
  -> one common event contract
  -> request and trace correlation
  -> governed aggregation and cost enrichment
```

Provider accuracy, pricing, budgets, quota enforcement, billing reconciliation,
retention, dashboards, and alerting remain owned by the appropriate platform
and FinOps teams.