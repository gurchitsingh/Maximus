"""A scripted stand-in for an LLM provider (CONTRACTS 10: chat tests use a fake provider, never a real API)."""
from app.services.chat.providers import ProviderError, Turn


class FakeProvider:
    """Returns scripted replies (the last one repeats), or calls `fn(system, turns)`, or raises `error`.
    Records every call so tests can inspect exactly what a provider would have been sent."""

    def __init__(self, name: str = "fake", replies: list[str] | None = None, fn=None, error: Exception | None = None):
        self.name, self.replies, self.fn, self.error = name, list(replies or []), fn, error
        self.calls: list[tuple[str, list[Turn]]] = []

    def complete(self, system: str, turns: list[Turn]) -> str:
        self.calls.append((system, list(turns)))
        if self.error is not None:
            raise self.error
        if self.fn is not None:
            return self.fn(system, turns)
        return self.replies.pop(0) if len(self.replies) > 1 else self.replies[0]


def failing(name: str, reason: str = "http_500") -> FakeProvider:
    return FakeProvider(name, error=ProviderError(reason))
