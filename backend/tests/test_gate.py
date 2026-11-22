"""Publish gate G1 to G10 (CONTRACTS 9.3, testing contract 10): a passing base, then one failing fixture per rule.
Also the importer: G1 on every file, the whole gate for `status: published`."""
import copy
import json

import pytest

from app.models import Title
from ingest import gate
from ingest.import_title import ImportRefused, import_title
from tests.conftest import SAMPLES
from tests.wiki_fake import fake_client, SEED
from ingest.build import build


@pytest.fixture
def topic(tmp_path):
    client, _ = fake_client(tmp_path)
    draft, _ = build(SEED, client, media_dir=tmp_path / "m", media_base_url="http://h/media")
    draft["quiz"] = [{"id": "test-empire.q001", "title_id": "test-empire", "lesson_id": "test-empire.l01",
                      "prompt": "When?", "options": ["1", "2", "3", "4"], "correct_index": 0,
                      "explanation": "Because.", "difficulty": "easy", "status": "reviewed", "review_note": None},
                     {"id": "test-empire.q002", "title_id": "test-empire", "lesson_id": None, "prompt": "Who?",
                      "options": ["a", "b", "c", "d"], "correct_index": 1, "explanation": "So.",
                      "difficulty": "medium", "status": "needs_check", "review_note": None}]
    draft["feed_facts"] = [{"id": "test-empire.f001", "title_id": "test-empire", "lesson_id": "test-empire.l01",
                            "text": "Roads ran for miles.", "image_id": None, "status": "needs_check",
                            "review_note": None}]
    assert gate.check(draft).ok, gate.check(draft).lines()
    return draft


@pytest.fixture
def person():
    """chanakya sample without SAMPLE markers, with properly cited claims: passes the gate."""
    d = json.loads((SAMPLES / "chanakya.json").read_text("utf-8").replace("SAMPLE", "Sample"))
    cites = [s for s in d["sources"] if s["role"] == "citation"]
    for s in cites:
        s["confidence"] = "high"
    ids = [s["id"] for s in cites[:2]]
    p = d["person"]
    for c in p["traits"] + p["changes"] + p["odds_beaten"] + p["core_ideas"] + p["use_today"]:
        c["source_ids"] = list(ids)
    assert gate.check(d).ok, gate.check(d).lines()
    return d


def fails(t, rule):
    rep = gate.check(t)
    assert rule in rep.rules(), rep.lines()
    return rep


def test_g1_schema(topic):
    topic["lessons"][0]["heading"] = ""
    fails(topic, "G1")


def test_g1_referential(topic):
    topic["lessons"][0]["source_ids"] = ["test-empire.s99"]
    fails(topic, "G1")
    t2 = copy.deepcopy(topic)
    t2["lessons"][0]["body"] += "\n\n### Too deep"
    fails(t2, "G1")


def test_g1_reading_minutes(topic):
    topic["lessons"][0]["reading_minutes"] += 3
    fails(topic, "G1")


def test_g2_no_lessons(topic):
    topic["lessons"] = []
    topic["quiz"] = [dict(q, lesson_id=None) for q in topic["quiz"]]
    topic["feed_facts"] = [dict(f, lesson_id=None) for f in topic["feed_facts"]]
    fails(topic, "G2")


def test_g2_lesson_too_short(topic):
    topic["lessons"][0]["body"] = "Only a few words here."
    topic["lessons"][0]["reading_minutes"] = 1
    rep = fails(topic, "G2")
    assert any("words" in m for _, m in rep.errors)


def test_g2_lesson_without_source(topic):
    topic["lessons"][0]["source_ids"] = []
    fails(topic, "G2")


@pytest.mark.parametrize("change", [
    {"credit_line": " "},
    {"license": "CC BY", "license_version": None},
    {"license": "CC BY-SA", "license_url": None},
    {"source_page_url": None},
    {"alt": "Ruins_today.jpg"},
    {"alt": "Ruins today"},
    {"author": " "},
])
def test_g3_image_credits(topic, change):
    topic["images"][0].update(change)
    if topic["images"][0]["alt"] == "Ruins today":
        topic["images"][0]["source_page_url"] = "https://commons.wikimedia.org/wiki/File:Ruins_today.jpg"
    rep = gate.check(topic)
    assert rep.rules() & {"G1", "G3"}, rep.lines()  # some of these are already schema errors


def test_g3_licence_not_allowed_is_caught_by_schema(topic):
    topic["images"][0]["license"] = "CC BY-NC"
    fails(topic, "G1")


def test_g4_topic_needs_text_source(topic):
    for s in topic["sources"]:
        s["role"], s["license"], s["confidence"] = "citation", None, "high"
    fails(topic, "G4")


def test_g4_text_source_needs_licence(topic):
    topic["sources"][0]["license"] = " "
    fails(topic, "G4")


def test_g5_reviewed_question_needs_distinct_options(topic):
    topic["quiz"][0]["options"] = ["1", "1 ", "3", "4"]
    fails(topic, "G5")


def test_g5_ignores_unreviewed_questions(topic):
    topic["quiz"][1]["options"] = ["x", "X", "y", "z"]
    assert gate.check(topic).ok


def test_g6_feed_fact_too_long(topic):
    topic["feed_facts"][0]["text"] = " ".join(["word"] * 41)
    assert gate.check(topic).rules() & {"G1", "G6"}  # the schema already enforces 40 words / 280 chars


def test_g6_rule_itself(topic, monkeypatch):
    """G6 still fires if the schema limits are ever loosened."""
    monkeypatch.setattr(gate, "g1_errors", lambda t: [])
    topic["feed_facts"][0]["text"] = " ".join(["word"] * 41)
    fails(topic, "G6")


def test_g7_claim_needs_two_citations(person):
    person["person"]["traits"][0]["source_ids"] = person["person"]["traits"][0]["source_ids"][:1]
    fails(person, "G7")


def test_g7_not_only_low_confidence(person):
    for s in person["sources"]:
        if s["role"] == "citation":
            s["confidence"] = "low"
    fails(person, "G7")


def test_g8_legend_note(person):
    person["person"]["legend_note"] = None
    fails(person, "G8")


def test_g9_sample_marker(topic):
    topic["lessons"][1]["heading"] = "SAMPLE heading"
    fails(topic, "G9")


def test_g10_counts_but_does_not_block(topic):
    rep = gate.check(topic)
    assert rep.ok and rep.needs_check == {"quiz": 1, "feed_facts": 1}
    assert any(l.startswith("G10 note: 1 quiz") for l in rep.lines())


# ---------- importer ----------

def test_import_refuses_invalid_file(topic, session_factory):
    topic["lessons"][0]["source_ids"] = ["test-empire.s99"]
    with session_factory() as db, pytest.raises(ImportRefused) as e:
        import_title(db, topic)
    assert any(p.startswith("G1") for p in e.value.problems)
    with session_factory() as db:
        assert db.get(Title, "test-empire") is None


def test_import_refuses_published_title_failing_gate(topic, session_factory):
    topic["status"] = "published"
    topic["feed_facts"][0]["text"] = " ".join(["word"] * 41)
    with session_factory() as db, pytest.raises(ImportRefused) as e:
        import_title(db, topic)
    assert any(p.startswith(("G1", "G6")) for p in e.value.problems)


def test_import_accepts_published_title_passing_gate(topic, session_factory):
    topic["status"] = "published"
    with session_factory() as db:
        assert import_title(db, topic) == "created"
        assert db.get(Title, "test-empire").status == "published"


def test_import_refuses_published_sample(session_factory):
    d = json.loads((SAMPLES / "roman-history.json").read_text("utf-8"))
    d["status"] = "published"
    with session_factory() as db, pytest.raises(ImportRefused) as e:
        import_title(db, d)
    assert any(p.startswith("G9") for p in e.value.problems)


def test_import_fills_contract_defaults(topic, session_factory):
    for k in ("subtitle", "period_start", "period_end", "poster_image_id", "linked_title_ids", "rank"):
        topic.pop(k)
    with session_factory() as db:
        import_title(db, topic)
        t = db.get(Title, "test-empire")
        assert (t.rank, t.linked_title_ids, t.subtitle, t.period_start) == (999, [], None, None)


def test_draft_import_then_api_serves_it(topic, session_factory, monkeypatch):
    from fastapi.testclient import TestClient
    from app import main
    from app.config import settings
    from app.db import get_db
    from tests.conftest import schema_errors
    with session_factory() as db:
        import_title(db, topic)
    monkeypatch.setattr(settings, "serve_drafts", True)

    def _db():
        with session_factory() as db:
            yield db

    main.app.dependency_overrides[get_db] = _db
    main.limiter.reset()
    try:
        with TestClient(main.app) as c:
            r = c.get("/v1/titles/test-empire")
            assert r.status_code == 200
            assert schema_errors(r.json(), "title.schema.json") == []
            cr = c.get("/v1/credits").json()
            assert any(i["title_id"] == "test-empire" and "Wikimedia Commons" in i["credit_line"]
                       for i in cr["images"])
    finally:
        main.app.dependency_overrides.clear()


# ---------- the committed real titles (S11 drafts) ----------

TITLE_FILES = sorted((SAMPLES.parent / "titles").glob("*.json"))


@pytest.mark.parametrize("path", TITLE_FILES, ids=[p.stem for p in TITLE_FILES])
def test_committed_titles_pass_the_gate(path):
    t = json.loads(path.read_text("utf-8"))
    rep = gate.check(t)
    assert rep.ok, rep.lines()
    assert t["status"] == "draft"  # the owner moves it to reviewed; the ingest never does
    for i in t["images"]:
        assert i["license"] in {"PD", "CC0", "CC BY", "CC BY-SA"} and "Wikimedia Commons" in i["credit_line"]
        assert i["source_page_url"].startswith("https://commons.wikimedia.org/wiki/File:")


def test_committed_titles_import_and_reimport_unchanged(session_factory):
    with session_factory() as db:
        for p in TITLE_FILES:
            assert import_title(db, json.loads(p.read_text("utf-8"))) == "created"
        for p in TITLE_FILES:
            assert import_title(db, json.loads(p.read_text("utf-8"))) == "unchanged"
