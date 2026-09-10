# Platform SDK DLP Safety Utility

## Stakeholder Demo and Service Integration Guide

## 1. Summary

The Platform SDK DLP safety utility uses Google Cloud Sensitive Data
Protection to de-identify text at approved agent and LLM boundaries. In the
current safety pipeline, DLP runs before Model Armor so that downstream safety
evaluation and model processing receive the de-identified value.

```text
Application text
    |
    v
Safety wrapper
    |
    v
DlpSafetyPipeline
    |
    |  DLPClient.deidentify_content(text)
    v
Google Cloud Sensitive Data Protection
    |
    +--> changed text -> return de-identified text + MATCH_FOUND
    +--> unchanged text -> return original text + NO_MATCH
    +--> provider error -> raise SafetyProviderError
    |
    v
Model Armor (next stage in the composite pipeline)
```

DLP transforms text; it does not authenticate callers, authorize requests,
classify business intent, or decide whether content is safe. Model Armor owns
the allow/block evaluation in the composite pipeline.

## Business Capability Summary

The DLP capability helps protect sensitive business and personal information
when approved AI services process text. It applies centrally managed Google
Cloud Sensitive Data Protection rules before text reaches the AI model and
before an AI-generated response is returned, reducing unnecessary exposure of
identified sensitive values.

From a business perspective, the capability:

- **Reduces sensitive-data exposure** by transforming detected information
  according to approved inspection and de-identification policies.
- **Protects both sides of an AI interaction** by applying the control to
  configured user inputs and AI-generated outputs.
- **Applies protection early** by de-identifying text before Model Armor safety
  evaluation and before permitted content reaches the AI model or user.
- **Promotes consistent data handling** through shared Platform SDK controls
  and centrally governed DLP templates instead of separate service-specific
  implementations.
- **Supports privacy and compliance objectives** by enabling approved masking,
  replacement, redaction, or other transformations defined by enterprise data
  policy.
- **Provides safe operational evidence** by recording that de-identification
  occurred using request and trace identifiers without placing raw sensitive
  text in the event.
- **Fails safely** when the required DLP service or configuration is
  unavailable, rather than intentionally sending the original text onward.
- **Keeps accountability clear** because DLP transforms configured content but
  does not authenticate users, authorize requests, classify business data, or
  make the final allow-or-block safety decision.

In simple terms, this capability acts as a privacy filter around approved AI
interactions: it identifies and transforms sensitive text according to the
organization's policy before that text proceeds to the next stage. Data
classification, template approval, access control, monitoring, retention, and
incident response remain owned by the appropriate enterprise teams.

## 2. What stakeholders gain

| Stakeholder question | Utility capability |
|---|---|
| Is sensitive text handled before model safety evaluation? | Runs DLP before Model Armor |
| Can enterprise inspection and de-identification policy be reused? | Supports configured Google DLP templates |
| Is input and output text covered? | Filters both configured agent and LLM boundaries |
| Is a transformation observable? | Emits `dlp_input_deidentified` or `dlp_output_deidentified` |
| Does a provider failure silently pass raw text? | No; it raises `SafetyProviderError` |

## 3. Package, class, and method map

```text
platform_sdk
|
+-- adapters/llm/safety/dlp.py
|   +-- DLPClient
|       +-- inspect_content(text, ...)
|       +-- deidentify_content(text, ...)
|
+-- safety/config.py
|   +-- SafetyConfig
|
+-- safety/factory.py
|   +-- build_agent_safety_pipeline(config)
|   +-- build_llm_safety_pipeline(config)
|
+-- safety/pipeline.py
    +-- DlpSafetyPipeline
    +-- CompositeSafetyPipeline
```

| Component | Meaning |
|---|---|
| `DLPClient` | Thin adapter over Google Cloud DLP |
| `DlpSafetyPipeline` | Converts the provider response into SDK input/output results |
| `CompositeSafetyPipeline` | Runs DLP and then Model Armor in order |
| `SafetyConfig` | Selects provider, templates, and protected boundaries |

The runtime dependency is `google-cloud-dlp>=3.18.0` and the SDK supports
Python 3.11 through 3.13.

### Google API and SDK method map

| Platform SDK method | Google Python client method | Google API operation | Request/result used |
|---|---|---|---|
| `DLPClient.inspect_content()` | `dlp_v2.DlpServiceClient.inspect_content()` | `projects.locations.content.inspect` | Sends `parent`, `item`, and optional inspect template/config; returns `InspectContentResponse` |
| `DLPClient.deidentify_content()` | `dlp_v2.DlpServiceClient.deidentify_content()` | `projects.locations.content.deidentify` | Sends `parent`, `item`, and optional inspect/de-identification templates/configs; pipeline reads `response.item.value` |

The SDK client methods are `inspect_content` and `deidentify_content`; there is
no DLP `get_count` method in this flow. Template policy determines InfoTypes,
likelihood thresholds, masking, replacement, redaction, and transformations.

## 4. End-to-end behavior

```text
Incoming prompt
  -> DLP de-identification
  -> Model Armor prompt evaluation
  -> allowed: sanitized prompt reaches the model
  -> blocked: model is not called

Model response
  -> DLP de-identification
  -> Model Armor response evaluation
  -> allowed: sanitized response reaches the caller
  -> blocked: response is not returned
```

For an agent boundary, the same order is applied to the incoming ADK message
and final response text. Non-final agent events are not output-filtered.

## 5. Service integration

### Step 1: Configure both DLP and Model Armor

The factory currently exposes DLP through the `dlp_model_armor` composite
provider; there is no DLP-only provider selection.

```python
from platform_sdk.safety import SafetyConfig

safety = SafetyConfig(
    enabled=True,
    provider="dlp_model_armor",
    project_id="my-gcp-project",
    location="us-central1",
    inspect_template_id="approved-inspect-template",
    deidentify_template_id="approved-deidentify-template",
    model_armor_template_id="approved-model-armor-template",
    filter_llm_io=True,
    filter_agent_io=False,
)
```

Set `dlp_project_id` when DLP templates live in a different project. If it is
unset, DLP uses `project_id`. The inspect template is optional in SDK
validation; the de-identification template is required for the composite
provider.

### Step 2: Attach configuration at the required boundary

Pass `safety` into the Platform SDK LLM generation runtime configuration to
protect direct generation, or into the agent runner builder to protect agent
input and final output. Enable only the boundary the service actually uses.

```python
pipeline = build_llm_safety_pipeline(safety)

input_result = await pipeline.filter_input(user_text)
safe_prompt = input_result.sanitized_text

output_result = await pipeline.filter_output(model_text)
safe_response = output_result.final_response
```

Normal service integration should use the SDK safety-aware runtime or runner;
calling the pipeline directly is useful for controlled verification.

### Step 3: Handle provider failures

```python
from platform_sdk.safety import SafetyProviderError

try:
    result = await runtime.generate_text(request)
except SafetyProviderError:
    # Return the service's approved safe failure contract.
    raise
```

Do not fall back to sending the original value when DLP is required.

## 6. Google Cloud setup

Enable `dlp.googleapis.com`, provision the configured inspect and
de-identification templates, and give the workload identity only the
permissions needed to use them. Use Application Default Credentials through
Cloud Run, GKE, VM, or Workload Identity; do not place service-account keys in
code or images.

The configured `location` is used in resource names:

```text
projects/<PROJECT_ID>/locations/<LOCATION>/inspectTemplates/<TEMPLATE_ID>
projects/<PROJECT_ID>/locations/<LOCATION>/deidentifyTemplates/<TEMPLATE_ID>
```

## 7. Failure and boundary behavior

| Condition | Result |
|---|---|
| Safety or the selected boundary is disabled | `NoOpSafetyPipeline` returns original text |
| Required project, location, or de-identification template is missing | `SafetyConfigurationError` during construction |
| DLP call fails | `SafetyProviderError`; raw text is not intentionally passed onward |
| Provider response contains changed text | Sanitized text and `MATCH_FOUND` |
| Provider response contains unchanged text | Original text and `NO_MATCH` |
| Provider response has no extractable text | Current pipeline retains the original text |
| Composite pipeline is enabled | DLP output is passed to Model Armor |

The last two behaviors are important governance considerations: template
policy and provider-response monitoring remain deployment responsibilities.

## 8. Verification checklist

- [ ] DLP and Model Armor APIs and templates exist in the configured location.
- [ ] Runtime identity can use the approved templates.
- [ ] `provider="dlp_model_armor"` is selected.
- [ ] The intended agent or LLM boundary flag is enabled.
- [ ] A known test identifier is transformed as the template specifies.
- [ ] Model Armor receives the transformed value.
- [ ] A DLP outage produces a safe provider failure, not an unfiltered model call.
- [ ] Logs contain event names and identifiers, not raw sensitive text.

## 9. Stakeholder demonstration

1. Submit an approved synthetic prompt containing a test identifier.
2. Show that DLP returns the policy-defined replacement.
3. Show `dlp_input_deidentified` with request and trace identifiers.
4. Show that Model Armor evaluates the replacement, not the original value.
5. Return an approved synthetic model response and repeat the output flow.
6. Simulate a provider failure and confirm the request fails safely.

```text
Approved text boundary
  -> enterprise DLP template
  -> de-identified text
  -> Model Armor evaluation
  -> model or caller only when allowed
```

Template ownership, data classification, IAM, retention, monitoring, and the
service's business failure response remain owned by the appropriate enterprise
teams.