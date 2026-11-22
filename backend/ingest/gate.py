"""Publish gate (CONTRACTS 9.3). `check(title)` returns a Report; `report.ok` is False when any rule G1 to G9
fails. G10 (items still `needs_check`) never blocks: production filters those items, the report counts them.

The importer runs G1 on every file and the whole gate when the file says `status: published`
(`python -m ingest.cli check <id>` runs it on demand).
"""
import json
import re
from dataclasses import dataclass, field
from functools import lru_cache
from urllib.parse import unquote

from jsonschema import Draft202012Validator, FormatChecker
from referencing import Registry, Resource

from app.config import BACKEND_DIR
from ingest.split import words

SCHEMAS = BACKEND_DIR.parent / "docs" / "schemas"
BASE = "https://maximus.example/schemas/"
ALLOWED_LICENCES = {"PD", "CC0", "CC BY", "CC BY-SA", "OWN"}
LEGEND_IDS = {"romulus", "sun-tzu", "chanakya"}
BAD_LINE = re.compile(r"^(#(?!# )|###|<|\||```)|\]\(http|<[a-zA-Z/]")
FILE_NAME = re.compile(r"(\.(jpe?g|png|svg|gif|tiff?|webp)\b|^File:|_)", re.I)
LESSON_WORDS = (80, 700)


@dataclass
class Report:
    title_id: str
    errors: list[tuple[str, str]] = field(default_factory=list)   # (rule, message)
    needs_check: dict = field(default_factory=dict)                # G10 counts

    @property
    def ok(self) -> bool:
        return not self.errors

    def add(self, rule: str, msg: str):
        self.errors.append((rule, msg))

    def rules(self) -> set[str]:
        return {r for r, _ in self.errors}

    def lines(self) -> list[str]:
        out = [f"{r} {m}" for r, m in self.errors]
        q, f = self.needs_check.get("quiz", 0), self.needs_check.get("feed_facts", 0)
        out.append(f"G10 note: {q} quiz question(s) and {f} feed fact(s) still needs_check (not served)")
        return out


@lru_cache(maxsize=1)
def _registry() -> Registry:
    reg = Registry()
    for f in SCHEMAS.glob("*.schema.json"):
        reg = reg.with_resource(BASE + f.name, Resource.from_contents(json.loads(f.read_text("utf-8"))))
    return reg


def schema_errors(doc, ref: str = "title-import.schema.json") -> list[str]:
    schema = {"$schema": "https://json-schema.org/draft/2020-12/schema", "$ref": BASE + ref}
    v = Draft202012Validator(schema, registry=_registry(), format_checker=FormatChecker())
    return [f"{'/'.join(map(str, e.path)) or '(root)'}: {e.message}" for e in v.iter_errors(doc)]


def reading_minutes(body: str) -> int:
    return max(1, -(-words(body) // 200))


def referential_errors(t: dict) -> list[str]:
    """The validate_samples title_checks rules without the SAMPLE markers; computed fields only if present."""
    errs, tid = [], t["id"]
    ids = [x["id"] for k in ("lessons", "images", "quiz", "feed_facts", "sources") for x in t[k]]
    if len(ids) != len(set(ids)):
        errs.append("duplicate child ids")
    errs += [f"child id {x} not prefixed with {tid}." for x in ids if not x.startswith(tid + ".")]
    img = {i["id"] for i in t["images"]}
    src = {s["id"] for s in t["sources"]}
    les = {l["id"] for l in t["lessons"]}
    for k in ("lessons", "images", "quiz", "feed_facts"):
        errs += [f"{x['id']}: title_id mismatch" for x in t[k] if x["title_id"] != tid]
    if [l["index"] for l in t["lessons"]] != list(range(1, len(t["lessons"]) + 1)):
        errs.append("lesson index not 1..n")
    for ref in (t.get("poster_image_id"), t.get("hero_image_id")):
        if ref and ref not in img:
            errs.append(f"missing image {ref}")
    for l in t["lessons"]:
        errs += [f"{l['id']}: missing image {i}" for i in l["image_ids"] if i not in img]
        for tok in re.findall(r"^!\[\]\((.+)\)$", l["body"], re.M):
            if tok not in l["image_ids"][1:]:
                errs.append(f"{l['id']}: inline image {tok} not in image_ids[1:]")
        errs += [f"{l['id']}: missing source {s}" for s in l["source_ids"] if s not in src]
        for n, line in enumerate(l["body"].splitlines(), 1):
            if BAD_LINE.search(line):
                errs.append(f"{l['id']} line {n}: outside markdown subset: {line[:40]}")
        if l["reading_minutes"] != reading_minutes(l["body"]):
            errs.append(f"{l['id']}: reading_minutes {l['reading_minutes']} != {reading_minutes(l['body'])}")
    for x in t["quiz"] + t["feed_facts"]:
        if x["lesson_id"] and x["lesson_id"] not in les:
            errs.append(f"{x['id']}: missing lesson {x['lesson_id']}")
    errs += [f"{f['id']}: missing image {f['image_id']}" for f in t["feed_facts"]
             if f["image_id"] and f["image_id"] not in img]
    if "lesson_count" in t and t["lesson_count"] != len(t["lessons"]):
        errs.append("lesson_count wrong")
    if "reading_minutes" in t and t["reading_minutes"] != sum(l["reading_minutes"] for l in t["lessons"]):
        errs.append("title reading_minutes wrong")
    p = t.get("person")
    if p:
        for c in p["traits"] + p["changes"] + p["odds_beaten"] + p["core_ideas"] + p["use_today"]:
            errs += [f"person claim: missing source {s}" for s in c["source_ids"] if s not in src]
    return errs


def g1_errors(t: dict) -> list[str]:
    errs = schema_errors(t)
    if errs:
        return errs  # referential checks assume the shape is right
    return referential_errors(t)


def _strings(x):
    if isinstance(x, str):
        yield x
    elif isinstance(x, dict):
        for v in x.values():
            yield from _strings(v)
    elif isinstance(x, list):
        for v in x:
            yield from _strings(v)


def check(t: dict) -> Report:
    rep = Report(t.get("id", "?"))
    for e in g1_errors(t):
        rep.add("G1", e)
    if not rep.ok:
        return rep  # later rules read fields G1 guarantees

    # G2 lessons
    if not t["lessons"]:
        rep.add("G2", "no lessons")
    for l in t["lessons"]:
        n = words(l["body"])
        if not l["body"].strip():
            rep.add("G2", f"{l['id']}: empty body")
        elif not LESSON_WORDS[0] <= n <= LESSON_WORDS[1]:
            rep.add("G2", f"{l['id']}: {n} words (needs {LESSON_WORDS[0]} to {LESSON_WORDS[1]})")
        if not l["source_ids"]:
            rep.add("G2", f"{l['id']}: no source")

    # G3 images
    for i in t["images"]:
        lic = i["license"]
        if lic not in ALLOWED_LICENCES:
            rep.add("G3", f"{i['id']}: licence {lic} not allowed")
        if not (i["credit_line"] or "").strip():
            rep.add("G3", f"{i['id']}: no credit line")
        if not (i["author"] or "").strip():
            rep.add("G3", f"{i['id']}: no author")
        if lic in ("CC BY", "CC BY-SA") and not (i["license_version"] and i["license_url"] and i["source_page_url"]):
            rep.add("G3", f"{i['id']}: {lic} needs licence version, licence URL and source page")
        if lic != "OWN" and not i["source_page_url"]:
            rep.add("G3", f"{i['id']}: no source page")
        alt = (i["alt"] or "").strip()
        stem = unquote((i["source_page_url"] or "").rsplit("/", 1)[-1])
        stem = re.sub(r"[\s_]+", " ", re.sub(r"^File:|\.[A-Za-z0-9]{2,5}$", "", stem)).strip().lower()
        if len(alt.split()) < 2 or FILE_NAME.search(alt) or (stem and alt.lower().rstrip(".") == stem):
            rep.add("G3", f"{i['id']}: alt text looks like a file name: {alt[:40]!r}")

    # G4 text sources
    text_sources = [s for s in t["sources"] if s["role"] == "text"]
    if t["kind"] == "topic" and not text_sources:
        rep.add("G4", "topic has no role:text source")
    for s in text_sources:
        if not (s["license"] or "").strip():
            rep.add("G4", f"{s['id']}: text source without licence")

    # G5 served quiz questions
    for q in t["quiz"]:
        if q["status"] != "reviewed":
            continue
        opts = [o.strip().lower() for o in q["options"]]
        if len(opts) != 4 or len(set(opts)) != 4:
            rep.add("G5", f"{q['id']}: needs 4 distinct options")
        if not (q["explanation"] or "").strip():
            rep.add("G5", f"{q['id']}: no explanation")

    # G6 feed facts
    for f in t["feed_facts"]:
        if len(f["text"]) > 280 or len(f["text"].split()) > 40:
            rep.add("G6", f"{f['id']}: longer than 40 words / 280 characters")

    # G7 people claims
    p = t["person"]
    if p:
        cites = {s["id"]: s for s in t["sources"] if s["role"] == "citation"}
        groups = [("trait", p["traits"]), ("change", p["changes"]), ("odds", p["odds_beaten"]),
                  ("idea", p["core_ideas"]), ("use_today", p["use_today"])]
        for label, claims in groups:
            for n, c in enumerate(claims, 1):
                used = {s for s in c["source_ids"] if s in cites}
                if len(used) < 2:
                    rep.add("G7", f"{label} {n}: cites {len(used)} citation source(s), needs 2")
                elif all(cites[s]["confidence"] == "low" for s in used):
                    rep.add("G7", f"{label} {n}: only low-confidence sources")

    # G8 legends
    if t["id"] in LEGEND_IDS and not (p and p.get("legend_note")):
        rep.add("G8", "legendary or debated life needs a legend_note")

    # G9 sample marker
    if any("SAMPLE" in s for s in _strings(t)):
        rep.add("G9", "contains the SAMPLE marker")

    # G10 (report only)
    rep.needs_check = {"quiz": sum(q["status"] == "needs_check" for q in t["quiz"]),
                       "feed_facts": sum(f["status"] == "needs_check" for f in t["feed_facts"])}
    return rep
