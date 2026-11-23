"""S13 people import (CONTRACTS 2.4, 2.9, 9.2 step 4, llm/perplexity.md). Fake research and drafts only.
Base title = the chanakya sample (thinker, draft)."""
import copy
import json

import pytest

from ingest import cli, gate, people, review
from ingest.titlefile import UsageError
from tests.conftest import SAMPLES

WIKI = "https://en.wikipedia.org/wiki/Chanakya"           # already a citation in the sample (s01), stored as low
BRIT = "https://www.britannica.com/biography/Chanakya"
ARTH = "https://example.org/arthashastra-notes"
THIRD = "https://example.org/third"


def src(url, conf="high", title=None, publisher=None):
    return {"url": url, "title": title or f"Page at {url[-14:]}", "publisher": publisher, "confidence": conf}


def claim(n, *sources, **extra):
    return {"text": f"Fake claim number {n}.", "sources": list(sources) or [src(BRIT), src(ARTH)], **extra}


def named(n, *sources):
    return {"name": f"Name {n}", "text": f"Fake named claim {n}.", "sources": list(sources) or [src(BRIT), src(ARTH)]}


def draft():
    return {"person": {
        "role": "Teacher and royal adviser", "born": {"year": -375, "display": "c. 375 BCE (traditional)"},
        "died": None, "region": "Magadha, ancient India", "headline": "Fake headline",
        "traits": [named(1), named(2), named(3, src(BRIT), src(THIRD, "medium"))],
        "changes": [claim(1)], "core_ideas": [named(4, src(WIKI), src(BRIT))], "use_today": [claim(2)],
        "legend_note": "Fake: life story mixes history and tradition."}}


@pytest.fixture
def dirs(tmp_path):
    t = json.loads((SAMPLES / "chanakya.json").read_text("utf-8"))
    titles, drafts = tmp_path / "titles", tmp_path / "drafts"
    titles.mkdir()
    drafts.mkdir()
    (titles / "chanakya.json").write_text(json.dumps(t, ensure_ascii=False, indent=2), "utf-8")
    return titles, drafts


def put(dirs, d=None, raw=None):
    (dirs[1] / "chanakya.person.json").write_text(raw if raw is not None else json.dumps(d or draft()), "utf-8")


def run(dirs, **kw):
    return people.import_person("chanakya", dirs[0], dirs[1], **kw)


def stored(dirs):
    return json.loads((dirs[0] / "chanakya.json").read_text("utf-8"))


def mutate(dirs, fn):
    d = draft()
    fn(d["person"])
    put(dirs, d)


# ---- happy path ----------------------------------------------------------------------------------------------------

def test_import_fills_person_and_adds_citation_sources(dirs):
    before = stored(dirs)
    put(dirs)
    res = run(dirs)
    assert res.ok and res.written and res.claims == 6
    t = stored(dirs)
    p = t["person"]
    assert p["role"] == "Teacher and royal adviser" and p["born"]["year"] == -375 and p["died"] is None
    assert p["odds_beaten"] == [] and p["legend_note"].startswith("Fake")
    assert [list(x) for x in p["traits"]][0] == ["name", "text", "source_ids"]
    assert gate.g1_errors(t) == []
    new = t["sources"][len(before["sources"]):]
    assert [s["url"] for s in new] == [BRIT, ARTH, THIRD] and all(s["role"] == "citation" for s in new)
    assert [s["id"] for s in new] == ["chanakya.s%02d" % (len(before["sources"]) + i) for i in (1, 2, 3)]
    assert {s["id"]: s["confidence"] for s in new}[new[2]["id"]] == "medium"
    assert all(s["license"] is None for s in new)


def test_existing_sources_and_everything_else_are_untouched(dirs):
    before = stored(dirs)
    put(dirs)
    run(dirs)
    after = stored(dirs)
    assert after["sources"][:len(before["sources"])] == before["sources"]
    assert {k: v for k, v in after.items() if k not in ("person", "sources")} == \
           {k: v for k, v in before.items() if k not in ("person", "sources")}


def test_a_url_already_cited_is_reused_not_duplicated(dirs):
    before = stored(dirs)
    wiki_id = next(s["id"] for s in before["sources"] if s["url"] == WIKI)
    put(dirs)
    res = run(dirs)
    assert res.reused_sources == 1
    t = stored(dirs)
    assert wiki_id in t["person"]["core_ideas"][0]["source_ids"]
    assert sum(s["url"] == WIKI for s in t["sources"]) == 1
    assert any("already stored as low" in w for w in res.warnings), "draft said high, stored is low: stored kept"


def test_url_forms_match_ignoring_host_case_slash_and_fragment(dirs):
    d = draft()
    d["person"]["use_today"][0] = claim(2, src("https://WWW.Britannica.com/biography/Chanakya/#x"), src(ARTH))
    put(dirs, d)
    res = run(dirs)
    assert res.ok and sum("britannica.com" in s["url"].lower() for s in stored(dirs)["sources"]) == 1
    ids = {s["url"]: s["id"] for s in stored(dirs)["sources"]}
    assert len(ids) == len(stored(dirs)["sources"])


def test_same_url_with_two_confidences_keeps_the_lower_and_warns(dirs):
    mutate(dirs, lambda p: p["use_today"].__setitem__(0, claim(2, src(BRIT, "low"), src(ARTH))))
    res = run(dirs)
    assert res.ok and any("kept the lower" in w for w in res.warnings)
    assert next(s for s in stored(dirs)["sources"] if s["url"] == BRIT)["confidence"] == "low"


def test_rerun_is_a_no_op_and_reimport_of_a_draft_title_overwrites(dirs):
    put(dirs)
    run(dirs)
    snap = (dirs[0] / "chanakya.json").read_bytes()
    res = run(dirs)
    assert res.ok and res.unchanged and (dirs[0] / "chanakya.json").read_bytes() == snap
    mutate(dirs, lambda p: p.update(headline="Changed headline"))
    res = run(dirs)
    assert res.ok and stored(dirs)["person"]["headline"] == "Changed headline"
    assert len(stored(dirs)["sources"]) == len(json.loads(snap)["sources"]), "no duplicate sources"


def test_reviewed_title_needs_replace(dirs):
    t = stored(dirs)
    t["status"] = "reviewed"
    (dirs[0] / "chanakya.json").write_text(json.dumps(t), "utf-8")
    put(dirs)
    snap = (dirs[0] / "chanakya.json").read_bytes()
    res = run(dirs)
    assert not res.ok and "--replace" in "\n".join(res.errors) and (dirs[0] / "chanakya.json").read_bytes() == snap
    assert run(dirs, replace=True).ok and stored(dirs)["status"] == "reviewed"


def test_dry_run_writes_nothing(dirs):
    put(dirs)
    snap = (dirs[0] / "chanakya.json").read_bytes()
    res = run(dirs, dry_run=True)
    assert res.ok and not res.written and res.new_sources and (dirs[0] / "chanakya.json").read_bytes() == snap


def test_unused_old_citations_are_kept_with_a_warning(dirs):
    put(dirs)
    res = run(dirs)
    assert any("no longer used" in w for w in res.warnings) or res.reused_sources


def test_leader_needs_odds_beaten(dirs):
    t = stored(dirs)
    t["kind"] = "leader"
    t["person"]["odds_beaten"] = [{"event": "e", "year_display": None, "why_impossible": "w", "outcome": "o",
                                   "outcome_kind": "won", "source_ids": [t["sources"][0]["id"]]}]
    (dirs[0] / "chanakya.json").write_text(json.dumps(t), "utf-8")
    put(dirs)
    res = run(dirs)
    assert not res.ok and "odds_beaten" in "\n".join(res.errors)
    d = draft()
    d["person"]["odds_beaten"] = [{"event": "Held the pass", "why_impossible": "Outnumbered ten to one",
                                   "outcome": "Held it for a week", "outcome_kind": "refused_to_surrender",
                                   "sources": [src(BRIT), src(ARTH)]}]
    put(dirs, d)
    res = run(dirs)
    assert res.ok and stored(dirs)["person"]["odds_beaten"][0]["year_display"] is None


# ---- warnings (allowed in a draft, blocked by the publish gate) -----------------------------------------------------

def test_single_source_and_low_only_claims_warn_and_publish_gate_blocks(dirs):
    mutate(dirs, lambda p: p.update(changes=[claim(1, src(BRIT))],
                                    use_today=[claim(2, src(ARTH, "low"), src(THIRD, "low"))]))
    res = run(dirs)
    text = "\n".join(res.warnings)
    assert res.ok and "changes #1" in text and "1 distinct" in text and "use_today #1" in text and "low-confidence" in text
    rep = gate.check({**stored(dirs), "brief": "Fine brief."})
    assert "G7" in rep.rules()


def test_legend_without_note_warns(dirs):
    mutate(dirs, lambda p: p.update(legend_note=None))
    res = run(dirs)
    assert res.ok and any("G8" in w for w in res.warnings) and "G8" in gate.check(stored(dirs)).rules()


# ---- errors (nothing written) -------------------------------------------------------------------------------------

BAD = {
    "source_ids set": (lambda p: p["changes"][0].update(source_ids=["chanakya.s01"]), "source_ids"),
    "no sources": (lambda p: p["changes"][0].update(sources=[]), "sources"),
    "sources missing": (lambda p: p["changes"][0].pop("sources"), "sources"),
    "url not http": (lambda p: p["changes"][0].update(sources=[src("ftp://x.org/a"), src(ARTH)]), "url"),
    "bad confidence": (lambda p: p["changes"][0].update(sources=[src(BRIT, "sure"), src(ARTH)]), "confidence"),
    "no source title": (lambda p: p["changes"][0].update(sources=[{**src(BRIT), "title": ""}, src(ARTH)]), "title"),
    "unknown source key": (lambda p: p["changes"][0].update(sources=[{**src(BRIT), "id": "x"}, src(ARTH)]), "id"),
    "claim text over 300": (lambda p: p["changes"][0].update(text="x" * 301), "text"),
    "two traits only": (lambda p: p.update(traits=p["traits"][:2]), "traits"),
    "six traits": (lambda p: p.update(traits=[named(i) for i in range(6)]), "traits"),
    "trait name over 40": (lambda p: p["traits"][0].update(name="n" * 41), "name"),
    "no use_today": (lambda p: p.update(use_today=[]), "use_today"),
    "headline over 140": (lambda p: p.update(headline="h" * 141), "headline"),
    "missing role": (lambda p: p.pop("role"), "role"),
    "unknown top field": (lambda p: p.update(nickname="x"), "nickname"),
    "bad odds kind": (lambda p: p.update(odds_beaten=[{"event": "e", "why_impossible": "w", "outcome": "o",
                                                       "outcome_kind": "triumph", "sources": [src(BRIT)]}]),
                      "outcome_kind"),
    "claim not an object": (lambda p: p.update(changes=["text"]), "changes #1"),
    "traits not a list": (lambda p: p.update(traits="x"), "traits"),
    "thinker with no core ideas": (lambda p: p.update(core_ideas=[]), "core_ideas"),
}


@pytest.mark.parametrize("name", BAD)
def test_bad_draft_writes_nothing_and_names_the_problem(dirs, name):
    fn, word = BAD[name]
    mutate(dirs, fn)
    snap = (dirs[0] / "chanakya.json").read_bytes()
    res = run(dirs)
    assert not res.ok and word in "\n".join(res.errors), res.errors
    assert (dirs[0] / "chanakya.json").read_bytes() == snap and not res.written
    assert "nothing was written" in people.format_report(res).lower()


def test_all_errors_are_reported_in_one_run(dirs):
    mutate(dirs, lambda p: (p["changes"][0].update(sources=[]), p["use_today"][0].update(sources=[src("ftp://x")])))
    assert len(run(dirs).errors) >= 2


@pytest.mark.parametrize("raw", ["", "null", "[]", '{"person": []}', '{"persona": {}}', '{"person": {}, "x": 1}'])
def test_wrong_top_level_shape(dirs, raw):
    put(dirs, raw=raw)
    assert not run(dirs).ok


def test_invalid_json_reports_line(dirs):
    put(dirs, raw='{"person": {\n "role": ,}}')
    assert "line 2" in "\n".join(run(dirs).errors)


def test_fences_and_bom_are_accepted(dirs):
    put(dirs, raw="﻿```json\n" + json.dumps(draft()) + "\n```")
    assert run(dirs).ok


def test_usage_errors(dirs, tmp_path):
    with pytest.raises(UsageError, match="chanakya.person.json"):
        run(dirs)
    put(dirs)
    with pytest.raises(UsageError, match="research file"):
        run(dirs, research=tmp_path / "nope.md")
    with pytest.raises(UsageError):
        people.import_person("ghost", dirs[0], dirs[1])
    t = stored(dirs)
    t.update(kind="topic", person=None)
    (dirs[0] / "chanakya.json").write_text(json.dumps(t), "utf-8")
    with pytest.raises(UsageError, match="only leader and thinker"):
        run(dirs)


def test_title_invalid_before_blocks(dirs):
    t = stored(dirs)
    t["lessons"][0]["image_ids"] = ["chanakya.i99"]
    (dirs[0] / "chanakya.json").write_text(json.dumps(t), "utf-8")
    put(dirs)
    assert not run(dirs).ok


# ---- research file ---------------------------------------------------------------------------------------------------

RESEARCH = f"""# People batch 1

## Chanakya
| claim | source URL | confidence |
|---|---|---|
| Planned for years | {BRIT} | high |
| Wrote on statecraft | [Arthashastra notes]({ARTH}) | medium |
| Taught at Taxila | {THIRD}. | Medium |
| Also | {WIKI} | low |
"""


def test_parse_research():
    m = people.parse_research(RESEARCH)
    assert m == {people.norm_url(BRIT): "high", people.norm_url(ARTH): "medium", people.norm_url(THIRD): "medium",
                 people.norm_url(WIKI): "low"}


def test_research_check_passes_when_urls_and_confidence_fit(dirs, tmp_path):
    f = tmp_path / "people-1.md"
    f.write_text(RESEARCH, "utf-8")
    d = draft()
    for g in ("traits", "changes", "core_ideas", "use_today"):
        for c in d["person"][g]:
            for s in c["sources"]:
                s["confidence"] = {"high": "medium"}.get(s["confidence"], s["confidence"]) if s["url"] == ARTH else s["confidence"]
                if s["url"] == WIKI:
                    s["confidence"] = "low"
                if s["url"] == THIRD:
                    s["confidence"] = "medium"
    put(dirs, d)
    res = run(dirs, research=f)
    assert res.ok, res.errors


def test_research_check_rejects_unknown_urls_and_inflated_confidence(dirs, tmp_path):
    f = tmp_path / "people-1.md"
    f.write_text(RESEARCH.replace(THIRD, "https://example.org/other"), "utf-8")
    put(dirs)  # ARTH is "high" in the draft but "medium" in the research; THIRD is missing from it
    res = run(dirs, research=f)
    msg = "\n".join(res.errors)
    assert not res.ok and "not in the research file" in msg and "higher than the research's medium" in msg
    assert not res.written


# ---- CLI + the whole flow -----------------------------------------------------------------------------------------------

def test_cli_people_then_report(dirs, capsys, tmp_path):
    put(dirs)
    base = ["--titles", str(dirs[0]), "--drafts", str(dirs[1])]
    assert cli.main(["people", "chanakya", *base, "--dry-run"]) == 0
    assert "dry run" in capsys.readouterr().out
    assert cli.main(["people", "chanakya", *base]) == 0
    assert "3 new citation source" in capsys.readouterr().out
    assert cli.main(["report", "chanakya", "--titles", str(dirs[0])]) == 0
    assert "G9" in capsys.readouterr().out, "the sample still carries SAMPLE markers, so the gate says so"
    mutate(dirs, lambda p: p["changes"][0].update(sources=[]))
    assert cli.main(["people", "chanakya", *base]) == 1
    assert cli.main(["people", "ghost", *base]) == 2


def test_cli_people_research_flag(dirs, capsys, tmp_path):
    put(dirs)
    f = tmp_path / "r.md"
    f.write_text("| a | https://example.org/x | high |\n", "utf-8")
    assert cli.main(["people", "chanakya", "--titles", str(dirs[0]), "--drafts", str(dirs[1]), "--research", str(f)]) == 1
    assert "not in the research file" in capsys.readouterr().out
