"""Offline-first sync (CONTRACTS 15, D38): one generic user_records table, last write wins by the device's
updated_at, a delete beats an edit at the same instant, and a per-user seq assigned here is the pull cursor.

Concurrency: a push locks the user's row (SELECT ... FOR UPDATE on Postgres) while it hands out seq numbers, so
seq values commit in order and a pull never skips a record. SQLite (dev and tests only) serialises writers itself.
"""
import json
import re
import uuid
from datetime import datetime, timedelta, timezone
from typing import Annotated, Literal

from pydantic import BaseModel, ConfigDict, Field, StrictBool, StrictInt, ValidationError
from sqlalchemy import delete, func, select, update
from sqlalchemy.orm import Session

from app.config import settings
from app.errors import ApiError
from app.models import User, UserRecord

MAX_RECORDS = 500
MAX_BODY_BYTES = 512 * 1024
MAX_DATA_BYTES = 8 * 1024
MAX_FUTURE = timedelta(minutes=5)
SYNCED_SETTINGS = frozenset({"onboarding_done", "theme", "text_size", "voice_speed", "voice_name"})

SLUG = r"^[a-z0-9]+(?:-[a-z0-9]+)*$"
LESSON = r"^[a-z0-9]+(?:-[a-z0-9]+)*\.l[0-9]{2,3}$"
FACT = r"^[a-z0-9]+(?:-[a-z0-9]+)*\.f[0-9]{2,4}$"
QUESTION = r"^[a-z0-9]+(?:-[a-z0-9]+)*\.q[0-9]{2,4}$"
UUID4 = r"^[0-9a-f]{8}-[0-9a-f]{4}-4[0-9a-f]{3}-[89ab][0-9a-f]{3}-[0-9a-f]{12}$"
_Z = re.compile(r"^\d{4}-\d{2}-\d{2}T\d{2}:\d{2}:\d{2}(\.\d{1,6})?Z$")

Slug = Annotated[str, Field(pattern=SLUG, max_length=100)]
Stamp = Annotated[str, Field(pattern=_Z.pattern)]


class _Data(BaseModel):
    model_config = ConfigDict(extra="forbid", strict=True)


class SettingData(_Data):
    value: str = Field(max_length=200)


class InterestData(_Data):
    kind: Literal["topic_pick", "leader_pick"]
    title_id: Slug
    position: StrictInt = Field(ge=0, le=100)
    picked_at: Stamp


class StudyItemData(_Data):
    title_id: Slug
    added_at: Stamp


class RatingData(_Data):
    title_id: Slug
    value: Literal[-1, 0, 1]
    rated_at: Stamp


class ProgressData(_Data):
    lesson_id: str = Field(pattern=LESSON)
    title_id: Slug
    lesson_index: StrictInt = Field(ge=0, le=1000)
    last_opened_at: Stamp
    completed_at: Stamp | None


class QuizResultData(_Data):
    id: str = Field(pattern=UUID4)
    title_id: Slug
    score: StrictInt = Field(ge=0, le=100)
    total: StrictInt = Field(ge=1, le=100)
    question_ids: list[Annotated[str, Field(pattern=QUESTION)]] = Field(max_length=100)
    wrong_ids: list[Annotated[str, Field(pattern=QUESTION)]] = Field(max_length=100)
    content_version: StrictInt = Field(ge=1)
    taken_at: Stamp


class FeedItemData(_Data):
    fact_id: str = Field(pattern=FACT)
    title_id: Slug
    saved: StrictBool
    reaction: Literal[-1, 0, 1]
    seen_at: Stamp | None


# kind -> (data model, the record id the data implies)
KINDS = {
    "setting": (SettingData, None),
    "interest": (InterestData, lambda d: f"{d.kind}:{d.title_id}"),
    "study_item": (StudyItemData, lambda d: d.title_id),
    "rating": (RatingData, lambda d: d.title_id),
    "progress": (ProgressData, lambda d: d.lesson_id),
    "quiz_result": (QuizResultData, lambda d: d.id),
    "feed_item": (FeedItemData, lambda d: d.fact_id),
}
ID_RULES = {
    "setting": lambda i: i in SYNCED_SETTINGS,
    "interest": lambda i: re.fullmatch(r"(topic_pick|leader_pick):" + SLUG[1:-1], i) is not None,
    "study_item": lambda i: re.fullmatch(SLUG, i) is not None,
    "rating": lambda i: re.fullmatch(SLUG, i) is not None,
    "progress": lambda i: re.fullmatch(LESSON, i) is not None,
    "quiz_result": lambda i: re.fullmatch(UUID4, i) is not None,
    "feed_item": lambda i: re.fullmatch(FACT, i) is not None,
}


class Rejected(Exception):
    def __init__(self, reason: str):
        self.reason = reason


def parse_time(value) -> datetime:
    if not isinstance(value, str) or not _Z.match(value):
        raise Rejected("invalid_data")
    try:
        dt = datetime.fromisoformat(value[:-1]).replace(tzinfo=timezone.utc)
    except ValueError:
        raise Rejected("invalid_data")
    return dt.replace(microsecond=dt.microsecond // 1000 * 1000)  # milliseconds, as echoed back


def z(dt: datetime) -> str:
    base = dt.astimezone(timezone.utc).strftime("%Y-%m-%dT%H:%M:%S")
    return f"{base}.{dt.microsecond // 1000:03d}Z" if dt.microsecond else base + "Z"


def record_json(r: UserRecord) -> dict:
    return {"kind": r.kind, "id": r.record_id, "data": None if r.deleted else r.data, "updated_at": z(r.updated_at),
            "deleted": bool(r.deleted), "seq": r.seq}


def validate(raw) -> tuple[str, str, dict | None, datetime, bool]:
    if not isinstance(raw, dict):
        raise Rejected("invalid_data")
    kind, rid = raw.get("kind"), raw.get("id")
    if kind not in KINDS:
        raise Rejected("invalid_kind")
    if not isinstance(rid, str) or not 1 <= len(rid) <= 200 or not ID_RULES[kind](rid):
        raise Rejected("invalid_data")
    deleted = raw.get("deleted", False)
    if not isinstance(deleted, bool):
        raise Rejected("invalid_data")
    updated_at = parse_time(raw.get("updated_at"))
    if deleted:
        return kind, rid, None, updated_at, True
    data = raw.get("data")
    if not isinstance(data, dict):
        raise Rejected("invalid_data")
    if len(json.dumps(data, separators=(",", ":"))) > MAX_DATA_BYTES:
        raise Rejected("too_large")
    model, implied_id = KINDS[kind]
    try:
        parsed = model.model_validate(data)
    except ValidationError:
        raise Rejected("invalid_data")
    if implied_id is not None and implied_id(parsed) != rid:
        raise Rejected("invalid_data")
    return kind, rid, parsed.model_dump(), updated_at, False


def wins(kind: str, stored: UserRecord | None, updated_at: datetime, deleted: bool) -> bool:
    if stored is None:
        return True
    if kind == "quiz_result":  # append-only: never edited, only tombstoned, never revived
        return deleted and not stored.deleted
    if updated_at > stored.updated_at:
        return True
    return updated_at == stored.updated_at and deleted and not stored.deleted


def _lock_user(db: Session, user_id: uuid.UUID) -> User:
    # populate_existing: the auth dependency loaded this row earlier in the session; re-read it under the lock.
    stmt = select(User).where(User.id == user_id).with_for_update().execution_options(populate_existing=True)
    return db.execute(stmt).scalar_one()


def push(db: Session, user_id: uuid.UUID, records: list, now: datetime) -> dict:
    user = _lock_user(db, user_id)
    live = db.scalar(select(func.count()).select_from(UserRecord)
                     .where(UserRecord.user_id == user_id, UserRecord.deleted.is_(False))) or 0
    applied, superseded, rejected = [], [], []
    latest = now + MAX_FUTURE
    for raw in records:
        try:
            kind, rid, data, updated_at, deleted = validate(raw)
        except Rejected as e:
            k = raw.get("kind") if isinstance(raw, dict) and isinstance(raw.get("kind"), str) else None
            i = raw.get("id") if isinstance(raw, dict) and isinstance(raw.get("id"), str) else None
            rejected.append({"kind": k, "id": i[:200] if i else i, "reason": e.reason})
            continue
        updated_at = min(updated_at, latest)
        stored = db.get(UserRecord, (user_id, kind, rid))
        if not wins(kind, stored, updated_at, deleted):
            superseded.append(record_json(stored))
            continue
        was_live = stored is not None and not stored.deleted
        if not deleted and not was_live and live >= settings.sync_record_quota:
            rejected.append({"kind": kind, "id": rid, "reason": "quota"})
            continue
        live += int(not deleted) - int(was_live)
        user.sync_seq += 1
        if stored is None:
            stored = UserRecord(user_id=user_id, kind=kind, record_id=rid)
            db.add(stored)
        stored.data, stored.updated_at, stored.deleted, stored.seq = data, updated_at, deleted, user.sync_seq
        applied.append({"kind": kind, "id": rid, "seq": user.sync_seq})
    db.commit()
    return {"applied": applied, "superseded": superseded, "rejected": rejected, "cursor": user.sync_seq}


def pull(db: Session, user_id: uuid.UUID, since: int, limit: int) -> dict:
    user = db.get(User, user_id)
    if 0 < since < user.purged_seq:
        return {"records": [], "cursor": 0, "has_more": False, "reset": True}
    rows = list(db.scalars(select(UserRecord).where(UserRecord.user_id == user_id, UserRecord.seq > since)
                           .order_by(UserRecord.seq).limit(limit + 1)))
    has_more = len(rows) > limit
    rows = rows[:limit]
    return {"records": [record_json(r) for r in rows], "cursor": rows[-1].seq if rows else since,
            "has_more": has_more, "reset": False}


def purge_tombstones(db: Session, now: datetime) -> int:
    """Drop tombstones older than SYNC_TOMBSTONE_DAYS; remember the highest purged seq per user (15.4)."""
    horizon = now - timedelta(days=settings.sync_tombstone_days)
    old = (UserRecord.deleted.is_(True), UserRecord.updated_at < horizon)
    per_user = db.execute(select(UserRecord.user_id, func.max(UserRecord.seq)).where(*old)
                          .group_by(UserRecord.user_id)).all()
    for user_id, max_seq in per_user:
        db.execute(update(User).where(User.id == user_id, User.purged_seq < max_seq).values(purged_seq=max_seq))
    n = db.execute(delete(UserRecord).where(*old)).rowcount
    db.commit()
    return n


def parse_push_body(raw: bytes) -> list:
    if len(raw) > MAX_BODY_BYTES:
        raise ApiError(400, "bad_request", "Request body is over 512 KB.", details={"reason": "body_too_large"})
    try:
        doc = json.loads(raw.decode("utf-8"))
    except (UnicodeDecodeError, ValueError):
        raise ApiError(400, "bad_request", "Request body is not valid JSON.", details={"reason": "invalid_json"})
    records = doc.get("records") if isinstance(doc, dict) else None
    if not isinstance(records, list) or not 1 <= len(records) <= MAX_RECORDS:
        raise ApiError(400, "bad_request", f"records must be a list of 1 to {MAX_RECORDS}.",
                       details={"reason": "records"})
    return records
