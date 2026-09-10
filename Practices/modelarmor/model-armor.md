# Platform SDK Model Armor Safety Utility

## Stakeholder Demo and Service Integration Guide

## 1. Summary

The Platform SDK Model Armor safety utility applies Google Model Armor policy
to user prompts and model responses. SDK wrappers place this evaluation around
direct LLM generation and Google ADK agent execution.

```text
User or agent input
    |
    v
ModelArmorClient.evaluate_prompt()
    |
    +--> prompt injection/jailbreak match -> block input
    +--> SDP de-identification result -> use sanitized input
    +--> allowed -> call model or agent

Model or final agent output
    |
    v
ModelArmorClient.evaluate_response()
    |
    +--> configured harm threshold matched -> block output
    +--> allowed -> return output
```

Model Armor is a content-safety boundary. It does not authenticate users,
authorize tools, validate business entitlements, or replace model/provider
safety settings.

## Business Capability Summary

The Model Armor capability provides a consistent safety checkpoint for
AI-enabled business services. It reviews information before it is sent to an
AI model and checks the generated response before it is shared with a user.
This helps the organization adopt AI while applying centrally managed safety
standards across participating services.

From a business perspective, the capability:

- **Reduces unsafe AI interactions** by identifying prompt-injection and
  jailbreak attempts before the AI service processes them.
- **Protects sensitive information** by using configured data-protection rules
  to sanitize supported sensitive content before processing.
- **Prevents harmful content from being released** by checking AI responses
  against approved categories and risk thresholds.
- **Applies policy consistently** through a shared Platform SDK integration,
  reducing the need for each product team to build its own safety controls.
- **Supports audit and oversight** through structured safety decisions linked
  to request and trace identifiers, without recording the prompt or response
  text in safety events.
- **Fails safely** when the protection service is unavailable or incorrectly
  configured, rather than silently allowing an unprotected AI interaction.
- **Keeps accountability clear** because Model Armor provides content-safety
  screening but does not replace user authentication, business authorization,
  tool controls, human review, monitoring, or incident management.

In simple terms, Model Armor acts as a safety gate around AI conversations:
it checks what goes into the AI service and what comes back out, applying the
organization's approved safety policy at both points.

## 2. What stakeholders gain

| Stakeholder question | Utility capability |
|---|---|
| Is prompt injection checked before execution? | Evaluates prompts before the model or agent runs |
| Are model responses checked before release? | Evaluates direct LLM output and final agent output |
| Can policy be centrally managed? | Uses a named Google Model Armor template |
| Are blocked decisions consistent? | Raises typed input/output exceptions through wrappers |
| Can support teams see decisions safely? | Emits structured safety events without prompt/response text |

## 3. Package, class, and method map

```text
platform_sdk
|
+-- adapters/llm/safety/model_armor.py
|   +-- ModelArmorClient
|       +-- evaluate_prompt(prompt)
|       +-- evaluate_response(response_text)
|
+-- middleware/input_filter.py
|   +-- InputFilter.process(user_input)
|
+-- middleware/output_filter.py
|   +-- OutputFilter.process(llm_response)
|
+-- safety/factory.py
|   +-- build_agent_safety_pipeline(config)
|   +-- build_llm_safety_pipeline(config)
|
+-- safety/wrappers.py
    +-- SafetyAwareLLMGenerationRuntime
    +-- SafetyAwareAgentRunner
```

The runtime dependency is `google-cloud-modelarmor>=0.7.0` and the SDK
supports Python 3.11 through 3.13.

### Google API and SDK method map

| Platform SDK method | Google Python client method | Typed Google request | Google API operation/result |
|---|---|---|---|
| `ModelArmorClient.evaluate_prompt()` | `modelarmor_v1.ModelArmorClient.sanitize_user_prompt()` | `SanitizeUserPromptRequest(name=template_name, user_prompt_data=DataItem(text=prompt))` | `projects.locations.templates.sanitizeUserPrompt`; returns `SanitizeUserPromptResponse` |
| `ModelArmorClient.evaluate_response()` | `modelarmor_v1.ModelArmorClient.sanitize_model_response()` | `SanitizeModelResponseRequest(name=template_name, model_response_data=DataItem(text=response_text))` | `projects.locations.templates.sanitizeModelResponse`; returns `SanitizeModelResponseResponse` |

`evaluate_prompt` and `evaluate_response` are Platform SDK adapter names. The
actual Google client methods are `sanitize_user_prompt` and
`sanitize_model_response`; Model Armor does not use a `get_count` method.
The adapter sends one typed request per evaluation and the middleware
interprets `sanitization_result`, `filter_match_state`, and `filter_results`.

## 4. Policy decisions represented by the SDK

### Input

`InputFilter` blocks when the Model Armor `pi_and_jailbreak` result reports
`MATCH_FOUND`. If Model Armor supplies an SDP de-identification result, the
sanitized value replaces the original prompt. The SDK emits `input_blocked`
and, when applicable, `pii_sanitized`.

### Output

`OutputFilter` evaluates harassment, hate speech, dangerous content, and
sexually explicit content. The current SDK threshold map blocks:

| Category | Blocking confidence values |
|---|---|
| Harassment | `LOW_AND_ABOVE`, `MEDIUM_AND_ABOVE`, `HIGH` |
| Hate speech | `LOW_AND_ABOVE`, `MEDIUM_AND_ABOVE`, `HIGH` |
| Dangerous content | `LOW_AND_ABOVE`, `MEDIUM_AND_ABOVE`, `HIGH` |
| Sexually explicit | `MEDIUM_AND_ABOVE`, `HIGH` |

The SDK emits `output_blocked` or `output_allowed` and includes category
labels, not the model response text.

## 5. End-to-end runtime sequence

```text
Service -> safety wrapper : prompt
safety wrapper -> Model Armor : sanitize_user_prompt(SanitizeUserPromptRequest)
Model Armor -> safety wrapper : filter results

blocked input:
  safety wrapper -> service : SafetyInputBlockedError

allowed input:
  safety wrapper -> model/agent : original or sanitized prompt
  model/agent -> safety wrapper : response
  safety wrapper -> Model Armor : sanitize_model_response(SanitizeModelResponseRequest)
  Model Armor -> safety wrapper : filter results

blocked output:
  safety wrapper -> service : SafetyOutputBlockedError

allowed output:
  safety wrapper -> service : response
```

For ADK agents, input text parts are filtered before `run_async`. Only final
response events are output-filtered; streaming/intermediate events require
separate service policy if they are exposed externally.

## 6. Service integration

### Step 1: Configure Model Armor

```python
from platform_sdk.safety import SafetyConfig

safety = SafetyConfig(
    enabled=True,
    provider="model_armor",
    project_id="my-gcp-project",
    location="us-central1",
    model_armor_template_id="approved-model-armor-template",
    filter_llm_io=True,
    filter_agent_io=False,
)
```

Use `filter_llm_io=True` for the shared direct-generation runtime and
`filter_agent_io=True` for the shared agent runner. If a boundary flag is
false, its factory returns a no-op pipeline even when safety is globally
enabled.

### Step 2: Build through shared SDK factories

The generation runtime and agent runner builders install safety-aware wrappers
from `SafetyConfig`. Services should use these integration points so filtering
cannot be accidentally placed after model execution.

For a controlled pipeline check:

```python
from platform_sdk.safety.factory import build_llm_safety_pipeline

pipeline = build_llm_safety_pipeline(safety)
input_result = await pipeline.filter_input("approved synthetic prompt")
output_result = await pipeline.filter_output("approved synthetic response")
```

### Step 3: Map typed failures to the service contract

```python
from platform_sdk.safety import (
    SafetyInputBlockedError,
    SafetyOutputBlockedError,
    SafetyProviderError,
)
from platform_sdk.safety.http import safety_business_failure_response

try:
    result = await runtime.generate_text(request)
except (SafetyInputBlockedError, SafetyOutputBlockedError, SafetyProviderError) as exc:
    return safety_business_failure_response(exc)
```

The provided HTTP helper returns a business failure payload with HTTP 200 and
places the semantic status (`403`, `503`, or `500`) in `details.status_code`.
Confirm that this convention matches the consuming API contract.

## 7. Google Cloud setup

Enable the Model Armor API, create the template in the configured project and
location, and grant the runtime workload identity only the required template
usage permissions. The adapter uses the regional REST endpoint:

```text
modelarmor.<LOCATION>.rep.googleapis.com
projects/<PROJECT_ID>/locations/<LOCATION>/templates/<TEMPLATE_ID>
```

Use Application Default Credentials. Do not store service-account keys in
source, images, or ordinary environment files.

## 8. Failure behavior

| Condition | Result |
|---|---|
| Safety or boundary flag disabled | Original text passes through a no-op pipeline |
| Project, location, or template ID missing | `SafetyConfigurationError` |
| Model Armor invocation or response processing fails | `SafetyProviderError` |
| Prompt injection/jailbreak match | `SafetyInputBlockedError`; model/agent is not invoked |
| Output exceeds current category threshold | `SafetyOutputBlockedError`; output is not released |
| Content allowed | Processing continues and a structured allowed event is emitted |

Provider errors fail the protected operation; the wrappers do not silently
bypass safety.

## 9. Verification checklist

- [ ] Model Armor API and approved template exist in the selected region.
- [ ] Runtime identity can evaluate content with the template.
- [ ] The correct agent and/or LLM boundary flags are enabled.
- [ ] A safe synthetic prompt reaches the runtime.
- [ ] A prompt-injection test is blocked before runtime execution.
- [ ] A harmful synthetic output is withheld from the caller.
- [ ] Provider failure maps to the approved service response.
- [ ] Safety logs contain request/trace identifiers but no prompt or response.
- [ ] Intermediate agent events are not exposed without an explicit policy.

## 10. Stakeholder demonstration

1. Submit an approved benign prompt and show the `output_allowed` event.
2. Submit an approved prompt-injection test and show that execution never begins.
3. Produce an approved harmful-output test and show that it is not returned.
4. Correlate safety events using request and trace identifiers.
5. Disable access to the test template and show the safe provider-failure path.

```text
Prompt policy before execution
  + response policy before release
  + safe structured evidence
  = consistent model safety boundary
```

Template policy, test-corpus approval, authorization, tool governance, human
review, IAM, monitoring, and incident response remain enterprise-owned controls.