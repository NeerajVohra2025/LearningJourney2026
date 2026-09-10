"""Thin Python adapter for two Google Cloud Model Armor operations.

The module exposes provider-aligned methods for sanitizing a user prompt before
downstream execution and sanitizing a model response before external release.
It validates required values, constructs official SDK requests, invokes one
enterprise-managed template, and returns Google's typed response unchanged.

The adapter deliberately contains no allow/block policy, response rewriting,
workflow orchestration, retry strategy, telemetry pipeline, or web-service
concerns. Those responsibilities remain with the host application and managed
Google Cloud platform.
"""
from __future__ import annotations

from google.api_core.client_options import ClientOptions
from google.cloud import modelarmor_v1


class ArmorUtility:
    """Invoke an enterprise Model Armor template through a reusable adapter.

    This class is the outbound security-provider adapter in a hexagonal
    architecture. It keeps the application-facing boundary small while
    preserving Google's typed response so the host can apply its approved
    enforcement and failure policy.

    A configured instance can be reused for synchronous prompt and response
    sanitization calls. Supplying a preconstructed client supports isolated
    tests without changing the production request path.

    Attributes:
        template_name: Full Model Armor template resource name used by both
            sanitization operations.
        timeout_seconds: Positive deadline passed to each provider call.
        client: Configured Google Model Armor SDK client.
    """

    def __init__(self, template_name: str, location: str,
                  timeout_seconds: float = 30.0,
                  client: modelarmor_v1.ModelArmorClient | None = None) -> None:
        """Initialize the adapter for one governed Model Armor template.

        Args:
            template_name: Full template resource name in
                projects/{project}/locations/{location}/templates/{template}
                format.
            location: Template location used to select the Model Armor endpoint.
                Regional locations use the required regional endpoint; global
                uses the SDK default endpoint.
            timeout_seconds: Positive request deadline in seconds. Defaults to
                30 seconds.
            client: Optional preconstructed ModelArmorClient. When omitted, the
                utility creates a client using Application Default Credentials.

        Raises:
            ValueError: If template_name or location is blank, or if
                timeout_seconds is not greater than zero.

        Notes:
            Construction configures the client only and does not sanitize
            content or call Model Armor.
        """
        if not template_name.strip() or not location.strip():
            raise ValueError("template_name and location are required")
        if timeout_seconds <= 0:
            raise ValueError("timeout_seconds must be greater than zero")
        endpoint = (f"modelarmor.{location}.rep.googleapis.com"
                    if location.lower() != "global"
                    else modelarmor_v1.ModelArmorClient.DEFAULT_ENDPOINT)
        self.template_name = template_name
        self.timeout_seconds = timeout_seconds
        self.client = client or modelarmor_v1.ModelArmorClient(
            client_options=ClientOptions(api_endpoint=endpoint))

    def sanitize_user_prompt(
            self, text: str) -> modelarmor_v1.SanitizeUserPromptResponse:
        """Sanitize a user prompt with the configured Model Armor template.

        Args:
            text: Non-empty user-supplied prompt evaluated before model, agent,
                or tool execution.

        Returns:
            Google's typed SanitizeUserPromptResponse. The host should inspect
            invocation_result, filter_match_state, filter_results, and any
            configured transformed-content fields.

        Raises:
            ValueError: If text is empty.
            Exception: Authentication, authorization, deadline, transport, and
                provider failures propagate to the caller unchanged.

        Notes:
            The method makes exactly one provider call. It does not calculate
            an allowed flag or decide whether downstream execution may continue.
        """
        if not text or not text.strip():
            raise ValueError("text is required")
        return self.client.sanitize_user_prompt(
            request=modelarmor_v1.SanitizeUserPromptRequest(
                name=self.template_name,
                user_prompt_data=modelarmor_v1.DataItem(text=text),
            ),
            timeout=self.timeout_seconds,
        )

    def sanitize_model_response(
            self, text: str) -> modelarmor_v1.SanitizeModelResponseResponse:
        """Sanitize model output with the configured Model Armor template.

        Args:
            text: Non-empty model or tool response evaluated before release to
                a user or external system.

        Returns:
            Google's typed SanitizeModelResponseResponse. The host should
            inspect invocation_result, filter_match_state, filter_results, and
            any configured transformed-content fields.

        Raises:
            ValueError: If text is empty.
            Exception: Authentication, authorization, deadline, transport, and
                provider failures propagate to the caller unchanged.

        Notes:
            The method makes exactly one provider call. It does not calculate
            an allowed flag, modify text, or release content.
        """
        if not text or not text.strip():
            raise ValueError("text is required")
        return self.client.sanitize_model_response(
            request=modelarmor_v1.SanitizeModelResponseRequest(
                name=self.template_name,
                model_response_data=modelarmor_v1.DataItem(text=text),
            ),
            timeout=self.timeout_seconds,
        )