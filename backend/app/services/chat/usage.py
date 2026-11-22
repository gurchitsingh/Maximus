"""Daily chat caps on the chat_usage table (CONTRACTS 4.1 steps 3 and 9, D19, D25: UTC day).

Only salted hashes of install ids are stored, kept 2 days (today and yesterday).
"""
import hashlib
from datetime import date, datetime, time, timedelta, timezone

from sqlalchemy import delete, func, select
from sqlalchemy.orm import Session

from app.config import settings
from app.models import ChatUsage


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


def purge_old(db: Session, now: datetime) -> None:
    """Delete rows older than yesterday, once per UTC day per process (so at the first chat after startup and daily)."""
    global _last_purge
    if _last_purge == now.date():
        return
    db.execute(delete(ChatUsage).where(ChatUsage.day < (now.date() - timedelta(days=1)).isoformat()))
    db.commit()
    _last_purge = now.date()


def used_today(db: Session, ihash: str, now: datetime) -> int:
    row = db.get(ChatUsage, (day_key(now), ihash))
    return row.count if row else 0


def used_today_all(db: Session, now: datetime) -> int:
    return db.scalar(select(func.coalesce(func.sum(ChatUsage.count), 0)).where(ChatUsage.day == day_key(now))) or 0


def add_one(db: Session, ihash: str, now: datetime) -> int:
    """Count one 200 reply; returns this install's count for today after it. One atomic upsert, so two
    concurrent replies for a new install cannot collide on the primary key."""
    dialect = db.get_bind().dialect.name
    if dialect == "postgresql":
        from sqlalchemy.dialects.postgresql import insert
    else:
        from sqlalchemy.dialects.sqlite import insert
    stmt = insert(ChatUsage).values(day=day_key(now), install_hash=ihash, count=1)
    stmt = stmt.on_conflict_do_update(index_elements=["day", "install_hash"], set_={"count": ChatUsage.count + 1})
    db.execute(stmt)
    db.commit()
    return used_today(db, ihash, now)
