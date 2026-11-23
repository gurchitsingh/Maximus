"""Merge Gemini quiz / feed drafts into a title file (S13; CONTRACTS 9.2 step 5, llm/gemini.md).

Reads   data/drafts/<id>.quiz.json  = {"quiz": [...]}        items without id, title_id, status, review_note
        data/drafts/<id>.feed.json  = {"feed_facts": [...]}  (either file may be missing, not both)
Writes  data/titles/<id>.json       new items appended with the next free ids, status `needs_check`.

Guarantees
- Items already in the title file (reviewed or not) are never changed, moved or removed; new items go at the end.
- A draft may not set id, title_id, status or review_note: a model cannot mark its own work `reviewed`.
- Every new item is checked against the title schema (docs/schemas) plus: lesson_id names a lesson of this title,
  options are distinct ignoring case, image_id (feed) is an image of this title.
- All or nothing: one bad item stops the merge and nothing is written, unless `skip_invalid` is set (the good
  items are merged and the bad ones listed). The whole title must still pass G1 (gate.g1_errors) before it is saved.
- Items rejected in review (data/rejected/<id>.json) are not added again and their ids are not reused.
- Idempotent: an item whose prompt / text matches an existing item (ignoring case and punctuation) is skipped, so
  running the same drafts twice adds nothing.
- The file is replaced atomically (temp file, then rename).
"""
import json
import re
from dataclasses import dataclass, field
from pathlib import Path

from ingest import gate
from ingest.titlefile import UsageError, load_rejected, load_title, valid_before, write_json
QUIZ_QUESTION = "title.schema.json#/$defs/quiz_question"
FEED_FACT = "title.schema.json#/$defs/feed_fact"
SERVER_FIELDS = ("id", "title_id", "status", "review_note")  # set by this tool, never by the draft
LIMITS = {"quiz": 80, "feed_facts": 60}  # title.schema.json maxItems
DIFFICULTY_TARGET = {"easy": 40, "medium": 40, "hard": 20}  # gemini.md: 40/40/20
DIFFICULTY_TOLERANCE = 20  # percentage points before a warning
FENCE = re.compile(r"^\s*```[a-zA-Z]*\s*\n(.*?)\n\s*```\s*$", re.S)

KINDS = {
    "quiz": dict(file="quiz", label="quiz", id_letter="q", ref=QUIZ_QUESTION, text="prompt",
                 fields=("lesson_id", "prompt", "options", "correct_index", "explanation", "difficulty"),
                 required=("lesson_id", "prompt", "options", "correct_index", "explanation", "difficulty"),
                 order=("id", "title_id", "lesson_id", "prompt", "options", "correct_index", "explanation",
                        "difficulty", "status", "review_note")),
    "feed_facts": dict(file="feed", label="feed", id_letter="f", ref=FEED_FACT, text="text",
                       fields=("lesson_id", "text", "image_id"), required=("lesson_id", "text"),
                       order=("id", "title_id", "lesson_id", "text", "image_id", "status", "review_note")),
}


MergeUsage = UsageError  # kept for callers and tests that import it from here


@dataclass
class MergeResult:
    title_id: str
    errors: list[str] = field(default_factory=list)    # anything here means nothing was written
    invalid: list[str] = field(default_factory=list)   # bad items skipped under skip_invalid
    skipped: list[str] = field(default_factory=list)   # duplicates
    warnings: list[str] = field(default_factory=list)
    quiz_added: list[dict] = field(default_factory=list)
    feed_added: list[dict] = field(default_factory=list)
    needs_check: dict = field(default_factory=dict)    # whole title after the merge
    dry_run: bool = False
    written: bool = False
    path: Path | None = None

    @property
    def ok(self) -> bool:
        return not self.errors


def _norm(s: str) -> str:
    return re.sub(r"\W+", " ", s.lower()).strip()


def _read_draft(path: Path, key: str, errors: list[str]) -> list | None:
    """The item list of a draft file, None if the file does not exist or is unusable (error recorded)."""
    if not path.is_file():
        return None
    raw = path.read_text("utf-8-sig")
    m = FENCE.match(raw)  # chat tools like to wrap JSON in a ```json fence
    try:
        doc = json.loads(m.group(1) if m else raw)
    except json.JSONDecodeError as e:
        errors.append(f"{path.name}: not valid JSON: {e.msg} (line {e.lineno}, column {e.colno})")
        return None
    if not isinstance(doc, dict) or set(doc) != {key}:
        found = sorted(doc) if isinstance(doc, dict) else type(doc).__name__
        errors.append(f'{path.name}: must be an object with exactly one key "{key}", found {found}')
        return None
    if not isinstance(doc[key], list):
        errors.append(f'{path.name}: "{key}" must be a list')
        return None
    return doc[key]


def _clean(item: dict) -> dict:
    def trim(v):
        if isinstance(v, str):
            return v.strip()
        return [trim(o) for o in v] if isinstance(v, list) else v
    return {k: trim(v) for k, v in item.items()}


def _item_problems(kind: str, raw, tid: str, lessons: set, images: set) -> tuple[dict | None, list[str]]:
    """(clean draft item or None, problems)."""
    spec = KINDS[kind]
    if not isinstance(raw, dict):
        return None, [f"item must be an object, found {type(raw).__name__}"]
    probs = [f"{k}: the draft must not set this, the merge tool does" for k in SERVER_FIELDS if k in raw]
    probs += [f"{k}: unknown field" for k in raw if k not in spec["fields"] and k not in SERVER_FIELDS]
    missing = [f"{k}: missing" for k in spec["required"] if k not in raw]
    if missing:
        return None, probs + missing
    item = _clean({k: v for k, v in raw.items() if k in spec["fields"]})  # keep checking the rest of the item
    if kind == "feed_facts":
        item.setdefault("image_id", None)
    lesson = item["lesson_id"]
    if lesson is None:
        probs.append("lesson_id: required (say which lesson the item comes from)")
    elif isinstance(lesson, str) and lesson not in lessons:
        probs.append(f"lesson_id: {lesson!r} is not a lesson of {tid}")
    full = {"id": f"{tid}.{spec['id_letter']}999", "title_id": tid, "status": "needs_check", "review_note": None, **item}
    probs += gate.schema_errors(full, spec["ref"])
    if kind == "quiz" and isinstance(item["options"], list):
        seen = [o.lower() for o in item["options"] if isinstance(o, str)]
        if len(set(seen)) != len(seen):
            probs.append("options: two options are the same ignoring case")
    if kind == "feed_facts" and item["image_id"] is not None and item["image_id"] not in images:
        probs.append(f"image_id: {item['image_id']!r} is not an image of {tid}")
    return (None if probs else item), probs


def _snippet(item, kind: str) -> str:
    text = item.get(KINDS[kind]["text"]) if isinstance(item, dict) else None
    return f' ("{text[:40]}")' if isinstance(text, str) and text else ""


def _next_number(items: list[dict], letter: str) -> int:
    nums = [int(i["id"].rsplit(f".{letter}", 1)[1]) for i in items]
    return max(nums, default=0) + 1


def merge_title(title_id: str, titles_dir: Path, drafts_dir: Path, *, dry_run: bool = False,
                skip_invalid: bool = False) -> MergeResult:
    """Merge the drafts of one title. Raises MergeUsage when it cannot start; otherwise returns a MergeResult
    (check `.ok`). Nothing is written unless `.ok` and not `dry_run`."""
    path, title = load_title(title_id, titles_dir)
    files = {k: Path(drafts_dir) / f"{title_id}.{s['file']}.json" for k, s in KINDS.items()}
    if not any(p.is_file() for p in files.values()):
        raise MergeUsage(f"no drafts for {title_id}: expected {files['quiz'].name} and/or {files['feed_facts'].name} "
                         f"in {drafts_dir}")

    res = MergeResult(title_id, dry_run=dry_run, path=path)
    before = valid_before(title, path)
    if before:
        res.errors += before
        return res

    lessons = {l["id"] for l in title["lessons"]}
    images = {i["id"] for i in title["images"]}
    rejected = load_rejected(title_id, titles_dir)
    added: dict[str, list[dict]] = {k: [] for k in KINDS}
    problems: list[str] = []
    for kind, spec in KINDS.items():
        items = _read_draft(files[kind], kind, res.errors)
        if items is None:
            continue
        existing = title[kind]
        known = {_norm(x[spec["text"]]): x["id"] for x in existing}
        gone = [r["item"] for r in rejected if r["kind"] == kind]  # rejected in review (ingest/review.py)
        gone_text = {_norm(x[spec["text"]]): x["id"] for x in gone}
        number = _next_number(existing + gone, spec["id_letter"])
        for n, raw in enumerate(items, 1):
            where = f"{spec['label']} #{n}{_snippet(raw, kind)}"
            item, probs = _item_problems(kind, raw, title_id, lessons, images)
            if item is None:
                problems += [f"{where}: {p}" for p in probs]
                continue
            key = _norm(item[spec["text"]])
            if key in gone_text:
                res.skipped.append(f"{where}: skipped, you rejected this in review ({gone_text[key]})")
                continue
            if key in known:
                res.skipped.append(f"{where}: skipped, duplicate of {known[key]}")
                continue
            new_id = f"{title_id}.{spec['id_letter']}{number:03d}"
            if number > 999:
                problems.append(f"{where}: no free id left (limit {spec['id_letter']}999)")
                continue
            known[key] = new_id
            number += 1
            full = {"id": new_id, "title_id": title_id, **item, "status": "needs_check", "review_note": None}
            added[kind].append({k: full[k] for k in spec["order"]})

    for kind in KINDS:
        total = len(title[kind]) + len(added[kind])
        if total > LIMITS[kind]:
            res.errors.append(f"title would have {total} {KINDS[kind]['label']} items; the schema allows "
                              f"{LIMITS[kind]} (drop some from the draft)")
    if problems and skip_invalid:
        res.invalid = problems
    else:
        res.errors += problems
    if res.errors:
        return res

    merged = {**title, **{k: title[k] + added[k] for k in KINDS}}
    after = gate.g1_errors(merged)
    if after:  # a bug here, not a content problem: refuse rather than write a broken title
        res.errors += [f"merged title fails G1, nothing written: {e}" for e in after]
        return res
    for k, own in (("quiz", "quiz_added"), ("feed_facts", "feed_added")):
        setattr(res, own, added[k])
    res.needs_check = {"quiz": sum(q["status"] == "needs_check" for q in merged["quiz"]),
                       "feed_facts": sum(f["status"] == "needs_check" for f in merged["feed_facts"])}
    res.warnings = _warnings(merged, added)
    if not dry_run and (res.quiz_added or res.feed_added):
        write_json(path, merged)
        res.written = True
    return res


def _warnings(merged: dict, added: dict) -> list[str]:
    out = []
    quiz = added["quiz"]
    if len(quiz) >= 10:
        for level, target in DIFFICULTY_TARGET.items():
            share = 100 * sum(q["difficulty"] == level for q in quiz) / len(quiz)
            if abs(share - target) > DIFFICULTY_TOLERANCE:
                out.append(f"quiz difficulty: {share:.0f}% {level} in this draft, target is about {target}%")
    if len(merged["quiz"]) >= 10:
        covered = {q["lesson_id"] for q in merged["quiz"]}
        bare = [l["id"] for l in merged["lessons"] if l["id"] not in covered]
        if bare:
            out.append("lessons with no quiz question: " + ", ".join(bare))
    return out


def format_report(res: MergeResult) -> str:
    """Plain text for the terminal: what was added, skipped, wrong, and what is left to review."""
    lines = [f"== {res.title_id}"]
    if res.errors:
        lines.append(f"   FAILED, {len(res.errors)} problem(s):")
        lines += [f"      - {e}" for e in res.errors]
        lines.append("   Nothing was written. Fix the drafts (or ask Gemini again for those items) and re-run.")
        return "\n".join(lines)
    verb = "would add" if res.dry_run else "added"
    lines.append(f"   {verb} +{len(res.quiz_added)} quiz, +{len(res.feed_added)} feed (all needs_check)"
                 + ("" if not res.dry_run else "  [dry run, nothing written]"))
    for label, items in (("quiz", res.quiz_added), ("feed", res.feed_added)):
        if items:
            lines.append(f"   {label} ids: {items[0]['id']} .. {items[-1]['id']}")
    if res.invalid:
        lines.append(f"   {len(res.invalid)} invalid item(s) skipped, not merged:")
        lines += [f"      - {p}" for p in res.invalid]
    if res.skipped:
        lines.append(f"   {len(res.skipped)} duplicate(s) skipped:")
        lines += [f"      - {s}" for s in res.skipped]
    lines += [f"   WARNING {w}" for w in res.warnings]
    nc = res.needs_check
    lines.append(f"   still needs_check in the title: {nc.get('quiz', 0)} quiz, {nc.get('feed_facts', 0)} feed")
    return "\n".join(lines)
