"""In-memory per-process limiter: GET /v1/* per client IP per minute (CONTRACTS 3.1). Nothing is stored on disk."""
import time
from collections import defaultdict, deque

from app.errors import ApiError


class RateLimiter:
    def __init__(self, limit: int, window_s: int = 60):
        self.limit, self.window_s = limit, window_s
        self.hits: dict[str, deque] = defaultdict(deque)

    def check(self, key: str) -> None:
        now = time.monotonic()
        q = self.hits[key]
        while q and now - q[0] >= self.window_s:
            q.popleft()
        if len(q) >= self.limit:
            wait = max(1, int(self.window_s - (now - q[0])) + 1)
            raise ApiError(429, "rate_limited", "Too many requests.", retry_after_s=wait, details={"scope": "ip"})
        q.append(now)

    def reset(self) -> None:
        self.hits.clear()
