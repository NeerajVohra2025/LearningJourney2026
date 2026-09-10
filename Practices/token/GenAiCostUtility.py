"""Reusable Vertex AI token, cost, prompt-governance, and cache adapter.

The module provides synchronous Python operations for token counting, local
cost estimation, content generation, bounded summarization, prompt-budget
decisions, and explicit cache lifecycle management. Managed Vertex AI services
perform model, tokenizer, and cache operations; configured rates and thresholds
remain caller-owned policy inputs.

This module is not a billing authority, workflow engine, session budget store,
retry framework, telemetry pipeline, or enforcement service. Host applications
own orchestration, durable state, observability, and final release decisions.
"""
from __future__ import annotations
from dataclasses import dataclass
from google import genai
from google.genai import types

@dataclass(frozen=True)
class CostEstimate:
    """Immutable configured cost estimate for one model interaction.

    Attributes:
        input_tokens: Non-negative request-token count used for estimation.
        output_tokens: Non-negative generated-token count used for estimation.
        input_cost_usd: Estimated request cost in US dollars.
        output_cost_usd: Estimated response cost in US dollars.
        total_cost_usd: Sum of input_cost_usd and output_cost_usd.

    Notes:
        Values use caller-supplied rates and are estimates, not Google invoices.
    """
    input_tokens:int; output_tokens:int; input_cost_usd:float; output_cost_usd:float; total_cost_usd:float
@dataclass(frozen=True)
class GenerationResult:
    """Immutable normalized result from one Vertex generation operation.

    Attributes:
        text: Non-empty generated model text.
        input_tokens: Full request-token count reported by Vertex.
        output_tokens: Candidate output-token count reported by Vertex.
        cached_tokens: Cached-content token count reported by Vertex, or zero.
        estimated_cost: Local estimate calculated from input and output usage.
    """
    text:str; input_tokens:int; output_tokens:int; cached_tokens:int; estimated_cost:CostEstimate
@dataclass(frozen=True)
class PromptDecision:
    """Immutable prompt-budget decision and its supporting token evidence.

    Attributes:
        text: Text approved for the caller's next step; it may be the original,
            a generated summary, or empty when processing must stop.
        original_tokens: Vertex token count for the original supplied text.
        final_tokens: Token count for the selected text or generated summary.
        action: Stable policy outcome such as allow, summarize, review,
            require_summarization, or a stop action.
        generation: Optional generation evidence when Vertex produced text.
        reason: Human-readable explanation for a stopped decision.
    """
    text:str; original_tokens:int; final_tokens:int; action:str; generation:GenerationResult|None=None; reason:str=""
@dataclass(frozen=True)
class CacheResult:
    """Immutable result from an explicit Vertex cache lifecycle operation.

    Attributes:
        cache_id: Provider cache resource name or identifier.
        status: Operation outcome returned by this adapter, currently created
            or deleted.
    """
    cache_id:str; status:str

class GenAiCostUtility:
    """Expose reusable Vertex operations behind a policy-neutral adapter.

    The class is an outbound provider adapter in a hexagonal architecture. It
    owns Vertex request construction, response normalization, and configured
    arithmetic. The host application owns scenario selection, enforcement,
    retries, logging, budget persistence, and output release.

    A configured instance can be reused for synchronous calls. Injecting a
    preconstructed client enables isolated tests without changing production
    call paths.
    """
    def __init__(self, project_id:str, location:str, model:str,
                 input_cost_per_1m_tokens:float, output_cost_per_1m_tokens:float,
                 api_version:str="v1", timeout_seconds:float=30,
                 max_output_tokens:int=512, temperature:float=.2,
                  top_p:float=.8, top_k:int=40, cache_ttl_seconds:int=3600,
                  client:genai.Client|None=None)->None:
        """Initialize the adapter and its generation and cost configuration.

        Args:
            project_id: Google Cloud project used by the Vertex client.
            location: Vertex AI region used for model and cache operations.
            model: Vertex model identifier used by every provider call.
            input_cost_per_1m_tokens: Non-negative configured USD request rate
                per one million tokens.
            output_cost_per_1m_tokens: Non-negative configured USD response rate
                per one million tokens.
            api_version: Google Gen AI API version. Defaults to v1.
            timeout_seconds: Positive provider deadline in seconds.
            max_output_tokens: Maximum output tokens requested for generation.
            temperature: Sampling temperature passed to generation.
            top_p: Nucleus-sampling value passed to generation.
            top_k: Token-candidate sampling value passed to generation.
            cache_ttl_seconds: TTL used when explicit cached content is created.
            client: Optional injected Google Gen AI client.

        Raises:
            ValueError: If project, location, or model is blank; timeout is not
                positive; or either configured token rate is negative.

        Notes:
            When client is omitted, construction creates a Vertex-enabled
            Google Gen AI client using Application Default Credentials.
        """
        if not project_id.strip() or not location.strip() or not model.strip(): raise ValueError("project_id, location, and model are required")
        if timeout_seconds<=0: raise ValueError("timeout_seconds must be greater than zero")
        if min(input_cost_per_1m_tokens,output_cost_per_1m_tokens)<0: raise ValueError("token rates cannot be negative")
        if max_output_tokens <= 0: raise ValueError("max_output_tokens must be greater than zero")
        if temperature < 0: raise ValueError("temperature cannot be negative")
        if not 0 <= top_p <= 1: raise ValueError("top_p must be between zero and one")
        if top_k <= 0: raise ValueError("top_k must be greater than zero")
        if cache_ttl_seconds <= 0: raise ValueError("cache_ttl_seconds must be greater than zero")
        self.model=model; self.input_rate=input_cost_per_1m_tokens; self.output_rate=output_cost_per_1m_tokens
        self.max_output_tokens=max_output_tokens; self.temperature=temperature; self.top_p=top_p; self.top_k=top_k; self.cache_ttl_seconds=cache_ttl_seconds
        self.client=client or genai.Client(vertexai=True,project=project_id,location=location,http_options=types.HttpOptions(api_version=api_version,timeout=int(timeout_seconds*1000)))

    def count_tokens(self,text:str)->int:
        """Return the Vertex tokenizer count for non-empty text.

        Args:
            text: Text to count using the configured Vertex model tokenizer.

        Returns:
            Integer total_tokens value returned by Vertex.

        Raises:
            ValueError: If text is empty or the response omits total_tokens.
            Exception: Provider authentication, authorization, deadline, and
                transport failures propagate to the caller unchanged.
        """
        if not text: raise ValueError("text is required")
        total=getattr(self.client.models.count_tokens(model=self.model,contents=text),"total_tokens",None)
        if total is None: raise ValueError("Vertex AI count_tokens response has no total_tokens")
        normalized = int(total)
        if normalized < 0: raise ValueError("Vertex AI count_tokens response is negative")
        return normalized

    def estimate_cost(self,input_tokens:int,output_tokens:int)->CostEstimate:
        """Calculate a local USD estimate from configured per-million rates.

        Args:
            input_tokens: Non-negative request-token count.
            output_tokens: Non-negative response-token count.

        Returns:
            CostEstimate containing separate request, response, and total costs.

        Raises:
            ValueError: If either token count is negative.

        Notes:
            This method performs local arithmetic only and makes no API call.
            The result is an estimate and must not be treated as a cloud bill.
        """
        if min(input_tokens,output_tokens)<0: raise ValueError("token counts cannot be negative")
        ic=input_tokens*self.input_rate/1_000_000; oc=output_tokens*self.output_rate/1_000_000
        return CostEstimate(input_tokens,output_tokens,ic,oc,ic+oc)

    def generate_content(self,prompt:str)->GenerationResult:
        """Generate text once and estimate cost from Vertex usage metadata.

        Args:
            prompt: Non-empty content sent to the configured model.

        Returns:
            GenerationResult with generated text, normalized usage fields,
            cached-token usage, and configured cost estimates.

        Raises:
            ValueError: If prompt is empty or Vertex returns no usable text.
            Exception: Provider failures propagate to the caller unchanged.

        Notes:
            Automatic function calling and model thinking are disabled. The
            method does not release, persist, or log generated text.
        """
        if not prompt: raise ValueError("prompt is required")
        response=self.client.models.generate_content(model=self.model,contents=prompt,config=types.GenerateContentConfig(
            automatic_function_calling=types.AutomaticFunctionCallingConfig(disable=True),max_output_tokens=self.max_output_tokens,
            thinking_config=types.ThinkingConfig(thinking_budget=0),
            temperature=self.temperature,top_p=self.top_p,top_k=self.top_k))
        text=str(getattr(response,"text","") or "").strip()
        if not text: raise ValueError("Vertex AI generate_content response has no text")
        usage=getattr(response,"usage_metadata",None)
        inp=self._usage(usage,"prompt_token_count","promptTokenCount"); out=self._usage(usage,"candidates_token_count","candidatesTokenCount"); cached=self._usage(usage,"cached_content_token_count","cachedContentTokenCount")
        return GenerationResult(text,inp,out,cached,self.estimate_cost(inp,out))

    def summarize(self,text:str,target_tokens:int)->GenerationResult:
        """Generate a bounded summary using the standard governance instruction.

        Args:
            text: Source text included in the summarization prompt.
            target_tokens: Requested summary ceiling written into the prompt.

        Returns:
            GenerationResult from the underlying generate_content call.

        Notes:
            The target is a model instruction, not a guaranteed hard limit.
            govern_prompt performs separate post-generation token checks.
        """
        if not text: raise ValueError("text is required")
        if target_tokens <= 0: raise ValueError("target_tokens must be greater than zero")
        return self.generate_content(f"Summarize the following text in no more than {target_tokens} tokens. Preserve decisions, constraints, risks, and required actions.\n\n{text}")

    def govern_prompt(self,text:str,max_input_tokens:int,target_input_tokens:int,
                       on_exceeded:str="allow",summarization_enabled:bool=False,
                       require_net_token_reduction:bool=False)->PromptDecision:
        """Evaluate text against the caller's configured prompt-budget policy.

        Args:
            text: Prompt text evaluated with the configured Vertex tokenizer.
            max_input_tokens: Maximum input-token threshold.
            target_input_tokens: Desired summary-token ceiling.
            on_exceeded: Action used when text exceeds the maximum. Supported
                values are allow, summarize, raise, review, and
                require_summarization.
            summarization_enabled: Whether the summarize action may invoke
                Vertex to produce a candidate summary.
            require_net_token_reduction: Whether summary output plus measured
                instruction overhead must be smaller than the original input.

        Returns:
            PromptDecision containing the action, selected text, token evidence,
            optional generation result, and stop reason.

        Raises:
            ValueError: If token counting fails, raise is configured for an
                oversized prompt, or on_exceeded is unsupported.

        Notes:
            The method returns evidence and an action; the host application
            remains responsible for enforcing that action.
        """
        supported = {"allow", "summarize", "raise", "review", "require_summarization"}
        if on_exceeded not in supported: raise ValueError(f"unsupported on_exceeded action: {on_exceeded}")
        if max_input_tokens <= 0 or target_input_tokens <= 0: raise ValueError("prompt token thresholds must be greater than zero")
        tokens=self.count_tokens(text)
        if tokens<=max_input_tokens or on_exceeded=="allow": return PromptDecision(text,tokens,tokens,"allow")
        if on_exceeded=="summarize" and summarization_enabled:
            generation=self.summarize(text,target_input_tokens); final=self.count_tokens(generation.text); overhead=max(generation.input_tokens-tokens,0)
            if final>target_input_tokens: return PromptDecision("",tokens,final,"stop_summary_over_target",generation,"generated summary exceeds target_input_tokens")
            if final>max_input_tokens: return PromptDecision("",tokens,final,"stop_summary_over_maximum",generation,"generated summary exceeds max_input_tokens")
            if require_net_token_reduction and final+overhead>=tokens: return PromptDecision("",tokens,final,"stop_no_net_token_reduction",generation,"summary plus overhead does not reduce caller tokens")
            return PromptDecision(generation.text,tokens,final,"summarize",generation)
        if on_exceeded=="raise": raise ValueError("prompt exceeds configured token budget")
        if on_exceeded in {"review","require_summarization"}: return PromptDecision(text,tokens,tokens,on_exceeded)
        raise ValueError(f"unsupported on_exceeded action: {on_exceeded}")

    def create_cache(self,contents:str,display_name:str="")->CacheResult:
        """Create explicit Vertex cached content with the configured TTL.

        Args:
            contents: Content stored in the provider-managed cache.
            display_name: Optional human-readable cache display name.

        Returns:
            CacheResult containing the provider identifier and created status.

        Raises:
            ValueError: If the provider response has no cache identifier.
            Exception: Provider failures propagate to the caller unchanged.

        Notes:
            Cache eligibility and minimum-size policy belong to the caller.
        """
        if not contents: raise ValueError("contents is required")
        response=self.client.caches.create(model=self.model,config=types.CreateCachedContentConfig(ttl=f"{self.cache_ttl_seconds}s",display_name=display_name or None,contents=[contents]))
        cache_id=str(getattr(response,"name","") or getattr(response,"id",""))
        if not cache_id: raise ValueError("Vertex cache response has no cache name")
        return CacheResult(cache_id,"created")
    def delete_cache(self,cache_id:str)->CacheResult:
        """Delete an explicit Vertex cached-content resource.

        Args:
            cache_id: Non-empty provider cache resource name or identifier.

        Returns:
            CacheResult containing the same identifier and deleted status.

        Raises:
            ValueError: If cache_id is empty.
            Exception: Provider failures propagate to the caller unchanged.
        """
        if not cache_id: raise ValueError("cache_id is required")
        self.client.caches.delete(name=cache_id); return CacheResult(cache_id,"deleted")
    @staticmethod
    def _usage(value:object,*names:str)->int:
        """Normalize one usage counter across supported SDK field names.

        Args:
            value: Usage metadata object, or None when metadata is unavailable.
            *names: Attribute names checked in priority order.

        Returns:
            The first present value converted to int, otherwise zero.
        """
        for name in names:
            found=getattr(value,name,None) if value is not None else None
            if found is not None:return int(found)
        return 0