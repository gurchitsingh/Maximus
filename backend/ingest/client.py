"""Polite HTTP client for Wikimedia (CONTRACTS 11, CONTENT_SOURCES 3.2).

- Descriptive User-Agent from WIKI_USER_AGENT (public repo URL as contact, no personal email) + library name.
- One request at a time (well under the 3-concurrent limit) and at least `delay` seconds between requests.
- `maxlag=5` on Action API calls; 429 / 503 / maxlag answers are retried after `Retry-After` (capped), then give up.
- Every JSON answer and every downloaded file is cached on disk, so a re-run makes no requests.
Tests pass an `httpx.MockTransport`; pytest never reaches the network (tests/conftest.py blocks it).
"""
import hashlib
import json
import time
from pathlib import Path
from urllib.parse import urlencode

import httpx

from app.config import BACKEND_DIR, settings

CACHE_DIR = BACKEND_DIR / ".cache" / "ingest"
RETRY_STATUSES = {429, 500, 502, 503, 504}


class FetchError(RuntimeError):
    pass


def user_agent() -> str:
    return f"{settings.wiki_user_agent} httpx/{httpx.__version__}"


class WikiClient:
    def __init__(self, *, transport: httpx.BaseTransport | None = None, cache_dir: Path | None = CACHE_DIR,
                 delay: float = 1.0, refresh: bool = False, max_tries: int = 4, max_wait: float = 60.0,
                 sleep=time.sleep, clock=time.monotonic):
        self.http = httpx.Client(transport=transport, timeout=30.0, follow_redirects=True,
                                 headers={"User-Agent": user_agent(), "Accept-Encoding": "gzip"})
        self.cache_dir, self.delay, self.refresh = cache_dir, delay, refresh
        self.max_tries, self.max_wait, self.sleep, self.clock = max_tries, max_wait, sleep, clock
        self._last = None
        self.requests = 0  # network requests made (cache hits excluded)

    def close(self):
        self.http.close()

    def __enter__(self):
        return self

    def __exit__(self, *exc):
        self.close()

    # ---------- internals ----------

    def _cache_path(self, key: str, suffix: str) -> Path | None:
        if self.cache_dir is None:
            return None
        return self.cache_dir / (hashlib.sha256(key.encode()).hexdigest()[:32] + suffix)

    def _pace(self):
        if self._last is not None:
            wait = self.delay - (self.clock() - self._last)
            if wait > 0:
                self.sleep(wait)
        self._last = self.clock()

    def _send(self, url: str, params: dict | None) -> httpx.Response:
        for attempt in range(1, self.max_tries + 1):
            self._pace()
            self.requests += 1
            try:
                r = self.http.get(url, params=params)
            except httpx.HTTPError as e:
                if attempt == self.max_tries:
                    raise FetchError(f"{url}: {e}") from e
                self.sleep(min(self.max_wait, 2 ** attempt))
                continue
            if r.status_code in RETRY_STATUSES or _is_maxlag(r):
                if attempt == self.max_tries:
                    why = "server lag (maxlag)" if _is_maxlag(r) else f"HTTP {r.status_code}"
                    raise FetchError(f"{url}: {why} after {attempt} tries")
                self.sleep(min(self.max_wait, _retry_after(r, 2 ** attempt)))
                continue
            if r.status_code >= 400:
                raise FetchError(f"{url}: HTTP {r.status_code}")
            return r
        raise FetchError(url)  # pragma: no cover

    # ---------- public ----------

    def get_json(self, url: str, params: dict | None = None, *, action_api: bool = False) -> dict:
        params = dict(params or {})
        if action_api:
            params.setdefault("format", "json")
            params.setdefault("formatversion", "2")
            params.setdefault("maxlag", "5")
        key = url + "?" + urlencode(sorted(params.items()))
        path = self._cache_path(key, ".json")
        if path and path.is_file() and not self.refresh:
            return json.loads(path.read_text("utf-8"))
        data = self._send(url, params).json()
        if action_api and isinstance(data, dict) and "error" in data:
            raise FetchError(f"{url}: API error {data['error'].get('code')}: {data['error'].get('info')}")
        if path:
            path.parent.mkdir(parents=True, exist_ok=True)
            path.write_text(json.dumps(data, ensure_ascii=False), "utf-8")
        return data

    def download(self, url: str, dest: Path) -> Path:
        """Fetch a file once; an existing `dest` is reused unless refresh is set."""
        if dest.is_file() and dest.stat().st_size > 0 and not self.refresh:
            return dest
        r = self._send(url, None)
        dest.parent.mkdir(parents=True, exist_ok=True)
        tmp = dest.with_suffix(dest.suffix + ".part")
        tmp.write_bytes(r.content)
        tmp.replace(dest)
        return dest


def _is_maxlag(r: httpx.Response) -> bool:
    if r.status_code != 200 or "json" not in r.headers.get("content-type", ""):
        return False
    try:
        data = r.json()
    except ValueError:
        return False
    return isinstance(data, dict) and (data.get("error") or {}).get("code") == "maxlag"


def _retry_after(r: httpx.Response, default: float) -> float:
    try:
        return max(0.0, float(r.headers.get("retry-after", default)))
    except ValueError:
        return default
