"""FastAPI dependencies: the signed-in user from `Authorization: Bearer <access_token>` (CONTRACTS 14.1, 14.4).

The user row is loaded on every request, so a deleted account's still-unexpired access token stops working at once.
"""
import logging
from dataclasses import dataclass

from fastapi import Depends, Request
from sqlalchemy.orm import Session

from app.config import settings
from app.db import get_db
from app.errors import ApiError
from app.models import User
from app.services.auth import tokens

log = logging.getLogger("maximus.auth")

@dataclass
class Principal:
    user: User
    claims: dict


def client_ip(request: Request) -> str:
    """The key of every per-IP limit (SECURITY_AUDIT H1). uvicorn runs with --no-proxy-headers, so
    request.client is the TCP peer. With TRUSTED_PROXY_HOPS=n (Render: 1), the address comes from
    X-Forwarded-For counted n entries from the RIGHT: those entries were appended by our own proxies, while
    anything to their left is whatever the client sent. With 0, or a header shorter than n, the peer is used."""
    peer = request.client.host if request.client else "unknown"
    hops = settings.trusted_proxy_hops
    if hops <= 0:
        return peer
    entries = [e.strip() for e in ",".join(request.headers.getlist("x-forwarded-for")).split(",") if e.strip()]
    _log_header_shape(len(entries))
    if len(entries) < hops:
        return peer
    return entries[-hops][:64]


_shape_logged = False


def _log_header_shape(n: int) -> None:
    """Once per process, the number of X-Forwarded-For entries (never the addresses), so a deploy log shows
    how many hops the platform adds (DEPLOY.md)."""
    global _shape_logged
    if not _shape_logged:
        _shape_logged = True
        log.info("x-forwarded-for entries=%d trusted_proxy_hops=%d", n, settings.trusted_proxy_hops)


def bearer_token(request: Request) -> str:
    header = request.headers.get("authorization", "")
    scheme, _, value = header.partition(" ")
    if scheme.lower() != "bearer" or not value.strip() or len(value) > 4096:
        raise ApiError(401, "unauthorized", "Sign in to continue.")
    return value.strip()


def current_principal(request: Request, db: Session = Depends(get_db)) -> Principal:
    claims = tokens.decode_access(bearer_token(request), tokens.utcnow())
    user = db.get(User, claims["user_id"])
    if user is None:
        raise ApiError(401, "unauthorized", "Sign in to continue.")
    # M2: revoked by a password reset, a Google link or refresh-token reuse. iat is whole seconds, so a token
    # issued in the same second as the revocation (the new session of that same request) stays valid.
    if user.tokens_valid_after is not None and claims["iat"] < int(user.tokens_valid_after.timestamp()):
        raise ApiError(401, "unauthorized", "Sign in to continue.")
    return Principal(user, claims)


def current_user(p: Principal = Depends(current_principal)) -> User:
    return p.user
