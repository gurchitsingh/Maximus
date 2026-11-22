"""In-memory per-process limiter (CONTRACTS 3.1): GET /v1/* per client IP, and the chat burst limits. Nothing is stored on disk."""
import time
from collections import defaultdict, deque

from app.errors import ApiError


class RateLimiter:
    def __init__(self, limit: int, window_s: int = 60, scope: str = "ip"):
        self.limit, self.window_s, self.scope = limit, window_s, scope
        self.hits: dict[str, deque] = defaultdict(deque)

    def check(self, key: str) -> None:
        now = time.monotonic()
        q = self.hits[key]
        while q and now - q[0] >= self.window_s:
            q.popleft()
        if len(q) >= self.limit:
            wait = max(1, int(self.window_s - (now - q[0])) + 1)
            raise ApiError(429, "rate_limited", "Too many requests.", retry_after_s=wait, details={"scope": self.scope})
        q.append(now)

    def reset(self) -> None:
        self.hits.clear()
