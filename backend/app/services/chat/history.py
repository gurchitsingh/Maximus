"""Stored chat history (CONTRACTS 16, D39): both turns of every 200 reply, kept CHAT_RETENTION_DAYS (5, rolling per message).

Chat text is personal data: never logged, deleted with the account, listed in the privacy policy.
"""
import uuid
from datetime import datetime, timedelta

from sqlalchemy import and_, delete, or_, select
from sqlalchemy.orm import Session

from app.config import settings
from app.errors import ApiError
from app.models import UserChatMessage

CONTEXT_TURNS = 6


def recent(db: Session, user_id: uuid.UUID, title_id: str, n: int = CONTEXT_TURNS) -> list[dict]:
    """The last n stored turns for this title, oldest first, as {role, text} (the provider context)."""
    rows = list(db.scalars(select(UserChatMessage)
                           .where(UserChatMessage.user_id == user_id, UserChatMessage.title_id == title_id)
                           .order_by(UserChatMessage.created_at.desc(), UserChatMessage.id.desc()).limit(n)))
    return [{"role": r.role, "text": r.text} for r in reversed(rows)]


def save_exchange(db: Session, user_id: uuid.UUID, title_id: str, message: str, kind: str, text: str,
                  lesson_refs: list, now: datetime) -> uuid.UUID:
    """Both turns in the caller's transaction. The assistant turn is 1 ms later so the order is stable."""
    db.add(UserChatMessage(user_id=user_id, title_id=title_id, role="user", text=message, kind=None,
                           lesson_refs=[], created_at=now))
    reply = UserChatMessage(user_id=user_id, title_id=title_id, role="assistant", text=text, kind=kind,
                            lesson_refs=lesson_refs, created_at=now + timedelta(milliseconds=1))
    db.add(reply)
    db.flush()
    return reply.id


def _z(dt: datetime) -> str:
    return dt.strftime("%Y-%m-%dT%H:%M:%S.") + f"{dt.microsecond // 1000:03d}Z"


def page(db: Session, user_id: uuid.UUID, title_id: str, limit: int, before: str | None) -> dict:
    """Newest page first; oldest first within the page. `before` is a message id from an earlier page."""
    q = select(UserChatMessage).where(UserChatMessage.user_id == user_id, UserChatMessage.title_id == title_id)
    if before is not None:
        try:
            before_id = uuid.UUID(before)
        except ValueError:
            raise ApiError(422, "validation_error", "before must be a message id.",
                           details={"fields": [{"loc": "query.before", "msg": "not a message id"}]})
        anchor = db.get(UserChatMessage, before_id)
        if anchor is None or anchor.user_id != user_id or anchor.title_id != title_id:
            raise ApiError(422, "validation_error", "before is not a message of this chat.",
                           details={"fields": [{"loc": "query.before", "msg": "unknown message"}]})
        q = q.where(or_(UserChatMessage.created_at < anchor.created_at,
                        and_(UserChatMessage.created_at == anchor.created_at, UserChatMessage.id < anchor.id)))
    rows = list(db.scalars(q.order_by(UserChatMessage.created_at.desc(), UserChatMessage.id.desc()).limit(limit + 1)))
    has_more = len(rows) > limit
    rows = rows[:limit]
    return {"messages": [{"id": str(r.id), "role": r.role, "text": r.text, "kind": r.kind,
                          "lesson_refs": r.lesson_refs or [], "created_at": _z(r.created_at)}
                         for r in reversed(rows)],
            "has_more": has_more}


def delete_title(db: Session, user_id: uuid.UUID, title_id: str) -> None:
    db.execute(delete(UserChatMessage).where(UserChatMessage.user_id == user_id, UserChatMessage.title_id == title_id))
    db.commit()


def delete_all(db: Session, user_id: uuid.UUID) -> None:
    db.execute(delete(UserChatMessage).where(UserChatMessage.user_id == user_id))
    db.commit()


def purge_expired(db: Session, now: datetime) -> int:
    """Hard-delete messages older than CHAT_RETENTION_DAYS. The caller commits."""
    cutoff = now - timedelta(days=settings.chat_retention_days)
    return db.execute(delete(UserChatMessage).where(UserChatMessage.created_at < cutoff)).rowcount
