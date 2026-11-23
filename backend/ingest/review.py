"""Review and publish tooling for a title file (S13; CONTRACTS 9.1, 9.3).

report   what still needs the owner's review per title: items `needs_check`, the publish gate result, next step
review   show the needs_check items next to their lesson; approve (-> `reviewed`) or reject items by id;
         mark the whole title `reviewed` (draft -> reviewed, CONTRACTS 9.1)
publish  reviewed -> published, refused unless the whole publish gate (G1 to G9) passes

Rejecting removes the item from the title file and records it in data/rejected/<id>.json (so its id is not reused
and merge does not add the same draft again). Only `needs_check` items can be rejected: a `reviewed` item is
served, edit it by hand. Every write is atomic and the title must still pass G1.
"""
import re
from dataclasses import dataclass, field
from pathlib import Path

from ingest import gate
from ingest.titlefile import (UsageError, load_rejected, load_title, rejected_path, valid_before, write_json)

KINDS = {"quiz": ("q", "prompt"), "feed_facts": ("f", "text")}
KIND_ALIASES = {"quiz": "quiz", "feed": "feed_facts", "feed_facts": "feed_facts"}
ID_TOKEN = re.compile(r"^(?:([a-z0-9-]+)\.)?([qf])(\d{3})(?:-(?:[a-z0-9-]+\.)?\2(\d{3}))?$")


def _snip(text: str, n: int = 60) -> str:
    text = " ".join(text.split())
    return text if len(text) <= n else text[:n - 1] + "…"


def _lesson_label(title: dict, lesson_id) -> str:
    for l in title["lessons"]:
        if l["id"] == lesson_id:
            return f"lesson {l['index']} {l['heading']!r}"
    return "no lesson"


# ---- report -----------------------------------------------------------------------------------------------------

@dataclass
class TitleReport:
    title_id: str
    kind: str
    status: str
    gate: gate.Report
    quiz_total: int
    feed_total: int
    pending: dict = field(default_factory=dict)   # kind -> list of needs_check items
    next_step: str = ""

    @property
    def pending_count(self) -> int:
        return sum(len(v) for v in self.pending.values())


def build_report(title: dict) -> TitleReport:
    g = gate.check(title)
    pending = {k: [] for k in KINDS}
    if not g.rules() & {"G1"}:
        pending = {k: [x for x in title[k] if x["status"] == "needs_check"] for k in KINDS}
    rep = TitleReport(title.get("id", "?"), title.get("kind", "?"), title.get("status", "?"), g,
                      len(title.get("quiz", [])), len(title.get("feed_facts", [])), pending)
    tid = rep.title_id
    if "G1" in g.rules():
        rep.next_step = "fix the title file (G1), then re-run report"
    elif rep.pending_count:
        rep.next_step = f"python -m ingest.cli review {tid}   (check the items against the lessons, then --approve / --reject)"
    elif rep.status == "draft":
        rep.next_step = f"python -m ingest.cli review {tid} --title-reviewed   (after you have read the whole title)"
    elif rep.status == "reviewed":
        rep.next_step = (f"python -m ingest.cli publish {tid}" if g.ok
                         else "fix the gate failures above, then publish")
    else:
        rep.next_step = "published; nothing to do" if g.ok else "published but FAILING the gate: fix and re-import"
    return rep


def format_report(rep: TitleReport, items: bool = True) -> str:
    n_q, n_f = len(rep.pending["quiz"]), len(rep.pending["feed_facts"])
    lines = [f"== {rep.title_id}  ({rep.kind}, status {rep.status})",
             f"   quiz: {rep.quiz_total - n_q} reviewed, {n_q} to review   "
             f"feed: {rep.feed_total - n_f} reviewed, {n_f} to review",
             "   publish gate: " + ("PASS" if rep.gate.ok else f"FAIL ({len(rep.gate.errors)} problem(s))")]
    lines += [f"      {r} {m}" for r, m in rep.gate.errors]
    if rep.quiz_total - n_q < 6 and rep.kind == "topic":
        lines.append("   note: fewer than 6 reviewed quiz questions, the Quiz tab stays hidden (CONTRACTS 7.1)")
    if items:
        for kind in KINDS:
            for x in rep.pending[kind]:
                lines.append(f"   to review  {x['id']}  {_snip(x[KINDS[kind][1]])}")
    lines.append(f"   next: {rep.next_step}")
    return "\n".join(lines)


# ---- review sheet -----------------------------------------------------------------------------------------------

def review_sheet(title: dict, kind: str | None = None, lesson: str | None = None, lesson_text: bool = False) -> str:
    """Full text of every needs_check item (optionally one kind / lesson) with the lesson it claims to come from."""
    tid = title["id"]
    want = {KIND_ALIASES[kind]} if kind else set(KINDS)
    lesson_id = None
    if lesson:
        lesson_id = lesson if "." in lesson else f"{tid}.{lesson}"
    out, last = [], None
    for k in KINDS:
        if k not in want:
            continue
        for x in title[k]:
            if x["status"] != "needs_check" or (lesson_id and x["lesson_id"] != lesson_id):
                continue
            if lesson_text and x["lesson_id"] != last:
                last = x["lesson_id"]
                body = next((l["body"] for l in title["lessons"] if l["id"] == last), "")
                out += ["", f"######## {last}  {_lesson_label(title, last)}", body, "########"]
            out.append(f"\n-- {x['id']}   {_lesson_label(title, x['lesson_id'])}")
            if k == "quiz":
                out.append(f"   [{x['difficulty']}] {x['prompt']}")
                out += [f"   {'ABCD'[i]}) {o}{'   <- marked correct' if i == x['correct_index'] else ''}"
                        for i, o in enumerate(x["options"])]
                out.append(f"   why: {x['explanation']}")
            else:
                out.append(f"   {x['text']}")
                if x["image_id"]:
                    out.append(f"   image: {x['image_id']}")
    return "\n".join(out) if out else "(nothing to review with these filters)"


# ---- approve / reject -------------------------------------------------------------------------------------------

@dataclass
class ReviewResult:
    title_id: str
    approved: list[str] = field(default_factory=list)
    rejected: list[str] = field(default_factory=list)
    already: list[str] = field(default_factory=list)
    errors: list[str] = field(default_factory=list)
    left: int = 0
    dry_run: bool = False
    written: bool = False

    @property
    def ok(self) -> bool:
        return not self.errors


def expand_ids(token: str, title_id: str) -> list[str]:
    """`q003`, `roman-history.q003`, or a range `q003-q009` -> full ids. Raises ValueError for anything else."""
    m = ID_TOKEN.match(token.strip())
    if not m:
        raise ValueError(f"{token!r} is not an item id (use q012, f003, a full id, or a range like q001-q010)")
    prefix, letter, a, b = m.group(1), m.group(2), int(m.group(3)), m.group(4)
    last = int(b) if b else a
    if last < a or last - a > 200:
        raise ValueError(f"{token!r} is not a sensible range")
    if prefix and prefix != title_id:
        raise ValueError(f"{token!r} belongs to another title")
    return [f"{title_id}.{letter}{n:03d}" for n in range(a, last + 1)]


def review_items(title_id: str, titles_dir: Path, *, approve=(), reject=(), approve_all: bool = False,
                 kind: str | None = None, note: str | None = None, dry_run: bool = False) -> ReviewResult:
    path, title = load_title(title_id, titles_dir)
    res = ReviewResult(title_id, dry_run=dry_run)
    res.errors += valid_before(title, path)
    if res.errors:
        return res
    if kind and kind not in KIND_ALIASES:
        raise UsageError(f"--kind must be quiz or feed, not {kind!r}")
    items = {x["id"]: (k, x) for k in KINDS for x in title[k]}

    def resolve(tokens) -> list[str]:
        ids = []
        for t in tokens:
            try:
                ids += expand_ids(t, title_id)
            except ValueError as e:
                res.errors.append(str(e))
        return ids

    app, rej = resolve(approve), resolve(reject)
    if approve_all:
        only = KIND_ALIASES[kind] if kind else None
        app += [i for i, (k, x) in items.items() if x["status"] == "needs_check" and (not only or k == only)
                and i not in rej]
    app = list(dict.fromkeys(app))
    rej = list(dict.fromkeys(rej))
    for i in sorted(set(app) & set(rej)):
        res.errors.append(f"{i}: asked to approve and reject in the same call")
    for i in app + rej:
        if i not in items:
            res.errors.append(f"{i}: no such item in {title_id}")
    for i in rej:
        if i in items and items[i][1]["status"] != "needs_check":
            res.errors.append(f"{i}: already reviewed (served), cannot be rejected here; edit the file by hand")
    if note is not None and len(note) > 300:
        res.errors.append("note: longer than 300 characters")
    if not app and not rej and not res.errors:
        res.errors.append("nothing to do: give --approve, --reject or --approve-all")
    if res.errors:
        return res

    for i in app:
        item = items[i][1]
        if item["status"] == "reviewed":
            res.already.append(i)
            if note is None:
                continue
        item["status"] = "reviewed"
        if note is not None:
            item["review_note"] = note
        if i not in res.already:
            res.approved.append(i)
    log = load_rejected(title_id, titles_dir)
    for i in rej:
        k, item = items[i]
        title[k] = [x for x in title[k] if x["id"] != i]
        log = [r for r in log if r["item"]["id"] != i] + [{"kind": k, "item": item, "note": note}]
        res.rejected.append(i)
    after = gate.g1_errors(title)
    if after:
        res.errors += [f"title would fail G1, nothing written: {e}" for e in after]
        return res
    res.left = sum(x["status"] == "needs_check" for k in KINDS for x in title[k])
    if not dry_run and (res.approved or res.rejected or note is not None and app):
        if res.rejected:
            write_json(rejected_path(title_id, titles_dir), log)  # log first: a crash never loses an item
        write_json(path, title)
        res.written = True
    return res


def format_review(res: ReviewResult) -> str:
    if res.errors:
        return "\n".join([f"== {res.title_id}  FAILED, nothing was written:"] + [f"   - {e}" for e in res.errors])
    tag = "  [dry run, nothing written]" if res.dry_run else ""
    lines = [f"== {res.title_id}{tag}",
             f"   approved {len(res.approved)}, rejected {len(res.rejected)}"
             + (f", already reviewed {len(res.already)}" if res.already else "")
             + f"; {res.left} item(s) still needs_check"]
    if res.rejected:
        lines.append("   rejected (logged in data/rejected/): " + ", ".join(res.rejected))
    return "\n".join(lines)


# ---- title status -----------------------------------------------------------------------------------------------

@dataclass
class StatusResult:
    title_id: str
    ok: bool
    message: str
    problems: list[str] = field(default_factory=list)
    changed: bool = False


def mark_title_reviewed(title_id: str, titles_dir: Path) -> StatusResult:
    """draft -> reviewed. The owner says they read the whole title; the file must at least be valid (G1)."""
    path, title = load_title(title_id, titles_dir)
    if title["status"] != "draft":
        return StatusResult(title_id, title["status"] in ("reviewed", "published"),
                            f"already {title['status']}, nothing changed")
    bad = gate.g1_errors(title)
    if bad:
        return StatusResult(title_id, False, "refused: the title file is not valid (G1)", [f"G1 {e}" for e in bad])
    write_json(path, {**title, "status": "reviewed"})
    return StatusResult(title_id, True, "status draft -> reviewed", changed=True)


def publish_title(title_id: str, titles_dir: Path, dry_run: bool = False) -> StatusResult:
    """reviewed -> published, only if the whole gate G1 to G9 passes (CONTRACTS 9.3). Never writes otherwise."""
    path, title = load_title(title_id, titles_dir)
    if title["status"] == "published":
        rep = gate.check(title)
        return StatusResult(title_id, rep.ok, "already published" + ("" if rep.ok else ", but it FAILS the gate"),
                            [f"{r} {m}" for r, m in rep.errors])
    if title["status"] != "reviewed":
        return StatusResult(title_id, False, f"refused: status is {title['status']}; the owner marks a title "
                            f"reviewed first (python -m ingest.cli review {title_id} --title-reviewed)")
    rep = gate.check(title)
    if not rep.ok:
        return StatusResult(title_id, False, f"refused: {len(rep.errors)} publish gate problem(s)",
                            [f"{r} {m}" for r, m in rep.errors])
    if not dry_run:
        write_json(path, {**title, "status": "published"})
    nc = rep.needs_check
    left = nc.get("quiz", 0) + nc.get("feed_facts", 0)
    return StatusResult(title_id, True, ("would publish" if dry_run else "published")
                        + (f"; {left} item(s) still needs_check and will not be served" if left else ""),
                        changed=not dry_run)
