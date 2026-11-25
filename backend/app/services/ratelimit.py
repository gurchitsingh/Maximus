"""In-memory per-process limiter (CONTRACTS 3.1, 14.4): GET /v1/* per client IP, chat burst limits and the
auth limits. Nothing is stored on disk; a restart forgets every count."""
import threading
import time
from collections import deque

from app.errors import ApiError


class RateLimiter:
    MAX_KEYS = 100_000  # SECURITY_AUDIT L3: memory is bounded however many IPs or emails arrive

    def __init__(self, limit: int, window_s: int = 60, scope: str = "ip"):
        self.limit, self.window_s, self.scope = limit, window_s, scope
        self.hits: dict[str, deque] = {}
        self._lock = threading.Lock()

    def _trim(self, q: deque, now: float) -> None:
        while q and now - q[0] >= self.window_s:
            q.popleft()

    def _queue(self, key: str, now: float) -> deque:
        """The key's hits; a new key first evicts expired keys, then the oldest half, when the table is full."""
        q = self.hits.get(key)
        if q is None:
            if len(self.hits) >= self.MAX_KEYS:
                for k, old in list(self.hits.items()):
                    self._trim(old, now)
                    if not old:
                        del self.hits[k]
                if len(self.hits) >= self.MAX_KEYS:
                    for k in list(self.hits)[: len(self.hits) // 2]:  # insertion order: oldest keys first
                        del self.hits[k]
            q = self.hits[key] = deque()
        return q

    def _error(self, q: deque, now: float) -> ApiError:
        wait = max(1, int(self.window_s - (now - q[0])) + 1)
        return ApiError(429, "rate_limited", "Too many requests.", retry_after_s=wait, details={"scope": self.scope})

    def check(self, key: str) -> None:
        """Count one hit; 429 when the window is already full."""
        with self._lock:
            now = time.monotonic()
            q = self._queue(key, now)
            self._trim(q, now)
            if len(q) >= self.limit:
                raise self._error(q, now)
            q.append(now)

    def ensure_open(self, key: str) -> None:
        """429 when full, without counting (for limits that count only failures)."""
        with self._lock:
            now = time.monotonic()
            q = self.hits.get(key)
            if q is None:
                return
            self._trim(q, now)
            if not q:
                del self.hits[key]
            elif len(q) >= self.limit:
                raise self._error(q, now)

    def add(self, key: str) -> None:
        with self._lock:
            now = time.monotonic()
            q = self._queue(key, now)
            self._trim(q, now)
            q.append(now)

    def reset(self) -> None:
        with self._lock:
            self.hits.clear()
