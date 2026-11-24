"""Google ID token checks (CONTRACTS 14.3): RS256 signature against Google's published keys (cached for the
Cache-Control max-age), aud == GOOGLE_CLIENT_ID, iss accounts.google.com, exp in the future, email_verified."""
import logging
import re
import threading
import time
from dataclasses import dataclass

import httpx
import jwt

from app.config import settings
from app.errors import ApiError

log = logging.getLogger("maximus.auth")
CERTS_URL = "https://www.googleapis.com/oauth2/v3/certs"
ISSUERS = ("accounts.google.com", "https://accounts.google.com")
_MAX_AGE = re.compile(r"max-age=(\d+)")


@dataclass
class GoogleIdentity:
    sub: str
    email: str
    name: str | None


def invalid(reason: str) -> ApiError:
    log.info("google token rejected reason=%s", reason)
    return ApiError(401, "google_token_invalid", "Google sign-in failed. Try again.")


class GoogleKeys:
    """Google's JWKS, fetched with httpx and kept for max-age seconds (default 1 hour)."""

    def __init__(self, fetch=None):
        self._fetch = fetch or self._http_fetch
        self._keys: dict[str, jwt.PyJWK] = {}
        self._expires = 0.0
        self._lock = threading.Lock()

    @staticmethod
    def _http_fetch() -> tuple[dict, int]:
        r = httpx.get(CERTS_URL, timeout=10)
        r.raise_for_status()
        m = _MAX_AGE.search(r.headers.get("cache-control", ""))
        return r.json(), int(m.group(1)) if m else 3600

    def get(self, kid: str) -> jwt.PyJWK | None:
        with self._lock:
            if time.monotonic() >= self._expires or kid not in self._keys:
                try:
                    jwks, max_age = self._fetch()
                    self._keys = {k["kid"]: jwt.PyJWK(k) for k in jwks.get("keys", []) if "kid" in k}
                    self._expires = time.monotonic() + max(60, min(max_age, 86400))
                except Exception as e:  # network or bad JSON: keep what we had
                    log.warning("google certs fetch failed: %s", type(e).__name__)
            return self._keys.get(kid)


class GoogleVerifier:
    def __init__(self, keys: GoogleKeys | None = None):
        self.keys = keys or GoogleKeys()

    def verify(self, id_token: str) -> GoogleIdentity:
        client_id = settings.google_client_id
        if not client_id:
            raise invalid("not_configured")
        if not isinstance(id_token, str) or not 20 <= len(id_token) <= 8192:
            raise invalid("shape")
        try:
            header = jwt.get_unverified_header(id_token)
        except jwt.PyJWTError:
            raise invalid("header")
        if header.get("alg") != "RS256" or not header.get("kid"):
            raise invalid("alg")
        key = self.keys.get(header["kid"])
        if key is None:
            raise invalid("unknown_kid")
        try:
            claims = jwt.decode(id_token, key.key, algorithms=["RS256"], audience=client_id,
                                options={"require": ["iss", "aud", "exp", "iat", "sub"]}, leeway=60)
        except jwt.ExpiredSignatureError:
            raise invalid("expired")
        except jwt.PyJWTError:
            raise invalid("claims")
        if claims.get("iss") not in ISSUERS:
            raise invalid("iss")
        verified = claims.get("email_verified")
        if verified is not True and verified != "true":
            raise invalid("email_unverified")
        email = claims.get("email")
        if not isinstance(email, str) or "@" not in email:
            raise invalid("email")
        name = claims.get("name")
        return GoogleIdentity(sub=str(claims["sub"]), email=email.strip().lower(),
                              name=name.strip()[:80] if isinstance(name, str) and name.strip() else None)


_default: GoogleVerifier | None = None


def default_verifier() -> GoogleVerifier:
    global _default
    if _default is None:
        _default = GoogleVerifier()
    return _default
