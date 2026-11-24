"""Daily maintenance (CONTRACTS 15.4, 16). Run once a day from a scheduler (Render cron job, GitHub Actions or
similar) with the production DATABASE_URL:

    python -m app.jobs purge            # prints what it removed
    python -m app.jobs purge --dry-run  # counts only

Removes: chat history older than CHAT_RETENTION_DAYS (30), sync tombstones older than SYNC_TOMBSTONE_DAYS (90),
chat counters older than yesterday, and refresh or email tokens that expired more than a day ago.
The chat route also purges history lazily on the first chat of each UTC day, so a missed run loses nothing.
"""
import argparse
import sys
from datetime import datetime, timedelta, timezone

from sqlalchemy import delete, func, select
from sqlalchemy.orm import Session

from app.config import settings
from app.db import SessionLocal
from app.models import EmailToken, RefreshToken, UserChatMessage, UserRecord
from app.services import sync
from app.services.chat import history, usage


def purge(db: Session, now: datetime) -> dict:
    stale = now - timedelta(days=1)
    counts = {
        "chat_messages": history.purge_expired(db, now),
        "refresh_tokens": db.execute(delete(RefreshToken).where(RefreshToken.expires_at < stale)).rowcount,
        "email_tokens": db.execute(delete(EmailToken).where(EmailToken.expires_at < stale)).rowcount,
    }
    db.commit()
    counts["tombstones"] = sync.purge_tombstones(db, now)
    usage.purge_old(db, now, force=True)
    return counts


def dry_run(db: Session, now: datetime) -> dict:
    def n(model, *where):
        return db.scalar(select(func.count()).select_from(model).where(*where)) or 0
    stale = now - timedelta(days=1)
    return {
        "chat_messages": n(UserChatMessage, UserChatMessage.created_at < now - timedelta(days=settings.chat_retention_days)),
        "refresh_tokens": n(RefreshToken, RefreshToken.expires_at < stale),
        "email_tokens": n(EmailToken, EmailToken.expires_at < stale),
        "tombstones": n(UserRecord, UserRecord.deleted.is_(True),
                        UserRecord.updated_at < now - timedelta(days=settings.sync_tombstone_days)),
    }


def main(argv: list[str] | None = None) -> int:
    ap = argparse.ArgumentParser(prog="python -m app.jobs")
    sub = ap.add_subparsers(dest="cmd", required=True)
    p = sub.add_parser("purge", help="retention purge (chat history, tombstones, expired tokens, counters)")
    p.add_argument("--dry-run", action="store_true")
    args = ap.parse_args(argv)
    now = datetime.now(timezone.utc)
    with SessionLocal() as db:
        counts = dry_run(db, now) if args.dry_run else purge(db, now)
    label = "would remove" if args.dry_run else "removed"
    print(f"{label}: " + ", ".join(f"{k}={v}" for k, v in counts.items()))
    return 0


if __name__ == "__main__":
    sys.exit(main())
