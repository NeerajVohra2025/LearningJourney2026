"""Thin Python adapter for Google Cloud Sensitive Data Protection.

The module exposes two synchronous text operations backed by enterprise-managed
Google Cloud DLP templates: inspect text and return detected Google InfoType
names, or de-identify text using approved inspection and transformation
templates.

The utility deliberately contains no application workflow, policy thresholds,
credential handling, retry orchestration, logging, or web-service concerns.
Those responsibilities remain with the calling application and the managed
Google Cloud platform.
"""
from __future__ import annotations
from google.cloud import dlp_v2


class DlpUtility:
    """Call Google Cloud DLP through a small, reusable application adapter.

    The class is the outbound provider adapter in a hexagonal architecture. A
    host application supplies plain text and receives simple Python values,
    while this adapter owns request construction and the Google SDK call.

    One instance can be created during application startup and reused for
    multiple synchronous calls. The caller remains responsible for deciding
    when inspection or de-identification is required, how failures are handled,
    and whether returned content may continue through the workflow.

    Attributes:
        parent: Google resource parent in
            projects/{project_id}/locations/{location} format.
        inspect_template_name: Full resource name of the enterprise inspection
            template used by both public operations.
        deidentify_template_name: Full resource name of the enterprise
            de-identification template used by deidentify_content.
        timeout_seconds: Maximum duration supplied to each Google API call.
        client: Google Cloud DLP service client used for provider requests.
    """

    def __init__(self, project_id: str, location: str, inspect_template_name: str,
                 deidentify_template_name: str, timeout_seconds: float = 30.0,
                 client: dlp_v2.DlpServiceClient | None = None) -> None:
        """Initialize the adapter with governed Google Cloud resources.

        Args:
            project_id: Google Cloud project containing the DLP templates.
            location: Google Cloud location shared by the parent and templates.
            inspect_template_name: Full resource name of an existing
                enterprise-managed inspection template.
            deidentify_template_name: Full resource name of an existing
                enterprise-managed de-identification template.
            timeout_seconds: Positive deadline, in seconds, passed to every
                provider call. Defaults to 30 seconds.
            client: Optional preconstructed DLP client. Supplying a client is
                useful for dependency injection and isolated tests; otherwise,
                the Google SDK creates one using Application Default
                Credentials.

        Raises:
            ValueError: If the project, location, or either template name is
                blank, or if timeout_seconds is not greater than zero.

        Notes:
            Construction performs validation and client initialization only.
            It does not invoke a DLP content operation.
        """
        if not project_id.strip() or not location.strip():
            raise ValueError("project_id and location are required")
        if not inspect_template_name.strip() or not deidentify_template_name.strip():
            raise ValueError("inspect and de-identify template names are required")
        if timeout_seconds <= 0:
            raise ValueError("timeout_seconds must be greater than zero")
        self.parent = f"projects/{project_id}/locations/{location}"
        self.inspect_template_name = inspect_template_name
        self.deidentify_template_name = deidentify_template_name
        self.timeout_seconds = timeout_seconds
        self.client = client or dlp_v2.DlpServiceClient()

    def inspect_content(self, text: str) -> tuple[str, ...]:
        """Inspect text and return InfoType names detected by Google Cloud DLP.

        The method sends one inspect_content request using the configured
        parent, inspection template, timeout, and supplied text. It preserves
        the provider's finding order and does not deduplicate, rank, suppress,
        or reinterpret findings.

        Args:
            text: Non-empty text to inspect. The caller must ensure that sending
                this content to the configured Google project is permitted.

        Returns:
            A tuple containing the info_type.name from every provider finding.
            The tuple is empty when Google reports no findings.

        Raises:
            ValueError: If text is empty.
            google.api_core.exceptions.GoogleAPICallError: If the provider call
                fails. Google SDK subclasses convey the specific failure.
            google.api_core.exceptions.RetryError: If Google SDK retry handling
                is exhausted.

        Notes:
            The method does not log the supplied text and does not decide
            whether detected content should be blocked or transformed.
        """
        if not text:
            raise ValueError("text is required")
        response = self.client.inspect_content(request={
            "parent": self.parent,
            "inspect_template_name": self.inspect_template_name,
            "item": {"value": text},
        }, timeout=self.timeout_seconds)
        return tuple(f.info_type.name for f in getattr(response.result, "findings", ()))

    def deidentify_content(self, text: str) -> str:
        """Return text transformed by the configured DLP templates.

        The method sends one deidentify_content request. Google applies the
        inspection template to locate sensitive data and the de-identification
        template to transform matching values.

        Args:
            text: Non-empty text to protect. The caller must ensure that sending
                this content to the configured Google project is permitted.

        Returns:
            The transformed text from response.item.value. Transformation
            details are controlled entirely by the deployed Google templates.

        Raises:
            ValueError: If text is empty.
            google.api_core.exceptions.GoogleAPICallError: If the provider call
                fails. Google SDK subclasses convey the specific failure.
            google.api_core.exceptions.RetryError: If Google SDK retry handling
                is exhausted.

        Notes:
            The method does not compare the protected value with the original,
            persist either value, or decide how the result is used.
        """
        if not text:
            raise ValueError("text is required")
        response = self.client.deidentify_content(request={
            "parent": self.parent,
            "inspect_template_name": self.inspect_template_name,
            "deidentify_template_name": self.deidentify_template_name,
            "item": {"value": text},
        }, timeout=self.timeout_seconds)
        return response.item.value