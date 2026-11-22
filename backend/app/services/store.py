"""Reads the DB and builds the wire payloads (CONTRACTS 2.1, 3.2, 3.4, 2.8). Everything deterministic."""
import json
import random
from datetime import datetime, timezone

from sqlalchemy import select
from sqlalchemy.orm import Session, selectinload

from app.config import BACKEND_DIR, settings
from app.models import Title
from app.services.etag import short_hash

SUMMARY_KEYS = ["id", "kind", "name", "subtitle", "poster_lines", "group", "era", "region", "period_start",
                "period_end", "themes", "bg", "tint", "lettering", "poster_image_id", "hero_image_id", "brief",
                "reading_minutes", "lesson_count", "quiz_count", "linked_title_ids", "rank", "status",
                "content_version", "updated_at"]
GROUP_ORDER = ["ancient-medieval", "india", "revolutions-empires", "wars-space", "money-crashes", "leaders-ancient",
               "leaders-rome", "leaders-medieval", "leaders-europe", "leaders-india", "leaders-africa", "thinkers"]
EPOCH = "1970-01-01T00:00:00Z"


def now_iso() -> str:
    return datetime.now(timezone.utc).strftime("%Y-%m-%dT%H:%M:%SZ")


def _data(name: str) -> dict:
    return json.loads((BACKEND_DIR / "data" / name).read_text("utf-8"))


def editorial() -> dict:
    return _data("editorial.json")


def fonts() -> dict:
    return _data("fonts.json")


def _image(i) -> dict:
    keys = ["id", "title_id", "url", "width", "height", "alt", "kind", "author", "license", "license_version",
            "license_url", "source_page_url", "credit_line", "modified", "focal_x", "focal_y"]
    return {k: getattr(i, k) for k in keys}


def title_detail(t: Title, serve_drafts: bool) -> dict:
    quiz = [q for q in t.quiz_questions if serve_drafts or q.status == "reviewed"]
    facts = [f for f in t.feed_facts if serve_drafts or f.status == "reviewed"]
    d = {k: getattr(t, "group_key" if k == "group" else k, None) for k in SUMMARY_KEYS}
    d.update(
        reading_minutes=sum(l.reading_minutes for l in t.lessons), lesson_count=len(t.lessons), quiz_count=len(quiz),
        lessons=[{"id": l.id, "title_id": l.title_id, "index": l.idx, "heading": l.heading, "body": l.body,
                  "reading_minutes": l.reading_minutes, "image_ids": l.image_ids,
                  "read_aloud_text": l.read_aloud_text, "source_ids": l.source_ids} for l in t.lessons],
        images=[_image(i) for i in t.images],
        quiz=[{k: getattr(q, k) for k in ["id", "title_id", "lesson_id", "prompt", "options", "correct_index",
                                          "explanation", "difficulty", "status", "review_note"]} for q in quiz],
        feed_facts=[{k: getattr(f, k) for k in ["id", "title_id", "lesson_id", "text", "image_id", "status",
                                                "review_note"]} for f in facts],
        person=t.person,
        sources=[{k: getattr(s, k) for k in ["id", "title_id", "title", "url", "publisher", "role", "license",
                                             "confidence"]} for s in t.sources],
    )
    return d


def served_titles(db: Session) -> list[dict]:
    drafts = settings.serve_drafts
    stmt = select(Title).options(selectinload("*")).order_by(Title.rank, Title.id)
    if not drafts:
        stmt = stmt.where(Title.status == "published")
    return [title_detail(t, drafts) for t in db.scalars(stmt)]


def get_title(db: Session, title_id: str) -> dict | None:
    drafts = settings.serve_drafts
    t = db.get(Title, title_id)
    if t is None or (not drafts and t.status != "published"):
        return None
    return title_detail(t, drafts)


def latest_update(titles: list[dict]) -> str:
    return max((t["updated_at"] for t in titles), default=EPOCH)


def build_catalogue(db: Session) -> dict:
    titles = served_titles(db)
    ed, by_id = editorial(), {t["id"]: t for t in titles}
    refs = {t[k] for t in titles for k in ("poster_image_id", "hero_image_id") if t[k]}
    imgs = {i["id"]: i for t in titles for i in t["images"]}
    onboarding = [i for i in ed["onboarding_leader_ids"] if by_id.get(i, {}).get("kind") == "leader"][:12]
    cat = {
        "generated_at": latest_update(titles),  # moves only when an import changes something
        "featured_id": ed["featured_id"] if ed["featured_id"] in by_id else None,
        "people_row_label": ed["people_row_label"],
        "onboarding_leader_ids": onboarding,
        "groups": [{"key": k, "label": ed["group_labels"][k], "people": k.startswith(("leaders-", "thinkers")),
                    "order": n} for n, k in enumerate(GROUP_ORDER)],
        "titles": [{k: t[k] for k in SUMMARY_KEYS} for t in titles],
        "images": [imgs[r] for r in sorted(refs)],
    }
    cat["catalogue_version"] = short_hash({k: v for k, v in cat.items() if k != "generated_at"})
    return cat


def build_feed(db: Session, title_ids: list[str], limit: int, seed: int) -> dict:
    by_id = {t["id"]: t for t in served_titles(db)}
    rng, queues = random.Random(seed), []
    for tid in dict.fromkeys(title_ids):
        if tid in by_id:
            q = sorted(by_id[tid]["feed_facts"], key=lambda f: f["id"])
            rng.shuffle(q)
            queues.append(q)
    facts = []
    while len(facts) < limit and any(queues):
        for q in queues:
            if q and len(facts) < limit:
                facts.append(q.pop(0))
    imgs = {i["id"]: i for t in by_id.values() for i in t["images"]}
    ids = sorted({f["image_id"] for f in facts if f["image_id"]})
    return {"generated_at": now_iso(), "seed": seed, "facts": facts, "images": [imgs[i] for i in ids]}


def build_credits(db: Session) -> dict:
    titles = served_titles(db)
    text, images = [], []
    for t in titles:
        for s in sorted(t["sources"], key=lambda s: s["id"]):
            if s["role"] == "text":
                text.append({"title_id": t["id"], "title_name": t["name"], "name": s["title"], "url": s["url"],
                             "license": s["license"]})
        for i in sorted(t["images"], key=lambda i: i["id"]):
            images.append({"image_id": i["id"], "title_id": t["id"], "title_name": t["name"],
                           "credit_line": i["credit_line"], "license": i["license"], "license_url": i["license_url"],
                           "source_page_url": i["source_page_url"], "modified": i["modified"]})
    return {"generated_at": latest_update(titles), "notices": editorial()["notices"],
            "text_sources": text, "images": images}
