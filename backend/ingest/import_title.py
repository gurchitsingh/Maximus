"""Import a title JSON (CONTRACTS import format) into the DB (CONTRACTS 2.10, 9.2).

Children are replaced as a set in one transaction. content_version +1 only when the payload hash changes.
Every file is checked against title-import.schema.json and the referential rules (gate G1) first; a file that
says `status: published` must pass the whole publish gate (CONTRACTS 9.3). Either failure raises ImportRefused
and nothing is written.
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
from ingest import gate

COMPUTED = {"reading_minutes", "lesson_count", "quiz_count", "content_version", "updated_at"}
DEFAULTS = {"subtitle": None, "period_start": None, "period_end": None, "poster_image_id": None,
            "hero_image_id": None, "linked_title_ids": [], "rank": 999}  # CONTRACTS 9.2 import format
SUMMARY_COLS = ["kind", "name", "subtitle", "poster_lines", "era", "region", "period_start", "period_end", "themes",
                "bg", "tint", "lettering", "poster_image_id", "hero_image_id", "brief", "linked_title_ids", "rank",
                "status", "person"]


class ImportRefused(ValueError):
    def __init__(self, title_id: str, problems: list[str]):
        super().__init__(f"{title_id}: import refused ({len(problems)} problem(s))")
        self.title_id, self.problems = title_id, problems


def validate(data: dict) -> None:
    """G1 always; the whole gate for a published title. Raises ImportRefused."""
    if data.get("status") == "published":
        rep = gate.check(data)
        if not rep.ok:
            raise ImportRefused(data.get("id", "?"), [f"{r} {m}" for r, m in rep.errors])
    else:
        errs = gate.g1_errors(data)
        if errs:
            raise ImportRefused(data.get("id", "?"), [f"G1 {e}" for e in errs])


def reading_minutes(body: str) -> int:
    """max(1, ceil(words / 200)); image lines removed, `* # > -` treated as spaces (CONTRACTS 2.2)."""
    text = "\n".join(l for l in body.split("\n") if not l.startswith("!["))
    return max(1, math.ceil(len(re.sub(r"[*#>\-]", " ", text).split()) / 200))


def payload_hash(data: dict) -> str:
    return short_hash({k: v for k, v in data.items() if k not in COMPUTED})


def import_title(db: Session, data: dict) -> str:
    """Returns 'created', 'updated' or 'unchanged'. Raises ImportRefused (nothing written)."""
    validate(data)
    data = {**DEFAULTS, **data}
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
