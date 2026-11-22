"""LLM providers behind one small interface (CONTRACTS 4.1 step 7). Tests swap in fakes; no test calls a real API.

A provider gets the system prompt and the conversation turns, never the install id. Any failure (HTTP error,
timeout, provider 429, refusal/block, empty reply) raises ProviderError so the chain moves to the next provider.
Keys are sent in headers only (never in URLs) and are never logged.
"""
from dataclasses import dataclass
from typing import Protocol

import httpx

from app.config import settings

TEMPERATURE = 0.2
MAX_OUTPUT_TOKENS = 400
OPENROUTER_URL = "https://openrouter.ai/api/v1/chat/completions"
GEMINI_URL = "https://generativelanguage.googleapis.com/v1beta/models/{model}:generateContent"


@dataclass(frozen=True)
class Turn:
    role: str  # "user" | "assistant"
    text: str


class ProviderError(Exception):
    """The provider gave no usable reply. `reason` is a short code for logs (never message text)."""

    def __init__(self, reason: str):
        super().__init__(reason)
        self.reason = reason


class Provider(Protocol):
    name: str

    def complete(self, system: str, turns: list[Turn]) -> str: ...


def _post(client: httpx.Client | None, url: str, headers: dict, body: dict, timeout: float) -> dict:
    own = client is None
    c = client or httpx.Client()
    try:
        r = c.post(url, headers=headers, json=body, timeout=timeout)
    except httpx.TimeoutException:
        raise ProviderError("timeout") from None
    except httpx.HTTPError:
        raise ProviderError("http_error") from None
    finally:
        if own:
            c.close()
    if r.status_code == 429:
        raise ProviderError("provider_429")
    if r.status_code != 200:
        raise ProviderError(f"http_{r.status_code}")
    try:
        return r.json()
    except ValueError:
        raise ProviderError("bad_json") from None


class OpenRouterProvider:
    name = "openrouter"

    def __init__(self, api_key: str, model: str, timeout_s: float, client: httpx.Client | None = None):
        self.api_key, self.model, self.timeout_s, self.client = api_key, model, timeout_s, client

    def complete(self, system: str, turns: list[Turn]) -> str:
        messages = [{"role": "system", "content": system}]
        messages += [{"role": t.role, "content": t.text} for t in turns]
        body = {"model": self.model, "messages": messages, "temperature": TEMPERATURE, "max_tokens": MAX_OUTPUT_TOKENS}
        headers = {"Authorization": f"Bearer {self.api_key}", "X-Title": "Maximus"}
        data = _post(self.client, OPENROUTER_URL, headers, body, self.timeout_s)
        if not isinstance(data, dict) or data.get("error"):  # OpenRouter can report errors inside a 200
            raise ProviderError("provider_error")
        try:
            text = data["choices"][0]["message"]["content"]
        except (KeyError, IndexError, TypeError):
            raise ProviderError("bad_shape") from None
        if not isinstance(text, str) or not text.strip():
            raise ProviderError("empty")
        return text


class GeminiProvider:
    name = "gemini"

    def __init__(self, api_key: str, model: str, timeout_s: float, client: httpx.Client | None = None):
        self.api_key, self.model, self.timeout_s, self.client = api_key, model, timeout_s, client

    def complete(self, system: str, turns: list[Turn]) -> str:
        contents = [{"role": "model" if t.role == "assistant" else "user", "parts": [{"text": t.text}]} for t in turns]
        body = {
            "systemInstruction": {"parts": [{"text": system}]},
            "contents": contents,
            # thinkingBudget 0: thinking tokens would otherwise eat the 400-token output budget (2.5 Flash)
            "generationConfig": {"temperature": TEMPERATURE, "maxOutputTokens": MAX_OUTPUT_TOKENS,
                                 "thinkingConfig": {"thinkingBudget": 0}},
        }
        headers = {"x-goog-api-key": self.api_key}
        data = _post(self.client, GEMINI_URL.format(model=self.model), headers, body, self.timeout_s)
        try:
            cand = data["candidates"][0]
            parts = cand["content"]["parts"]
        except (KeyError, IndexError, TypeError):
            raise ProviderError("blocked_or_empty") from None
        if cand.get("finishReason") not in (None, "STOP", "MAX_TOKENS"):
            raise ProviderError("blocked")
        text = "".join(p.get("text", "") for p in parts if isinstance(p, dict) and not p.get("thought"))
        if not text.strip():
            raise ProviderError("empty")
        return text


def default_providers() -> list[Provider]:
    """OpenRouter first, then Gemini (CONTRACTS 4.1 step 7). A provider without a key is left out."""
    t = settings.chat_provider_timeout_s
    chain: list[Provider] = []
    if settings.openrouter_api_key:
        chain.append(OpenRouterProvider(settings.openrouter_api_key, settings.openrouter_model, t))
    if settings.gemini_api_key:
        chain.append(GeminiProvider(settings.gemini_api_key, settings.gemini_model, t))
    return chain
