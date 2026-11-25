"""FastAPI dependencies: the signed-in user from `Authorization: Bearer <access_token>` (CONTRACTS 14.1, 14.4).

The user row is loaded on every request, so a deleted account's still-unexpired access token stops working at once.
"""
from dataclasses import dataclass

from fastapi import Depends, Request
from sqlalchemy.orm import Session

from app.db import get_db
from app.errors import ApiError
from app.models import User
from app.services.auth import tokens


@dataclass
class Principal:
    user: User
    claims: dict


def client_ip(request: Request) -> str:
    return request.client.host if request.client else "unknown"


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
    return Principal(user, claims)


def current_user(p: Principal = Depends(current_principal)) -> User:
    return p.user
