"""Daily chat caps (CONTRACTS 4.1 steps 3 and 9, 16, D19, D25: UTC day).

- per account: chat_usage keyed by (day, user_id); CHAT_ACCOUNT_DAILY_CAP
- per install (only when the app sends install_id): chat_install_usage keyed by the salted install hash;
  CHAT_DAILY_CAP. An extra abuse signal: a new account on the same phone does not get a fresh allowance.
- global: SUM(chat_usage.count) for the day; CHAT_GLOBAL_DAILY_CAP. Every chat is signed in, so each counts once.
Rows are kept for today and yesterday only.
"""
import hashlib
import uuid
from datetime import date, datetime, time, timedelta, timezone

from sqlalchemy import delete, func, select
from sqlalchemy.orm import Session

from app.config import settings
from app.models import ChatInstallUsage, ChatUsage


def utcnow() -> datetime:  # tests patch this
    return datetime.now(timezone.utc)


def day_key(now: datetime) -> str:
    return now.date().isoformat()


def seconds_to_midnight(now: datetime) -> int:
    midnight = datetime.combine(now.date() + timedelta(days=1), time(0), tzinfo=timezone.utc)
    return max(1, int((midnight - now).total_seconds() + 0.999))


def install_hash(install_id: str) -> str:
    return hashlib.sha256((settings.install_id_salt + install_id).encode("utf-8")).hexdigest()


_last_purge: date | None = None


def purge_old(db: Session, now: datetime, force: bool = False) -> bool:
    """Delete counter rows older than yesterday, once per UTC day per process (and from the purge job).
    Returns True when it ran, so the caller can run its other daily purges on the same tick."""
    global _last_purge
    if _last_purge == now.date() and not force:
        return False
    cutoff = (now.date() - timedelta(days=1)).isoformat()
    db.execute(delete(ChatUsage).where(ChatUsage.day < cutoff))
    db.execute(delete(ChatInstallUsage).where(ChatInstallUsage.day < cutoff))
    db.commit()
    _last_purge = now.date()
    return True


def used_by_account(db: Session, user_id: uuid.UUID, now: datetime) -> int:
    row = db.get(ChatUsage, (day_key(now), user_id))
    return row.count if row else 0


def used_by_install(db: Session, ihash: str, now: datetime) -> int:
    row = db.get(ChatInstallUsage, (day_key(now), ihash))
    return row.count if row else 0


def used_today_all(db: Session, now: datetime) -> int:
    return db.scalar(select(func.coalesce(func.sum(ChatUsage.count), 0)).where(ChatUsage.day == day_key(now))) or 0


def _insert(db: Session):
    if db.get_bind().dialect.name == "postgresql":
        from sqlalchemy.dialects.postgresql import insert
    else:
        from sqlalchemy.dialects.sqlite import insert
    return insert


def add_one(db: Session, user_id: uuid.UUID, ihash: str | None, now: datetime) -> None:
    """Count one 200 reply with atomic upserts (two concurrent first chats cannot collide on the key).
    The caller commits."""
    insert = _insert(db)
    stmt = insert(ChatUsage).values(day=day_key(now), user_id=user_id, count=1)
    db.execute(stmt.on_conflict_do_update(index_elements=["day", "user_id"], set_={"count": ChatUsage.count + 1}))
    if ihash is not None:
        stmt = insert(ChatInstallUsage).values(day=day_key(now), install_hash=ihash, count=1)
        db.execute(stmt.on_conflict_do_update(index_elements=["day", "install_hash"],
                                              set_={"count": ChatInstallUsage.count + 1}))
