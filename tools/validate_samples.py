"""Throwaway S3 check: validate the sample titles and example payloads against docs/schemas.

Checks (CONTRACTS.md section 10):
  1. backend/data/samples/*.json     title + title-import schemas, referential rules
     backend/data/titles/*.json      title-import schema, referential rules, no SAMPLE marker (S11)
  2. docs/examples/*.json            their API schema, and that the derived payloads (catalogue,
                                     feed, credits, chat) match what the contract rules build from the samples
  3. docs/examples/match-cases.json  the match % reference (CONTRACTS.md section 6)

Run from the repo root:  tools\\.venv\\Scripts\\python tools\\validate_samples.py
Needs: pip install -r tools/requirements.txt
"""
import functools
import hashlib
import json
import math
import random
import re
import sys
from pathlib import Path

from jsonschema import Draft202012Validator, FormatChecker
from referencing import Registry, Resource

ROOT = Path(__file__).resolve().parent.parent
SCHEMAS = ROOT / "docs" / "schemas"
SAMPLES = ROOT / "backend" / "data" / "samples"
TITLES = ROOT / "backend" / "data" / "titles"
EXAMPLES = ROOT / "docs" / "examples"
BASE = "https://maximus.example/schemas/"
TITLE_SAMPLES = ["roman-history.json", "shivaji-maharaj.json", "chanakya.json"]
LEGEND_IDS = {"romulus", "sun-tzu", "chanakya"}
BAD_LINE = re.compile(r"^(#(?!# )|###|<|\||```)|\]\(http|<[a-zA-Z/]")

# file in docs/examples -> schema ref. A JSON array file is checked item by item.
EXAMPLE_FILES = {
    "catalogue.json": "catalogue.schema.json",
    "feed.json": "feed.schema.json",
    "on-this-day.json": "on-this-day.schema.json",
    "credits.json": "credits.schema.json",
    "fonts.json": "credits.schema.json#/$defs/font_list",
    "chat-request.json": "chat-request.schema.json",
    "chat-response.json": "chat-response.schema.json",
    "chat-response-out-of-scope.json": "chat-response.schema.json",
    "errors.json": "error.schema.json",
    "health.json": "health.schema.json",
}
# The request that docs/examples/feed.json answers (CONTRACTS.md 3.4).
FEED_REQUEST = {"title_ids": ["roman-history", "shivaji-maharaj", "chanakya"], "limit": 6, "seed": 42}
# The title that the chat examples were asked in.
CHAT_TITLE = "roman-history"


def registry():
    reg = Registry()
    for f in SCHEMAS.glob("*.schema.json"):
        reg = reg.with_resource(BASE + f.name, Resource.from_contents(json.loads(f.read_text("utf-8"))))
    return reg


def schema_errors(doc, ref, reg):
    schema = {"$schema": "https://json-schema.org/draft/2020-12/schema", "$ref": BASE + ref}
    v = Draft202012Validator(schema, registry=reg, format_checker=FormatChecker())
    return [f"{ref}: {'/'.join(map(str, e.path))}: {e.message}" for e in v.iter_errors(doc)]


def load(path):
    return json.loads(path.read_text("utf-8"))


# ---------- reference rules (CONTRACTS.md 2.8, 3.1 to 3.4) ----------

SUMMARY_KEYS = list(load(SCHEMAS / "title.schema.json")["$defs"]["summary_properties"]["properties"])


def short_hash(obj):
    """First 16 hex chars of sha256 over canonical JSON (sorted keys, no spaces, UTF-8)."""
    canon = json.dumps(obj, sort_keys=True, separators=(",", ":"), ensure_ascii=False)
    return hashlib.sha256(canon.encode("utf-8")).hexdigest()[:16]


def by_rank(titles):
    return sorted(titles, key=lambda t: (t["rank"], t["id"]))


def image_index(titles):
    return {i["id"]: i for t in titles for i in t["images"]}


def catalogue_version(cat):
    return short_hash({k: v for k, v in cat.items() if k not in ("catalogue_version", "generated_at")})


def catalogue_titles(titles):
    return [{k: t[k] for k in SUMMARY_KEYS} for t in by_rank(titles)]


def catalogue_images(titles):
    refs = {t[k] for t in titles for k in ("poster_image_id", "hero_image_id") if t[k]}
    imgs = image_index(titles)
    return [imgs[r] for r in sorted(refs)]


def feed_pick(titles, title_ids, limit, seed):
    """Round-robin over the requested titles; each title's facts shuffled by one seeded RNG."""
    rng, by_id, queues = random.Random(seed), {t["id"]: t for t in titles}, []
    for tid in dict.fromkeys(title_ids):
        if tid in by_id:
            q = sorted(by_id[tid]["feed_facts"], key=lambda f: f["id"])
            rng.shuffle(q)
            queues.append(q)
    out = []
    while len(out) < limit and any(queues):
        for q in queues:
            if q and len(out) < limit:
                out.append(q.pop(0))
    return out


def fact_images(facts, titles):
    imgs = image_index(titles)
    return [imgs[i] for i in sorted({f["image_id"] for f in facts if f["image_id"]})]


def credit_lists(titles):
    text, imgs = [], []
    for t in by_rank(titles):
        for s in sorted(t["sources"], key=lambda s: s["id"]):
            if s["role"] == "text":
                text.append({"title_id": t["id"], "title_name": t["name"], "name": s["title"],
                             "url": s["url"], "license": s["license"]})
        for i in sorted(t["images"], key=lambda i: i["id"]):
            imgs.append({"image_id": i["id"], "title_id": t["id"], "title_name": t["name"],
                         "credit_line": i["credit_line"], "license": i["license"], "license_url": i["license_url"],
                         "source_page_url": i["source_page_url"], "modified": i["modified"]})
    return text, imgs


# ---------- match % reference (CONTRACTS.md section 6) ----------

WEIGHTS = {"topic_pick": 3.0, "leader_pick": 3.0, "leader_link": 2.0, "rating_up": 4.0, "rating_okay": 0.0,
           "rating_down": -4.0, "study_list": 2.0, "lessons_read": 2.0, "feed_step": 0.5, "feed_cap": 4}
REASON_ORDER = ["rating_up", "topic_pick", "leader_pick", "leader_link", "study_list", "lessons_read", "feed_up"]
REASON_TEXT = {"rating_up": "because you liked {}", "topic_pick": "because you picked {}",
               "leader_pick": "because you chose {}", "leader_link": "because you chose {}",
               "study_list": "because you added {}", "lessons_read": "because you read {}",
               "feed_up": "because you liked facts about {}"}
REASON_FALLBACK = "because of what you picked"


def match_tags(t):
    return {"g:" + t["group"], "e:" + t["era"], "r:" + t["region"]} | {"t:" + x for x in t["themes"]}


def match_signals(sig, by_id):
    """-> list of (title_id, weight, kind, subject_id). The reason line names the subject."""
    out = []
    for i in sig.get("topic_picks", []):
        out.append((i, WEIGHTS["topic_pick"], "topic_pick", i))
    for i in sig.get("leader_picks", []):
        out.append((i, WEIGHTS["leader_pick"], "leader_pick", i))
        for x in by_id.get(i, {}).get("linked_title_ids", []):
            out.append((x, WEIGHTS["leader_link"], "leader_link", i))
    for i, v in sig.get("ratings", {}).items():
        kind = {1: "rating_up", 0: "rating_okay", -1: "rating_down"}[v]
        out.append((i, WEIGHTS[kind], kind, i))
    for i in sig.get("study_list", []):
        out.append((i, WEIGHTS["study_list"], "study_list", i))
    for i, n in sig.get("lessons_completed", {}).items():
        lc = by_id.get(i, {}).get("lesson_count", 0)
        out.append((i, WEIGHTS["lessons_read"] * (min(1.0, n / lc) if lc else 0.0), "lessons_read", i))
    for i, f in sig.get("feed", {}).items():
        up = WEIGHTS["feed_step"] * min(WEIGHTS["feed_cap"], f.get("liked_or_saved", 0))
        down = WEIGHTS["feed_step"] * min(WEIGHTS["feed_cap"], f.get("disliked", 0))
        out += [(i, up, "feed_up", i), (i, -down, "feed_down", i)]
    return [s for s in out if s[0] in by_id and s[3] in by_id and s[1] != 0]


def match_scores(titles, sig):
    """-> (badges_shown, ordered list of {id, raw, pct, reason})."""
    by_id = {t["id"]: t for t in titles}
    signals = match_signals(sig, by_id)
    w = {}
    for tid, wt, _, _ in signals:
        w[tid] = w.get(tid, 0.0) + wt
    w = {k: v for k, v in w.items() if v != 0}
    if not w:
        return False, [{"id": t["id"], "raw": None, "pct": None, "reason": None} for t in by_rank(titles)]
    tags = {t["id"]: match_tags(t) for t in titles}

    def jac(a, b):
        return len(tags[a] & tags[b]) / len(tags[a] | tags[b])

    rows = []
    for t in titles:
        tid = t["id"]
        raw = sum(ws * jac(tid, s) for s, ws in w.items())
        pct = min(99, max(40, math.floor(50 + 49 * raw / (4 + abs(raw)) + 0.5)))
        reason = None
        if raw > 0:
            cands = sorted((-(ws * jac(tid, s)), by_id[s]["rank"], s) for s, ws in w.items()
                           if s != tid and ws > 0 and jac(tid, s) > 0)
            for _, _, s in cands:
                pos = sorted((-wt, REASON_ORDER.index(k), k, subj) for x, wt, k, subj in signals
                             if x == s and wt > 0 and k in REASON_TEXT and subj != tid)
                if pos:
                    reason = REASON_TEXT[pos[0][2]].format(by_id[pos[0][3]]["name"])
                    break
            reason = reason or REASON_FALLBACK
        rows.append({"id": tid, "raw": raw, "pct": pct, "reason": reason, "rank": t["rank"]})

    def cmp(a, b):
        if a["pct"] != b["pct"]:
            return b["pct"] - a["pct"]
        if abs(a["raw"] - b["raw"]) > 1e-9:
            return -1 if a["raw"] > b["raw"] else 1
        return -1 if (a["rank"], a["id"]) < (b["rank"], b["id"]) else 1

    rows.sort(key=functools.cmp_to_key(cmp))
    return True, [{"id": r["id"], "raw": round(r["raw"], 4), "pct": r["pct"], "reason": r["reason"]} for r in rows]


# ---------- 1. sample titles ----------

def words(body):
    lines = [l for l in body.splitlines() if not l.startswith("![](")]
    return len(re.sub(r"[*#>\-]", " ", "\n".join(lines)).split())


def title_checks(t, sample=True):
    """Referential rules. sample=True: a SAMPLE title (markers required, computed fields present).
    sample=False: a real title file in backend/data/titles (markers forbidden, computed fields optional)."""
    errs, tid = [], t["id"]
    ids = [x["id"] for k in ("lessons", "images", "quiz", "feed_facts", "sources") for x in t[k]]
    if len(ids) != len(set(ids)):
        errs.append("duplicate child ids")
    for x in ids:
        if not x.startswith(tid + "."):
            errs.append(f"child id {x} not prefixed with {tid}.")
    img = {i["id"] for i in t["images"]}
    src = {s["id"] for s in t["sources"]}
    les = {l["id"] for l in t["lessons"]}
    for k in ("lessons", "images", "quiz", "feed_facts"):
        for x in t[k]:
            if x["title_id"] != tid:
                errs.append(f"{x['id']}: title_id mismatch")
    if [l["index"] for l in t["lessons"]] != list(range(1, len(t["lessons"]) + 1)):
        errs.append("lesson index not 1..n")
    for ref in (t["poster_image_id"], t["hero_image_id"]):
        if ref and ref not in img:
            errs.append(f"missing image {ref}")
    for l in t["lessons"]:
        for i in l["image_ids"]:
            if i not in img:
                errs.append(f"{l['id']}: missing image {i}")
        for tok in re.findall(r"^!\[\]\((.+)\)$", l["body"], re.M):
            if tok not in l["image_ids"][1:]:
                errs.append(f"{l['id']}: inline image {tok} not in image_ids[1:]")
        for s in l["source_ids"]:
            if s not in src:
                errs.append(f"{l['id']}: missing source {s}")
        for n, line in enumerate(l["body"].splitlines(), 1):
            if BAD_LINE.search(line):
                errs.append(f"{l['id']} line {n}: outside markdown subset: {line[:40]}")
        want = max(1, math.ceil(words(l["body"]) / 200))
        if l["reading_minutes"] != want:
            errs.append(f"{l['id']}: reading_minutes {l['reading_minutes']} != {want} ({words(l['body'])} words)")
        if sample and "SAMPLE" not in l["body"]:
            errs.append(f"{l['id']}: not marked SAMPLE")
    for x in t["quiz"] + t["feed_facts"]:
        if x["lesson_id"] and x["lesson_id"] not in les:
            errs.append(f"{x['id']}: missing lesson {x['lesson_id']}")
    for f in t["feed_facts"]:
        if f["image_id"] and f["image_id"] not in img:
            errs.append(f"{f['id']}: missing image {f['image_id']}")
    # computed fields: always in samples, optional in import files (CONTRACTS 9.2)
    if "lesson_count" in t and t["lesson_count"] != len(t["lessons"]):
        errs.append("lesson_count wrong")
    if "quiz_count" in t and t["quiz_count"] != len(t["quiz"]):
        errs.append("quiz_count wrong")
    if "reading_minutes" in t and t["reading_minutes"] != sum(l["reading_minutes"] for l in t["lessons"]):
        errs.append(f"title reading_minutes != {sum(l['reading_minutes'] for l in t['lessons'])}")
    p = t["person"]
    if p:
        claims = p["traits"] + p["changes"] + p["odds_beaten"] + p["core_ideas"] + p["use_today"]
        for c in claims:
            for s in c["source_ids"]:
                if s not in src:
                    errs.append(f"person claim: missing source {s}")
        if tid in LEGEND_IDS and not p["legend_note"]:
            errs.append("legend title without legend_note")
    if not sample:  # real titles can never carry the marker (publish gate G9)
        return errs + (["contains the SAMPLE marker"] if "SAMPLE" in json.dumps(t, ensure_ascii=False) else [])
    marked = [t["brief"]] + [q["prompt"] for q in t["quiz"]] + [f["text"] for f in t["feed_facts"]]
    if p:
        marked.append(p["headline"])
    errs += [f"not marked SAMPLE: {m[:40]}" for m in marked if "SAMPLE" not in m]
    return errs


# ---------- 2. example payloads ----------

def example_checks(ex, titles):
    """Cross-checks that a schema alone cannot express. ex = {file name: parsed JSON}."""
    errs, by_id = [], {t["id"]: t for t in titles}

    cat = ex["catalogue.json"]
    if cat["titles"] != catalogue_titles(titles):
        errs.append("catalogue: titles are not the summaries of the samples in (rank, id) order")
    if cat["images"] != catalogue_images(titles):
        errs.append("catalogue: images are not exactly the poster/hero images, sorted by id")
    if cat["catalogue_version"] != catalogue_version(cat):
        errs.append(f"catalogue: catalogue_version should be {catalogue_version(cat)}")
    if [g["key"] for g in cat["groups"]] != load(SCHEMAS / "common.schema.json")["$defs"]["group"]["enum"]:
        errs.append("catalogue: groups must list every group key once, in the common.schema enum order")
    if [g["order"] for g in cat["groups"]] != list(range(len(cat["groups"]))):
        errs.append("catalogue: group order must be 0..n-1")
    if any(g["people"] != g["key"].startswith(("leaders-", "thinkers")) for g in cat["groups"]):
        errs.append("catalogue: people flag must be true exactly for leaders-* and thinkers")
    if cat["featured_id"] is not None and cat["featured_id"] not in by_id:
        errs.append("catalogue: featured_id is not a served title")
    if any(by_id.get(i, {}).get("kind") != "leader" for i in cat["onboarding_leader_ids"]):
        errs.append("catalogue: onboarding_leader_ids must be served leader titles")

    feed = ex["feed.json"]
    want = feed_pick(titles, **FEED_REQUEST)
    if feed["seed"] != FEED_REQUEST["seed"] or feed["facts"] != want:
        errs.append(f"feed: facts must equal feed_pick({FEED_REQUEST}) = {[f['id'] for f in want]}")
    if feed["images"] != fact_images(feed["facts"], titles):
        errs.append("feed: images must be exactly the images the facts reference, sorted by id")

    cred = ex["credits.json"]
    text, imgs = credit_lists(titles)
    if cred["text_sources"] != text:
        errs.append("credits: text_sources must be every role=text source, titles in (rank, id) order")
    if cred["images"] != imgs:
        errs.append("credits: images must be every image of every served title, titles in (rank, id) order")

    # On This Day: linked_title_id = the served title whose role=text source is that page (CONTRACTS 2.7)
    text_pages = {s["url"]: t["id"] for t in titles for s in t["sources"] if s["role"] == "text"}
    for it in ex["on-this-day.json"]["items"]:
        if it["linked_title_id"] != text_pages.get(it["page_url"]):
            errs.append(f"on-this-day: {it['page_title']} linked_title_id should be {text_pages.get(it['page_url'])}")

    # Chat (CONTRACTS 4): answers cite 1..3 real lessons, plain text without links; fixed refusal wording
    lessons = {l["id"]: l["index"] for l in by_id[CHAT_TITLE]["lessons"]}
    for name in ("chat-response.json", "chat-response-out-of-scope.json"):
        r = ex[name]
        for ref in r["lesson_refs"]:
            if lessons.get(ref["lesson_id"]) != ref["index"]:
                errs.append(f"{name}: lesson_ref {ref} does not match {CHAT_TITLE}")
        if r["kind"] == "answer" and not 1 <= len(r["lesson_refs"]) <= 3:
            errs.append(f"{name}: an answer cites 1 to 3 lessons")
        if re.search(r"https?:|www\.", r["text"]):
            errs.append(f"{name}: reply text must not contain links")
    if ex["chat-response.json"]["kind"] != "answer":
        errs.append("chat-response.json must be an answer")
    oos = ex["chat-response-out-of-scope.json"]
    if oos["kind"] != "out_of_scope" or oos["text"] != f"I only know about {by_id[CHAT_TITLE]['name']}.":
        errs.append("chat out-of-scope example must use the fixed wording 'I only know about <name>.'")

    # Errors (CONTRACTS 3.5): one per code, retry_after_s and details as the table says
    codes = [e["error"]["code"] for e in ex["errors.json"]]
    if codes != load(SCHEMAS / "error.schema.json")["properties"]["error"]["properties"]["code"]["enum"]:
        errs.append("errors.json: needs one example per error code, in schema enum order")
    retry = {"rate_limited", "chat_daily_cap", "chat_resting", "upstream_unavailable"}
    details = {"bad_request": {"reason"}, "validation_error": {"fields"}, "not_found": None,
               "title_not_found": {"title_id"}, "rate_limited": {"scope"}, "chat_daily_cap": {"cap"},
               "chat_resting": {"reason"}, "upstream_unavailable": {"upstream"}, "internal_error": None}
    for e in (x["error"] for x in ex["errors.json"]):
        if (e["retry_after_s"] is not None) != (e["code"] in retry):
            errs.append(f"errors.json: {e['code']} retry_after_s must be {'set' if e['code'] in retry else 'null'}")
        got = None if e["details"] is None else set(e["details"])
        if got != details.get(e["code"]) and not (e["code"] == "bad_request" and got is None):
            errs.append(f"errors.json: {e['code']} details keys {got} != {details.get(e['code'])}")
    allowed = {("rate_limited", "scope"): {"ip", "install"}, ("chat_resting", "reason"): {"providers_down", "global_cap"}}
    for e in (x["error"] for x in ex["errors.json"]):
        for (code, key), values in allowed.items():
            if e["code"] == code and (e["details"] or {}).get(key) not in values:
                errs.append(f"errors.json: {code} details.{key} must be one of {sorted(values)}")

    # Fonts (DESIGN_SPEC 10.5): exactly the four bundled families, one OFL.txt folder each
    fonts = ex["fonts.json"]["fonts"]
    if {f["family"] for f in fonts} != {"Figtree", "Cinzel", "Caveat Brush", "Big Shoulders Stencil Display"}:
        errs.append("fonts.json: families must be the four in DESIGN_SPEC 10.5")
    if len({f["license_asset"] for f in fonts}) != len(fonts):
        errs.append("fonts.json: each family needs its own OFL.txt path")
    return errs


# ---------- 3. match % cases ----------

def match_checks(doc):
    errs = []
    for case in doc["cases"]:
        badges, rows = match_scores(doc["titles"], case["signals"])
        if badges != case["badges"]:
            errs.append(f"{case['name']}: badges {badges} != {case['badges']}")
        exp = case["expected"]
        if [r["id"] for r in rows] != [e["id"] for e in exp]:
            errs.append(f"{case['name']}: order {[r['id'] for r in rows]}")
            continue
        for r, e in zip(rows, exp):
            same_raw = (r["raw"] is None and e["raw"] is None) or (
                r["raw"] is not None and e["raw"] is not None and abs(r["raw"] - e["raw"]) <= 1e-4)
            if not same_raw or r["pct"] != e["pct"] or r["reason"] != e["reason"]:
                errs.append(f"{case['name']}: {r['id']} got {r} expected {e}")
    return errs


def report(label, errs):
    print(("PASS " if not errs else "FAIL ") + label)
    for e in errs:
        print("   ", e)
    return bool(errs)


def main():
    reg, failed, titles = registry(), False, []
    for name in TITLE_SAMPLES:
        doc = load(SAMPLES / name)
        titles.append(doc)
        errs = schema_errors(doc, "title.schema.json", reg)
        errs += schema_errors(doc, "title-import.schema.json", reg)
        errs += title_checks(doc)
        failed |= report(name, errs)

    # real title files (S11 ingest drafts, later reviewed/published): import schema + referential rules
    for path in sorted(TITLES.glob("*.json")):
        doc = load(path)
        errs = schema_errors(doc, "title-import.schema.json", reg)
        if not errs:
            errs = title_checks(doc, sample=False)
        failed |= report("titles/" + path.name, errs)

    if not EXAMPLES.is_dir():
        print("SKIP docs/examples/ (not created yet; once it exists every example file is required)")
        sys.exit(1 if failed else 0)
    ex = {}
    for name, ref in EXAMPLE_FILES.items():
        if not (EXAMPLES / name).is_file():
            failed |= report("examples/" + name, ["missing file"])
            continue
        doc = load(EXAMPLES / name)
        ex[name] = doc
        items = doc if isinstance(doc, list) else [doc]
        failed |= report("examples/" + name, [e for d in items for e in schema_errors(d, ref, reg)])
    if len(ex) == len(EXAMPLE_FILES):
        failed |= report("examples cross-checks", example_checks(ex, titles))
    if (EXAMPLES / "match-cases.json").is_file():
        failed |= report("examples/match-cases.json", match_checks(load(EXAMPLES / "match-cases.json")))
    else:
        failed |= report("examples/match-cases.json", ["missing file"])
    sys.exit(1 if failed else 0)


if __name__ == "__main__":
    main()
