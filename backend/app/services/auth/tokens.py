"""Access tokens (JWT HS256, 15 minutes) and opaque tokens (256 random bits, stored as sha256) (CONTRACTS 14.2)."""
import hashlib
import secrets
import uuid
from datetime import datetime, timedelta, timezone

import jwt

from app.config import settings
from app.errors import ApiError

ISSUER = "maximus"
ACCESS_TTL_S = 900
REFRESH_TTL = timedelta(days=60)
EMAIL_TTL = {"reset": timedelta(hours=1), "delete": timedelta(hours=1)}
SKEW_S = 60


def new_opaque() -> str:
    return secrets.token_urlsafe(32)  # 256 bits, base64url


def hash_opaque(token: str) -> str:
    return hashlib.sha256(token.encode("utf-8")).hexdigest()


def issue_access(user_id: uuid.UUID, now: datetime) -> str:
    claims = {"sub": str(user_id), "iat": int(now.timestamp()), "exp": int(now.timestamp()) + ACCESS_TTL_S,
              "jti": uuid.uuid4().hex, "iss": ISSUER}
    return jwt.encode(claims, settings.jwt_secret, algorithm="HS256")


def decode_access(token: str, now: datetime) -> dict:
    """Claims of a valid token. 401 token_expired past exp, 401 unauthorized for anything else."""
    try:
        claims = jwt.decode(token, settings.jwt_secret, algorithms=["HS256"], issuer=ISSUER,
                            options={"require": ["sub", "iat", "exp", "jti", "iss"], "verify_exp": False,
                                     "verify_iat": False})
    except jwt.PyJWTError:
        raise ApiError(401, "unauthorized", "Sign in to continue.")
    ts = now.timestamp()
    if not isinstance(claims["exp"], int) or not isinstance(claims["iat"], int) or claims["iat"] > ts + SKEW_S:
        raise ApiError(401, "unauthorized", "Sign in to continue.")
    if claims["exp"] <= ts:
        raise ApiError(401, "token_expired", "The session token has expired.")
    try:
        claims["user_id"] = uuid.UUID(claims["sub"])
    except (ValueError, TypeError, AttributeError):
        raise ApiError(401, "unauthorized", "Sign in to continue.")
    return claims


def utcnow() -> datetime:  # tests patch this
    return datetime.now(timezone.utc)
