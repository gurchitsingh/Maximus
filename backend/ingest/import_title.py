"""Import a title JSON (CONTRACTS import format) into the DB (CONTRACTS 2.10, 9.2).

Children are replaced as a set in one transaction. content_version +1 only when the payload hash changes.
Computed fields in the file (counts, minutes, content_version, updated_at) are ignored, except that a brand-new
title keeps the file's content_version/updated_at when present (so the committed samples are reproducible).
"""
import json
import math
import re
from pathlib import Path

from sqlalchemy import delete
from sqlalchemy.orm import Session

from app.models import FeedFact, Image, IngestRun, Lesson, QuizQuestion, Source, Title
from app.services.etag import short_hash
from app.services.store import now_iso

COMPUTED = {"reading_minutes", "lesson_count", "quiz_count", "content_version", "updated_at"}
SUMMARY_COLS = ["kind", "name", "subtitle", "poster_lines", "era", "region", "period_start", "period_end", "themes",
                "bg", "tint", "lettering", "poster_image_id", "hero_image_id", "brief", "linked_title_ids", "rank",
                "status", "person"]


def reading_minutes(body: str) -> int:
    """max(1, ceil(words / 200)); image lines removed, `* # > -` treated as spaces (CONTRACTS 2.2)."""
    text = "\n".join(l for l in body.split("\n") if not l.startswith("!["))
    return max(1, math.ceil(len(re.sub(r"[*#>\-]", " ", text).split()) / 200))


def payload_hash(data: dict) -> str:
    return short_hash({k: v for k, v in data.items() if k not in COMPUTED})


def import_title(db: Session, data: dict) -> str:
    """Returns 'created', 'updated' or 'unchanged'."""
    tid, h, now = data["id"], payload_hash(data), now_iso()
    t = db.get(Title, tid)
    if t is not None and t.payload_hash == h:
        return "unchanged"
    if t is None:
        state, version, stamp = "created", data.get("content_version") or 1, data.get("updated_at") or now
        t = Title(id=tid)
        db.add(t)
    else:
        state, version, stamp = "updated", t.content_version + 1, now
        for model in (Lesson, Image, QuizQuestion, FeedFact, Source):
            db.execute(delete(model).where(model.title_id == tid))
        db.expire(t)
    t.group_key, t.payload_hash, t.content_version, t.updated_at = data["group"], h, version, stamp
    for col in SUMMARY_COLS:
        setattr(t, col, data.get(col))
    t.rank = data.get("rank") or 0
    db.flush()
    db.add_all(Source(**{**s, "title_id": tid}) for s in data["sources"])
    db.add_all(Image(**{**i, "title_id": tid}) for i in data["images"])
    db.add_all(Lesson(id=l["id"], title_id=tid, idx=l["index"], heading=l["heading"], body=l["body"],
                      reading_minutes=reading_minutes(l["body"]), image_ids=l["image_ids"],
                      read_aloud_text=l.get("read_aloud_text"), source_ids=l["source_ids"]) for l in data["lessons"])
    db.add_all(QuizQuestion(**{**q, "title_id": tid}) for q in data["quiz"])
    db.add_all(FeedFact(**{**f, "title_id": tid}) for f in data["feed_facts"])
    db.add(IngestRun(title_id=tid, kind="import", started_at=now, finished_at=now_iso(), status=state, notes=None))
    db.commit()
    return state


def import_file(db: Session, path: Path) -> str:
    return import_title(db, json.loads(Path(path).read_text("utf-8")))
