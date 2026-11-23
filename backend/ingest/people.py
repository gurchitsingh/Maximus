"""Import the person block of a leader / thinker title from a Claude draft of Perplexity's research (S13;
CONTRACTS 2.4, 2.9, 9.2 step 4; llm/perplexity.md).

Input   data/drafts/<id>.person.json = {"person": {...}}, the CONTRACTS 2.4 person fields with one change: a claim
        lists `sources` (url, title, optional publisher, confidence) instead of `source_ids`. Optional fields
        (`died`, `odds_beaten`, `core_ideas`, `legend_note`) default to null / [] / [] / null.
        Optional `--research research/people-<batch>.md`: Perplexity's `claim | source URL | confidence` tables.
Output  the title file gets `person` filled in and the cited pages added to `sources` as `role: citation`
        (ids <id>.sNN after the existing ones, one source per URL, reused when the URL is already a citation).

Rules
- The title file must already exist with kind leader or thinker (the people lessons and editorial fields are not
  made here). Text sources and everything else in the file are untouched; the title status is not changed.
- Schema 2.1 gives every leader / thinker a person block (even a placeholder), so a `draft` title is simply
  overwritten: re-run after fixing the draft. A `reviewed` or `published` title is not overwritten without
  `replace`. Same content = no change.
- With a research file, every cited URL must appear in it and a draft may not claim higher confidence than the
  research gave (high > medium > low). The model-facing draft cannot invent a source.
- Claims with fewer than 2 distinct sources, or only low-confidence ones, and legend titles without a legend_note
  import with a WARNING: they are allowed in a draft and stop `publish` (gate G7, G8).
- All or nothing; atomic write; the whole title must pass G1 afterwards.
"""
import json
import re
from dataclasses import dataclass, field
from pathlib import Path
from urllib.parse import urlsplit, urlunsplit

from ingest import gate
from ingest.titlefile import UsageError, load_title, valid_before, write_json

PERSON = "title.schema.json#/$defs/person"
GROUPS = {"traits": ("name", "text"), "changes": ("text",),
          "odds_beaten": ("event", "year_display", "why_impossible", "outcome", "outcome_kind"),
          "core_ideas": ("name", "text"), "use_today": ("text",)}
OPTIONAL_CLAIM_FIELDS = {"year_display"}
TOP_REQUIRED = ("role", "born", "region", "headline", "traits", "changes", "use_today")
TOP_OPTIONAL = ("died", "odds_beaten", "core_ideas", "legend_note")
PERSON_ORDER = ("role", "born", "died", "region", "headline", "traits", "changes", "odds_beaten", "core_ideas",
                "use_today", "legend_note")
SOURCE_KEYS = {"url", "title", "publisher", "confidence"}
RANK = {"low": 0, "medium": 1, "high": 2}
URL = re.compile(r"https?://[^\s|<>\"')\]]+")
LEGEND_IDS = gate.LEGEND_IDS


@dataclass
class PeopleResult:
    title_id: str
    errors: list[str] = field(default_factory=list)
    warnings: list[str] = field(default_factory=list)
    new_sources: list[dict] = field(default_factory=list)
    reused_sources: int = 0
    claims: int = 0
    unchanged: bool = False
    dry_run: bool = False
    written: bool = False

    @property
    def ok(self) -> bool:
        return not self.errors


def norm_url(url: str) -> str:
    p = urlsplit(url.strip())
    return urlunsplit((p.scheme.lower(), p.netloc.lower(), p.path.rstrip("/"), p.query, ""))


def parse_research(text: str) -> dict[str, str]:
    """{normalised url: lowest confidence seen} from the table rows of a Perplexity research file."""
    found: dict[str, str] = {}
    for line in text.splitlines():
        if "|" not in line and "](" not in line:
            continue
        urls = [u.rstrip(".,;") for u in URL.findall(line)]
        conf = re.findall(r"\b(high|medium|low)\b", URL.sub(" ", line), re.I)
        for u in urls:
            k = norm_url(u)
            c = conf[-1].lower() if conf else None
            if c is None:
                found.setdefault(k, "low")  # a URL with no stated confidence is treated as low
            elif k not in found or RANK[c] < RANK[found[k]]:
                found[k] = c
    return found


def _read(path: Path, errors: list[str]) -> dict | None:
    raw = path.read_text("utf-8-sig")
    m = re.match(r"^\s*```[a-zA-Z]*\s*\n(.*?)\n\s*```\s*$", raw, re.S)
    try:
        doc = json.loads(m.group(1) if m else raw)
    except json.JSONDecodeError as e:
        errors.append(f"{path.name}: not valid JSON: {e.msg} (line {e.lineno}, column {e.colno})")
        return None
    if not isinstance(doc, dict) or set(doc) != {"person"} or not isinstance(doc["person"], dict):
        errors.append(f'{path.name}: must be an object with exactly one key "person" holding an object')
        return None
    return doc["person"]


def _trim(v):
    if isinstance(v, str):
        return v.strip()
    return [_trim(x) for x in v] if isinstance(v, list) else v


def import_person(title_id: str, titles_dir: Path, drafts_dir: Path, *, research: Path | None = None,
                  replace: bool = False, dry_run: bool = False) -> PeopleResult:
    """Raises UsageError when it cannot start (no title, wrong kind, no draft); else returns a PeopleResult."""
    path, title = load_title(title_id, titles_dir)
    if title.get("kind") not in ("leader", "thinker"):
        raise UsageError(f"{title_id} is a {title.get('kind')}: only leader and thinker titles have a person block")
    draft_path = Path(drafts_dir) / f"{title_id}.person.json"
    if not draft_path.is_file():
        raise UsageError(f"no draft for {title_id}: expected {draft_path.name} in {drafts_dir}")
    if research is not None and not Path(research).is_file():
        raise UsageError(f"research file not found: {research}")
    res = PeopleResult(title_id, dry_run=dry_run)
    res.errors += valid_before(title, path)
    draft = _read(draft_path, res.errors)
    if res.errors or draft is None:
        return res
    known_urls = parse_research(Path(research).read_text("utf-8-sig")) if research else None

    # 1. the draft's own shape
    err = res.errors
    for k in draft:
        if k not in TOP_REQUIRED + TOP_OPTIONAL:
            err.append(f"{k}: unknown field")
    err += [f"{k}: missing" for k in TOP_REQUIRED if k not in draft]
    for g in GROUPS:
        if g in draft and not isinstance(draft[g], list):
            err.append(f"{g}: must be a list")
    if err:
        return res

    # 2. claims and their sources
    registry: dict[str, dict] = {}   # norm url -> {url, title, publisher, confidence}
    shaped: dict[str, list] = {}  # group -> [(claim without source_ids, [normalised urls])]
    for g, fields in GROUPS.items():
        out = []
        for n, raw in enumerate(draft.get(g, []), 1):
            raw_text = raw.get(fields[0]) if isinstance(raw, dict) else None
            where = f"{g} #{n}" + (f' ("{str(raw_text)[:30]}")' if raw_text else "")
            if not isinstance(raw, dict):
                err.append(f"{where}: must be an object")
                continue
            if "source_ids" in raw:
                err.append(f"{where}: source_ids: the draft must not set this, the tool assigns it; list `sources`")
            err += [f"{where}: {k}: unknown field" for k in raw
                    if k not in fields and k not in ("sources", "source_ids")]
            err += [f"{where}: {k}: missing" for k in fields if k not in raw and k not in OPTIONAL_CLAIM_FIELDS]
            srcs = raw.get("sources")
            keys: list[str] = []
            if not isinstance(srcs, list) or not srcs:
                err.append(f"{where}: sources: give at least one source")
                srcs = []
            for m, s in enumerate(srcs, 1):
                sw = f"{where} source #{m}"
                if not isinstance(s, dict):
                    err.append(f"{sw}: must be an object")
                    continue
                err += [f"{sw}: {k}: unknown field" for k in s if k not in SOURCE_KEYS]
                url, conf = s.get("url"), s.get("confidence")
                if not isinstance(url, str) or not re.match(r"^https?://\S+$", url.strip()):
                    err.append(f"{sw}: url: must be an http(s) address")
                    continue
                if conf not in RANK:
                    err.append(f"{sw}: confidence: must be high, medium or low")
                    continue
                title_s = (s.get("title") or "").strip()
                if not 1 <= len(title_s) <= 200:
                    err.append(f"{sw}: title: 1 to 200 characters (name the page, as in 'Chanakya (Britannica)')")
                    continue
                pub = s.get("publisher")
                if pub is not None and (not isinstance(pub, str) or len(pub.strip()) > 120):
                    err.append(f"{sw}: publisher: text up to 120 characters or null")
                    continue
                k = norm_url(url)
                if known_urls is not None:
                    if k not in known_urls:
                        err.append(f"{sw}: url: {url.strip()} is not in the research file")
                    elif RANK[conf] > RANK[known_urls[k]]:
                        err.append(f"{sw}: confidence: {conf} is higher than the research's {known_urls[k]}")
                if k in registry:
                    if conf != registry[k]["confidence"]:
                        res.warnings.append(f"{url.strip()}: given as {registry[k]['confidence']} and {conf}; "
                                            f"kept the lower one")
                        if RANK[conf] < RANK[registry[k]["confidence"]]:
                            registry[k]["confidence"] = conf
                else:
                    registry[k] = {"url": url.strip(), "title": title_s, "publisher": pub.strip() if pub else None,
                                   "confidence": conf}
                if k in keys:
                    res.warnings.append(f"{where}: the same source is listed twice")
                else:
                    keys.append(k)
            if len(keys) < 2:
                res.warnings.append(f"{where}: {len(keys)} distinct source(s), publishing needs 2 (G7)")
            elif all(registry[k]["confidence"] == "low" for k in keys):
                res.warnings.append(f"{where}: only low-confidence sources (G7)")
            out.append(({f: _trim(raw[f]) if f in raw else None for f in fields}, keys))
        shaped[g] = out
    if err:
        return res

    # 3. source ids: reuse an existing citation with the same URL, else the next free number
    ids: dict[str, str] = {}
    stored: dict[str, dict] = {}
    for s in title["sources"]:
        if s["role"] == "citation":
            ids.setdefault(norm_url(s["url"]), s["id"])
            stored.setdefault(norm_url(s["url"]), s)
    nums = [int(s["id"].rsplit(".s", 1)[1]) for s in title["sources"]]
    nxt = max(nums, default=0) + 1
    for k, s in registry.items():  # dict order = first use in the draft
        if k in ids:
            res.reused_sources += 1
            if stored[k]["confidence"] != s["confidence"]:
                res.warnings.append(f"{ids[k]} ({s['url']}) is already stored as {stored[k]['confidence']} "
                                    f"confidence, the draft says {s['confidence']}; the stored source is kept")
            continue
        ids[k] = f"{title_id}.s{nxt:02d}"
        res.new_sources.append({"id": ids[k], "title": s["title"], "url": s["url"], "publisher": s["publisher"],
                                "role": "citation", "license": None, "confidence": s["confidence"]})
        nxt += 1
    shaped = {g: [{**c, "source_ids": [ids[k] for k in keys]} for c, keys in claims] for g, claims in shaped.items()}
    res.claims = sum(len(v) for v in shaped.values())

    # 4. the person block against the schema, then the whole title
    person = {k: _trim(draft[k]) if k in draft else ([] if k in ("odds_beaten", "core_ideas") else None)
              for k in PERSON_ORDER if k not in GROUPS}
    person.update(shaped)
    person = {k: person[k] for k in PERSON_ORDER}
    err += [f"person {e}" for e in gate.schema_errors(person, PERSON)]
    if title_id in LEGEND_IDS and not person["legend_note"]:
        res.warnings.append("legend_note: this title needs one before it can be published (G8)")
    if err:
        return res
    merged = {**title, "person": person, "sources": title["sources"] + res.new_sources}
    if title.get("person") and title["person"] != person and title["status"] != "draft" and not replace:
        err.append(f"the title is {title['status']}; its person block is not overwritten without --replace")
        return res
    if title.get("person") == person and not res.new_sources:
        res.unchanged = True
        return res
    after = gate.g1_errors(merged)
    if after:
        err += [f"the title would fail G1 ({e})" for e in after]
        return res
    used = {i for g in shaped.values() for c in g for i in c["source_ids"]}
    stale = [s["id"] for s in title["sources"] if s["role"] == "citation" and s["id"] not in used]
    if stale:
        res.warnings.append(f"citation sources no longer used by the person block (kept): {', '.join(stale)}")
    if not dry_run:
        write_json(path, merged)
        res.written = True
    return res


def format_report(res: PeopleResult) -> str:
    lines = [f"== {res.title_id}"]
    if res.errors:
        lines.append(f"   FAILED, {len(res.errors)} problem(s):")
        lines += [f"      - {e}" for e in res.errors]
        lines.append("   Nothing was written. Fix the draft and re-run.")
        return "\n".join(lines)
    if res.unchanged:
        return "\n".join(lines + ["   person block already up to date, nothing changed"])
    tag = "  [dry run, nothing written]" if res.dry_run else ""
    lines.append(f"   person block: {res.claims} claim(s), +{len(res.new_sources)} new citation source(s), "
                 f"{res.reused_sources} reused{tag}")
    lines += [f"   WARNING {w}" for w in res.warnings]
    lines.append(f"   next: python -m ingest.cli report {res.title_id}")
    return "\n".join(lines)
