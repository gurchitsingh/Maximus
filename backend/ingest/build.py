"""Build a draft title (CONTRACTS import format, `status: draft`) from a seed entry (ingest/seed.json).

Seed entry: the editorial fields (id, kind, name, poster_lines, group, era, region, themes, bg, tint, lettering,
rank, linked_title_ids, optional subtitle / period_start / period_end / brief / hero_image + hero_alt / wikidata)
and `pages`: [{"page": "Roman Republic", "sections": ["lead", {"name": "History", "max_words": 300}],
"heading": "...", "max_words": 550}]. An entry with `sections` is one lesson (split only if it runs past 600
words); without `sections` every article section becomes its own lesson. `heading` names the entry's lesson.

Re-running on an existing draft keeps what other tools own: quiz, feed_facts, person and `role: citation`
sources (S13), and reuses source and image ids by URL so references stay stable.
"""
import hashlib
from pathlib import Path
from urllib.parse import urlparse

from ingest import commons, wikidata, wikipedia
from ingest.gate import reading_minutes
from ingest.client import FetchError
from ingest.split import SENTENCE, item_words, plan_lessons, trim
from ingest.split import body as lesson_body

TEXT_LICENCE = "CC BY-SA 4.0"
MAX_IMAGES = 24
EDITORIAL = ["id", "kind", "name", "subtitle", "poster_lines", "group", "era", "region", "period_start",
             "period_end", "themes", "bg", "tint", "lettering", "poster_image_id", "hero_image_id", "brief",
             "linked_title_ids", "rank", "status"]


class SeedError(ValueError):
    pass


def _next_id(prefix: str, used: set[str]) -> str:
    n = 1
    while f"{prefix}{n:02d}" in used:
        n += 1
    used.add(f"{prefix}{n:02d}")
    return f"{prefix}{n:02d}"


def brief_from(text: str) -> str:
    """First sentence(s) of the lead, within 200 characters, never cut mid-sentence unless one sentence is longer."""
    out = ""
    for s in SENTENCE.split(text):
        cand = (out + " " + s).strip()
        if len(cand) > 200:
            break
        out = cand
    if out:
        return out
    return text[:199].rsplit(" ", 1)[0].rstrip(",;:") + "…"


def _section(seed_id: str, pg: dict, name: str):
    key = None if name == "lead" else wikipedia.norm_heading(name)
    for s in pg["sections"]:
        if wikipedia.norm_heading(s["heading"]) == key:
            return key, s
    have = ", ".join(s["heading"] or "lead" for s in pg["sections"])
    raise SeedError(f"{seed_id}: section {name!r} not in {pg['title']!r} (has: {have})")


def _picks(seed: dict, pages: dict) -> list[dict]:
    """One pick per seed entry when it lists `sections` (later sections become `## ` sub-headings; the
    splitter still breaks it up if it runs past 600 words). Without `sections`, each article section is its
    own pick. A section may be {"name": ..., "max_words": n, "heading": "..."} to shorten or rename just it."""
    picks = []
    for entry in seed["pages"]:
        pg = pages[entry["page"]]
        if entry.get("sections"):
            groups = [[x if isinstance(x, dict) else {"name": x} for x in entry["sections"]]]
        else:
            groups = [[{"name": "lead"}]] + [[{"name": s["heading"]}] for s in pg["sections"] if s["heading"]]
        for g, group in enumerate(groups):
            items, files, heading = [], [], None
            for n, spec in enumerate(group):
                key, sec = _section(seed["id"], pg, spec["name"])
                sec_items = trim(sec["items"], spec["max_words"]) if spec.get("max_words") else sec["items"]
                title = spec.get("heading") or (sec["heading"] if key else pg["title"])
                if n == 0:
                    heading = title
                else:
                    items.append(("sub", title))
                items += sec_items
                files += [i["file"] for i in pg["images"] if wikipedia.norm_heading(i["section"]) == key]
            if g == 0 and entry.get("heading"):
                heading = entry["heading"]
            picks.append({"heading": heading, "items": items, "source_id": pg["source_id"], "images": files,
                          "max_words": entry.get("max_words"), "page": pg["title"]})
    return picks


def build(seed: dict, client, *, existing: dict | None = None, media_dir: Path, media_base_url: str,
          download: bool = True) -> tuple[dict, dict]:
    tid = seed["id"]
    if seed["kind"] != "topic" and not (existing and existing.get("person")):
        raise SeedError(f"{tid}: {seed['kind']} titles need their person block first (S13 / Perplexity draft); "
                        "the Wikipedia ingest only adds lessons, images and text sources")
    old = existing or {}
    report = {"title_id": tid, "pages": [], "rejected": [], "warnings": [], "wikidata": None, "lessons": []}

    # 1. text
    pages, src_ids = {}, {s["url"]: s["id"] for s in old.get("sources", [])}
    used_src = {s["id"].rsplit(".", 1)[1] for s in old.get("sources", []) if s["role"] == "citation"}
    used_src |= {i.rsplit(".", 1)[1] for i in src_ids.values()}
    sources = [s for s in old.get("sources", []) if s["role"] == "citation"]
    for entry in seed["pages"]:
        if entry["page"] in pages:
            continue
        pg = wikipedia.fetch_page(client, entry["page"])
        sid = src_ids.get(pg["url"]) or f"{tid}." + _next_id("s", used_src)
        pg["source_id"] = sid
        pages[entry["page"]] = pg
        if all(s["id"] != sid for s in sources):
            sources.append({"id": sid, "title": f"{pg['title']} (Wikipedia)"[:200], "url": pg["url"],
                            "publisher": "Wikipedia", "role": "text", "license": TEXT_LICENCE, "confidence": None})
        report["pages"].append({"page": entry["page"], "title": pg["title"], "url": pg["url"], "revid": pg["revid"]})
    sources.sort(key=lambda s: s["id"])
    picks = _picks(seed, pages)

    # 2. Wikidata
    first = pages[seed["pages"][0]["page"]]
    qid = seed.get("wikidata") or first["wikibase_item"]
    try:
        wd = wikidata.facts(client, qid)
    except FetchError as e:  # Wikidata only adds facts the seed may already have: never fatal
        report["warnings"].append(f"Wikidata {qid} unavailable ({e}); seed values only")
        wd = wikidata.facts(client, None)
    report["wikidata"] = wd

    # 3. Commons
    hero_wish = [f for f in (seed.get("hero_image"), wd["image"]) if f]
    wanted, captions = [], {}
    for pk in picks:
        for f in pk["images"]:
            if f not in wanted:
                wanted.append(f)
    for pg in pages.values():
        for i in pg["images"]:
            captions.setdefault(i["file"], i["caption"])
    if seed.get("hero_image") and seed.get("hero_alt"):
        captions[seed["hero_image"]] = seed["hero_alt"]  # written by the editor, wins over Wikipedia's caption
    for f in hero_wish:
        if f not in wanted:
            wanted.append(f)
    ask = []
    for f in wanted:
        why = commons.name_ok(f)
        if why:
            report["rejected"].append({"file": f, "reason": why})
        else:
            ask.append(f)
    info = commons.query(client, ask) if ask else {}
    accepted = {}
    for f in ask:
        cand, why = commons.evaluate(f, info.get(f), captions.get(f))
        if cand:
            accepted[f] = cand
        else:
            report["rejected"].append({"file": f, "reason": why})
    for pk in picks:
        pk["images"] = [f for f in pk["images"] if f in accepted]

    # 4. lessons
    planned = plan_lessons(picks)
    if not planned:
        raise SeedError(f"{tid}: no lesson text found in the seed pages")
    hero_file = next((f for f in hero_wish if f in accepted), None) or \
        next((f for les in planned for f in les["image_ids"]), None)
    order = ([hero_file] if hero_file else []) + [f for les in planned for f in les["image_ids"]]
    order = list(dict.fromkeys(order))[:MAX_IMAGES]
    keep = set(order)

    img_ids = {i["source_page_url"]: i["id"] for i in old.get("images", [])}
    used_img = {i.rsplit(".", 1)[1] for i in img_ids.values()}
    images, file_to_id = [], {}
    for f in order:
        c = accepted[f]
        iid = img_ids.get(c["source_page_url"]) or f"{tid}." + _next_id("i", used_img)
        file_to_id[f] = iid
        ext = Path(urlparse(c["download_url"]).path).suffix.lower() or ".jpg"
        ext = ".jpg" if ext == ".jpeg" else ext
        # the source URL's hash is in the name: a changed picture gets a new file and a new URL (app cache)
        digest = hashlib.sha256(c["download_url"].encode()).hexdigest()[:10]
        name = f"{iid.rsplit('.', 1)[1]}-{digest}{ext}"
        if download:
            client.download(c["download_url"], Path(media_dir) / tid / name)
        portrait = c["kind"] == "portrait"
        images.append({"id": iid, "title_id": tid, "url": f"{media_base_url.rstrip('/')}/{tid}/{name}",
                       "width": c["width"], "height": c["height"], "alt": c["alt"], "kind": c["kind"],
                       "author": c["author"], "license": c["license"], "license_version": c["license_version"],
                       "license_url": c["license_url"], "source_page_url": c["source_page_url"],
                       "credit_line": c["credit_line"], "modified": c["modified"],
                       "focal_x": 0.5, "focal_y": 0.35 if portrait else 0.5})
    images.sort(key=lambda i: i["id"])

    lessons = []
    for n, les in enumerate(planned, 1):
        ids = [file_to_id[f] for f in les["image_ids"] if f in keep]
        text = lesson_body(les["items"], ids[1:])
        lessons.append({"id": f"{tid}.l{n:02d}", "title_id": tid, "index": n, "heading": les["heading"],
                        "body": text, "reading_minutes": reading_minutes(text), "image_ids": ids,
                        "read_aloud_text": None, "source_ids": les["source_ids"]})
        report["lessons"].append({"id": lessons[-1]["id"], "heading": les["heading"],
                                  "words": item_words(les["items"]), "images": len(ids)})

    # 5. title fields: seed wins, then Wikidata, then the article
    start = seed["period_start"] if "period_start" in seed else wd["period_start"]
    end = seed["period_end"] if "period_end" in seed else wd["period_end"]
    for label, s_val, w_val in (("period_start", seed.get("period_start"), wd["period_start"]),
                                ("period_end", seed.get("period_end"), wd["period_end"])):
        if s_val is not None and w_val is not None and s_val != w_val:
            report["warnings"].append(f"{label}: seed {s_val}, Wikidata {qid} says {w_val} (seed kept; check it)")
    lead = next((t for k, t in picks[0]["items"] if k == "p"), "")
    draft = {
        "id": tid, "kind": seed["kind"], "name": seed["name"],
        "subtitle": seed["subtitle"] if "subtitle" in seed else wikidata.period_label(start, end),
        "poster_lines": seed["poster_lines"], "group": seed["group"], "era": seed["era"],
        "region": seed["region"], "period_start": start, "period_end": end, "themes": seed["themes"],
        "bg": seed["bg"], "tint": seed["tint"], "lettering": seed["lettering"],
        "poster_image_id": old.get("poster_image_id"),
        "hero_image_id": file_to_id.get(hero_file) if hero_file else None,
        "brief": seed.get("brief") or brief_from(lead),
        "linked_title_ids": seed.get("linked_title_ids", []), "rank": seed.get("rank", 999),
        "status": "draft",
        "lessons": lessons, "images": images,
        "quiz": old.get("quiz", []), "feed_facts": old.get("feed_facts", []),
        "person": old.get("person"), "sources": sources,
    }
    if draft["poster_image_id"] and draft["poster_image_id"] not in {i["id"] for i in images}:
        own = [i for i in old.get("images", []) if i["id"] == draft["poster_image_id"]]
        draft["images"] = sorted(images + own, key=lambda i: i["id"])
    lesson_set = {l["id"] for l in lessons}
    stale = [x["id"] for x in draft["quiz"] + draft["feed_facts"] if x["lesson_id"] and x["lesson_id"] not in lesson_set]
    if stale:
        report["warnings"].append(f"{len(stale)} quiz/feed item(s) point at lessons that no longer exist: "
                                  + ", ".join(stale[:8]))
    return draft, report

