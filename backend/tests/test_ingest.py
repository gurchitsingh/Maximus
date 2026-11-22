"""S11 ingest: text cleaning, splitting, licences, Wikidata, the polite client, the draft builder and the CLI.
All Wikimedia traffic goes to tests/wiki_fake.py (httpx.MockTransport); conftest blocks real network."""
import copy
import re
import json

import httpx
import pytest

from app.config import BACKEND_DIR, settings
from ingest import commons, gate, wikidata, wikipedia
from ingest.build import SeedError, brief_from, build
from ingest.client import FetchError, WikiClient, user_agent
from ingest.split import MAX_WORDS, MIN_WORDS, body, chunk, plan_lessons, trim, words
from tests.conftest import schema_errors
from tests.wiki_fake import COMMONS, SEED, FakeWiki, fake_client, para


def build_fake(tmp_path, seed=SEED, **kw):
    client, fake = fake_client(tmp_path)
    kw.setdefault("media_dir", tmp_path / "media")
    kw.setdefault("media_base_url", "http://10.0.2.2:8000/media")
    draft, report = build(seed, client, **kw)
    return draft, report, client, fake


# ---------- text cleaning ----------

@pytest.mark.parametrize("raw, want", [
    ("Rome (Latin: Roma [ˈroːma]) was a city.[1]", "Rome was a city."),
    ("It grew ( ; ) quickly and (, ) widely.", "It grew quickly and widely."),
    ("Caesar (/ˈsiːzər/ SEE-zər) crossed the river.", "Caesar crossed the river."),
    ("He won.[citation needed] Then he lost.[a]", "He won. Then he lost."),
    ("- A sentence that looks like a bullet item.", "A sentence that looks like a bullet item."),
    ("# Not a heading but a sentence here.", "Not a heading but a sentence here."),
    ("Values <b>bold</b> and *stars* go.", "Values < b>bold< /b> and stars go."),
    ("Sputnik 1 (/ˈspʊtnɪk/; Russian: Спутник-1) was the first satellite.", "Sputnik 1 was the first satellite."),
    ("Sputnik 1 (, Russian: Спутник-1, Satellite 1) was the first satellite.", "Sputnik 1 was the first satellite."),
    ("The Directory (also called Directorate; French: le Directoire [diʁɛktwaʁ] ) ruled France.",
     "The Directory (also called Directorate; French: le Directoire) ruled France."),
    ("As of 2023[update] the station is still in orbit.", "As of 2023 the station is still in orbit."),
    ("Short list item", None),
    ("Two words.", None),
])
def test_clean_paragraph(raw, want):
    assert wikipedia.clean_paragraph(raw) == want


def test_cleaned_text_stays_in_markdown_subset():
    for raw in ["<div>x</div> is a tag in a long sentence here.", "| a | table | row that is long enough |.",
                "```code``` fence in a long enough sentence.", "See [x](http://example.org) for a long sentence."]:
        out = wikipedia.clean_paragraph(raw)
        assert out is None or not gate.BAD_LINE.search(out), out


def test_parse_extract_drops_boilerplate_and_keeps_level3():
    from tests.wiki_fake import EXTRACT
    secs = wikipedia.parse_extract(EXTRACT)
    assert [s["heading"] for s in secs] == [None, "History", "Legacy"]
    hist = secs[1]["items"]
    assert ("sub", "Rise") in hist and ("sub", "Fall") in hist
    assert all(t != "Detail" for _, t in hist)  # level 4 headings dropped, text kept
    assert "Short list item" not in [t for _, t in secs[0]["items"]]


def test_images_by_section_ignores_navboxes_and_reads_captions():
    from tests.wiki_fake import HTML
    imgs = {i["file"]: i for i in wikipedia.images_by_section(HTML)}
    assert "Navbox thing.jpg" not in imgs
    assert imgs["Good painting.jpg"]["section"] is None
    assert imgs["Good painting.jpg"]["caption"] == "A painting of the first emperor in his robes."
    assert imgs["Map of test.png"]["section"] == "History"
    assert imgs["Map of test.png"]["caption"] == "Map of the empire at its height."
    assert imgs["Ruins today.jpg"]["section"] == "Legacy"


# ---------- splitting ----------

def test_long_section_splits_within_range_and_never_mid_paragraph():
    items = [("p", para(150, f"w{n}")) for n in range(8)]  # 1200 words
    parts = chunk(items)
    assert len(parts) >= 2
    for p in parts:
        n = sum(words(t) for _, t in p)
        assert MIN_WORDS <= n <= MAX_WORDS
    assert [it for p in parts for it in p] == items  # nothing lost, order kept


def test_split_prefers_subheading_boundaries():
    items = [("p", para(320, "a")), ("sub", "Part two"), ("p", para(320, "b"))]
    parts = chunk(items)
    assert parts[1][0] == ("sub", "Part two")


def test_short_picks_merge_with_subheading():
    picks = [{"heading": "One", "items": [("p", para(120, "a"))], "source_id": "t.s01", "images": []},
             {"heading": "Two", "items": [("p", para(150, "b"))], "source_id": "t.s02", "images": ["x.jpg"]}]
    out = plan_lessons(picks)
    assert len(out) == 1
    assert out[0]["items"][1] == ("sub", "Two")
    assert out[0]["source_ids"] == ["t.s01", "t.s02"] and out[0]["image_ids"] == ["x.jpg"]


def test_trim_whole_paragraphs_then_whole_sentences():
    items = [("p", para(200, "a")), ("sub", "S"), ("p", para(200, "b")), ("p", para(200, "c"))]
    assert trim(items, 420) == items[:3]                         # 20 words left: not worth a fragment
    out = trim(items, 451)                                         # the sub-heading counts as 1 word
    assert out[:3] == items[:3] and out[3] == ("p", para(50, "c"))  # 50 words = 5 whole sentences
    assert trim([("p", para(900, "a"))], 100) == [("p", para(100, "a"))]
    assert trim([("p", "One very long sentence " + "x " * 80 + "end.")], 10)[0][1].endswith("end.")
    assert trim([("sub", "S"), ("p", para(30, "a"))], 10) == [("sub", "S"), ("p", para(10, "a"))]


def test_seed_entry_with_sections_is_one_lesson(tmp_path):
    seed = {**SEED, "pages": [{"page": "Test Empire", "heading": "Rise and legacy",
                               "sections": ["lead", {"name": "Legacy", "max_words": 50}]}]}
    draft, *_ = build_fake(tmp_path, seed=seed)
    assert len(draft["lessons"]) == 1
    les = draft["lessons"][0]
    assert les["heading"] == "Rise and legacy" and "\n\n## Legacy\n\n" in les["body"]
    assert words(les["body"].split("## Legacy", 1)[1]) == 50


def test_wikidata_failure_is_not_fatal(tmp_path):
    fake = FakeWiki()

    def lagging(request):
        if request.url.host == "www.wikidata.org":
            return httpx.Response(200, json={"error": {"code": "maxlag", "info": "lag"}})
        return fake(request)

    client = WikiClient(transport=httpx.MockTransport(lagging), cache_dir=None, delay=0, sleep=lambda s: None)
    draft, report = build({**SEED, "period_start": -27, "period_end": 476}, client, media_dir=tmp_path / "m",
                          media_base_url="http://h/media", download=False)
    assert any("Wikidata Q1 unavailable" in w and "maxlag" in w for w in report["warnings"])
    assert draft["period_start"] == -27 and gate.check(draft).ok


def test_body_places_inline_images_between_paragraphs():
    items = [("p", para(20, "a")), ("sub", "Sub"), ("p", para(20, "b")), ("p", para(20, "c"))]
    text = body(items, ["t.i02"])
    lines = text.split("\n\n")
    assert "![](t.i02)" in lines and lines[-1] != "![](t.i02)"
    assert not lines[lines.index("![](t.i02)") - 1].startswith("## ")  # placed after a paragraph
    assert "## Sub" in lines
    assert body([("p", para(20, "a"))], ["t.i02"]) == para(20, "a")  # no slot: shown after the text by the app


def test_brief_from_lead():
    assert brief_from("One short sentence. Two short sentence.") == "One short sentence. Two short sentence."
    long = "A " + "very " * 60 + "long sentence."
    b = brief_from(long)
    assert len(b) <= 200 and b.endswith("…")


# ---------- licences ----------

@pytest.mark.parametrize("code, short, url, want", [
    ("cc-by-sa-4.0", "CC BY-SA 4.0", "https://creativecommons.org/licenses/by-sa/4.0",
     ("CC BY-SA", "4.0", "https://creativecommons.org/licenses/by-sa/4.0", "CC BY-SA 4.0")),
    ("cc-by-3.0-de", "CC BY 3.0 de", None,
     ("CC BY", "3.0", "https://creativecommons.org/licenses/by/3.0/de/", "CC BY 3.0 DE")),
    ("cc-by-2.0", "CC BY 2.0", "//creativecommons.org/licenses/by/2.0/",
     ("CC BY", "2.0", "https://creativecommons.org/licenses/by/2.0/", "CC BY 2.0")),
    ("cc0", "CC0", None, ("CC0", None, "https://creativecommons.org/publicdomain/zero/1.0/", "CC0")),
    ("pd", "Public domain", None, ("PD", None, None, "Public domain")),
    ("pd-old-100", "Public domain", None, ("PD", None, None, "Public domain")),
    ("", "Public domain", None, ("PD", None, None, "Public domain")),
])
def test_allowed_licences(code, short, url, want):
    m = {"License": {"value": code}, "LicenseShortName": {"value": short}}
    if url:
        m["LicenseUrl"] = {"value": url}
    lic, why = commons.licence(m)
    assert why is None
    assert (lic["license"], lic["license_version"], lic["license_url"], lic["display"]) == want


@pytest.mark.parametrize("m", [
    {"License": {"value": "cc-by-nc-4.0"}, "LicenseShortName": {"value": "CC BY-NC 4.0"}},
    {"License": {"value": "cc-by-nd-4.0"}, "LicenseShortName": {"value": "CC BY-ND 4.0"}},
    {"License": {"value": "gfdl"}, "LicenseShortName": {"value": "GFDL"}},
    {"License": {"value": "fal"}, "LicenseShortName": {"value": "FAL"}},
    {"License": {"value": "cc-by-sa-4.0"}, "LicenseShortName": {"value": "CC BY 2.0"}},  # fields disagree
    {"License": {"value": "pd"}, "LicenseShortName": {"value": "Public domain"}, "NonFree": {"value": "true"}},
    {"License": {"value": "cc0"}, "LicenseShortName": {"value": "CC0"}, "Restrictions": {"value": "trademarked"}},
    {},
])
def test_rejected_licences(m):
    lic, why = commons.licence(m)
    assert lic is None and why


def test_author_cleanup():
    assert commons.author({"Artist": {"value": "<span>Unknown author</span><span>Unknown author</span>"}}) ==         "Unknown author"
    assert commons.author({"Artist": {"value": "NSSDC, NASA[1]"}}) == "NSSDC, NASA"


def test_alt_text_must_be_readable_english():
    assert commons.alt_text("Советский космонавт Юрий Гагарин.") is None
    assert commons.alt_text("Musée de la Révolution française, Vizille") is not None
    assert commons.alt_text("Station elements as of 2023[update] in orbit") == "Station elements as of 2023 in orbit"


def test_author_strips_html_and_prefers_attribution():
    m = {"Artist": {"value": '<a href="//x">Jane &amp; Co</a>'}, "Attribution": {"value": "Photo: <b>Joe</b>"}}
    assert commons.author(m) == "Photo: Joe"
    assert commons.author({"Artist": {"value": '<span>Jane &amp; Co</span>'}}) == "Jane & Co"


@pytest.mark.parametrize("text, ok", [
    ("Colosseo 2020", False), ("Colosseo_2020.jpg", False), ("Retrieved from http://x.org/a", False),
    ("Own work", False), ("Word", False), ("The Colosseum at dusk.", True), ("A " + "long " * 80, True),
])
def test_alt_text(text, ok):
    out = commons.alt_text(text, "Colosseo 2020.jpg")
    assert (out is not None) == ok
    if out:
        assert len(out) <= 200


def test_name_filter():
    assert commons.name_ok("Flag of Italy.svg")
    assert commons.name_ok("Apollo 11 insignia.png")
    assert commons.name_ok("Clip.ogv")
    assert commons.name_ok("Roman Forum at night.jpg") is None


# ---------- Wikidata ----------

@pytest.mark.parametrize("time, precision, want", [
    ("-0753-04-21T00:00:00Z", 11, -753), ("+1789-05-05T00:00:00Z", 11, 1789), ("+0476-00-00T00:00:00Z", 9, 476),
    ("+1800-00-00T00:00:00Z", 7, None), ("+0000-00-00T00:00:00Z", 9, None), ("bad", 11, None),
])
def test_wikidata_year(time, precision, want):
    assert wikidata.year_of({"time": time, "precision": precision}) == want


def test_period_label():
    assert wikidata.period_label(-753, 476) == "753 BCE to 476 CE"
    assert wikidata.period_label(1789, 1799) == "1789 to 1799"
    assert wikidata.period_label(-800, -146) == "800 BCE to 146 BCE"
    assert wikidata.period_label(1944, None) == "From 1944"
    assert wikidata.period_label(None, None) is None


# ---------- client etiquette ----------

def test_client_sends_user_agent_and_maxlag_and_caches(tmp_path):
    client, fake = fake_client(tmp_path)
    client.get_json(wikipedia.API, {"action": "query", "titles": "Small War"}, action_api=True)
    client.get_json(wikipedia.API, {"action": "query", "titles": "Small War"}, action_api=True)
    assert len(fake.requests) == 1 and client.requests == 1  # second answer from the disk cache
    r = fake.requests[0]
    assert r.headers["user-agent"] == user_agent()
    assert "github.com" in r.headers["user-agent"] and "@" not in r.headers["user-agent"]
    assert r.url.params["maxlag"] == "5" and r.url.params["format"] == "json"


def test_client_paces_requests(tmp_path):
    now, waits = [100.0], []

    def sleep(s):
        waits.append(s)
        now[0] += s

    client = WikiClient(transport=httpx.MockTransport(FakeWiki()), cache_dir=None, delay=1.0, sleep=sleep,
                        clock=lambda: now[0])
    for t in ("Small War", "Test Empire", "Small War"):
        client.get_json(wikipedia.API, {"action": "query", "titles": t}, action_api=True)
    assert waits == [1.0, 1.0]


def test_client_retries_429_after_retry_after_then_succeeds(tmp_path):
    calls, waits = [], []

    def handler(request):
        calls.append(request)
        if len(calls) < 3:
            return httpx.Response(429, headers={"retry-after": "7"})
        return httpx.Response(200, json={"ok": True})

    client = WikiClient(transport=httpx.MockTransport(handler), cache_dir=None, delay=0, sleep=waits.append)
    assert client.get_json("https://en.wikipedia.org/w/api.php") == {"ok": True}
    assert waits == [7.0, 7.0]


def test_client_retries_maxlag_and_gives_up(tmp_path):
    waits = []

    def handler(request):
        return httpx.Response(200, json={"error": {"code": "maxlag", "info": "lagged"}},
                              headers={"retry-after": "5"})

    client = WikiClient(transport=httpx.MockTransport(handler), cache_dir=None, delay=0, sleep=waits.append,
                        max_tries=3)
    with pytest.raises(FetchError):
        client.get_json("https://en.wikipedia.org/w/api.php", action_api=True)
    assert waits == [5.0, 5.0]


def test_client_caps_retry_wait_and_raises_api_errors(tmp_path):
    waits = []
    seq = iter([httpx.Response(503, headers={"retry-after": "9999"}),
                httpx.Response(200, json={"error": {"code": "badvalue", "info": "nope"}})])
    client = WikiClient(transport=httpx.MockTransport(lambda r: next(seq)), cache_dir=None, delay=0,
                        sleep=waits.append, max_wait=60)
    with pytest.raises(FetchError, match="badvalue"):
        client.get_json("https://en.wikipedia.org/w/api.php", action_api=True)
    assert waits == [60]


def test_client_404_is_an_error(tmp_path):
    client = WikiClient(transport=httpx.MockTransport(lambda r: httpx.Response(404)), cache_dir=None, delay=0)
    with pytest.raises(FetchError, match="404"):
        client.get_json("https://en.wikipedia.org/w/api.php")


# ---------- draft builder ----------

def test_draft_passes_import_schema_and_gate(tmp_path):
    draft, report, client, fake = build_fake(tmp_path)
    assert schema_errors(draft, "title-import.schema.json") == []
    rep = gate.check(draft)
    assert rep.ok, rep.lines()
    assert draft["status"] == "draft" and draft["quiz"] == [] and draft["feed_facts"] == []
    assert [l["index"] for l in draft["lessons"]] == list(range(1, len(draft["lessons"]) + 1))
    for l in draft["lessons"]:
        assert 80 <= words(l["body"]) <= 700
    # all Wikimedia calls identified themselves
    assert fake.requests and all(r.headers["user-agent"] == user_agent() for r in fake.requests)


def test_draft_images_only_allowed_licences_with_credits(tmp_path):
    draft, report, *_ = build_fake(tmp_path)
    by_page = {i["source_page_url"].rsplit("File:", 1)[1].replace("_", " "): i for i in draft["images"]}
    assert set(by_page) == {"Hero pic.jpg", "Good painting.jpg", "Map of test.png", "Battle scene.jpg",
                            "Ruins today.jpg"}
    rejected = {r["file"]: r["reason"] for r in report["rejected"]}
    assert set(rejected) == {"Flag of Test.svg", "NC photo.jpg", "Local only.jpg", "Tiny.jpg", "No author.jpg"}
    assert "not on Wikimedia Commons" in rejected["Local only.jpg"]
    m = by_page["Map of test.png"]
    assert (m["license"], m["license_version"], m["license_url"]) == \
        ("CC BY-SA", "4.0", "https://creativecommons.org/licenses/by-sa/4.0")
    assert m["credit_line"] == "Map Maker · CC BY-SA 4.0 · Wikimedia Commons" and m["modified"] is False
    assert m["kind"] == "map" and m["url"].startswith("http://10.0.2.2:8000/media/test-empire/")
    hero = by_page["Hero pic.jpg"]
    assert hero["id"] == draft["hero_image_id"]  # Wikidata P18
    assert hero["credit_line"] == "Unknown author · Public domain · Wikimedia Commons · resized"
    assert hero["modified"] is True and hero["width"] == 1600 and hero["height"] == 1200
    assert by_page["Good painting.jpg"]["alt"] == "A painting of the first emperor in his robes."


def test_images_are_copied_to_media(tmp_path):
    draft, *_ = build_fake(tmp_path)
    names = set()
    for i in draft["images"]:
        name = i["url"].rsplit("/", 1)[1]
        # id + hash of the source URL: a different picture can never hide behind an old file name
        assert re.fullmatch(r"i\d\d-[0-9a-f]{10}\.(jpg|png)", name), name
        f = tmp_path / "media" / "test-empire" / name
        assert f.is_file() and f.stat().st_size > 0
        names.add(name)
    assert len(names) == len(draft["images"])


def test_no_download_writes_no_files(tmp_path):
    build_fake(tmp_path, download=False)
    assert not (tmp_path / "media").exists()


def test_draft_text_sources_and_wikidata_period(tmp_path):
    draft, report, *_ = build_fake(tmp_path)
    assert draft["sources"] == [
        {"id": "test-empire.s01", "title": "Test Empire (Wikipedia)", "url": "https://en.wikipedia.org/wiki/Test_Empire",
         "publisher": "Wikipedia", "role": "text", "license": "CC BY-SA 4.0", "confidence": None},
        {"id": "test-empire.s02", "title": "Small War (Wikipedia)", "url": "https://en.wikipedia.org/wiki/Small_War",
         "publisher": "Wikipedia", "role": "text", "license": "CC BY-SA 4.0", "confidence": None}]
    assert (draft["period_start"], draft["period_end"], draft["subtitle"]) == (-27, 476, "27 BCE to 476 CE")
    assert draft["brief"].startswith("The Test Empire was a large state")
    assert draft["lessons"][0]["heading"] == "The empire in brief"
    assert report["wikidata"]["start_prop"] == "P580"


def test_seed_values_win_over_wikidata_and_differences_are_reported(tmp_path):
    seed = {**SEED, "period_start": -30, "period_end": 476, "subtitle": "Seed subtitle", "brief": "Seed brief."}
    draft, report, *_ = build_fake(tmp_path, seed=seed)
    assert (draft["period_start"], draft["subtitle"], draft["brief"]) == (-30, "Seed subtitle", "Seed brief.")
    assert any("period_start" in w for w in report["warnings"])


def test_rerun_is_cached_and_stable(tmp_path):
    client, fake = fake_client(tmp_path)
    kw = dict(media_dir=tmp_path / "media", media_base_url="http://h/media")
    a, _ = build(SEED, client, **kw)
    n = len(fake.requests)
    b, _ = build(SEED, client, existing=a, **kw)
    assert len(fake.requests) == n  # cache + files on disk: no new requests
    assert a == b


def test_rebuild_keeps_quiz_feed_citations_and_ids(tmp_path):
    draft, *_ = build_fake(tmp_path)
    old = copy.deepcopy(draft)
    l1 = old["lessons"][0]["id"]
    old["quiz"] = [{"id": "test-empire.q001", "title_id": "test-empire", "lesson_id": l1, "prompt": "Q?",
                    "options": ["a", "b", "c", "d"], "correct_index": 0, "explanation": "Because.",
                    "difficulty": "easy", "status": "reviewed", "review_note": None}]
    old["feed_facts"] = [{"id": "test-empire.f001", "title_id": "test-empire", "lesson_id": l1,
                          "text": "A fact.", "image_id": None, "status": "needs_check", "review_note": None}]
    old["sources"].insert(0, {"id": "test-empire.s01", "title": "A book", "url": "https://example.org/book",
                              "publisher": None, "role": "citation", "license": None, "confidence": "high"})
    # the text source that had s01 now must move: simulate an older file where text sources were s02, s03
    old["sources"][1]["id"], old["sources"][2]["id"] = "test-empire.s02", "test-empire.s03"
    old["images"][0]["id"] = "test-empire.i09"
    old["hero_image_id"] = "test-empire.i09"
    for l in old["lessons"]:
        l["image_ids"] = ["test-empire.i09" if i == draft["images"][0]["id"] else i for i in l["image_ids"]]
    new, report, *_ = build_fake(tmp_path / "again", existing=old)
    assert new["quiz"] == old["quiz"] and new["feed_facts"] == old["feed_facts"]
    ids = {s["url"]: s["id"] for s in new["sources"]}
    assert ids["https://example.org/book"] == "test-empire.s01"
    assert ids["https://en.wikipedia.org/wiki/Test_Empire"] == "test-empire.s02"
    assert new["hero_image_id"] == "test-empire.i09"  # image id reused by its Commons page
    assert gate.check(new).ok and report["warnings"] == []


def test_rebuild_warns_about_quiz_pointing_at_missing_lessons(tmp_path):
    draft, *_ = build_fake(tmp_path)
    draft["quiz"] = [{"id": "test-empire.q001", "title_id": "test-empire", "lesson_id": "test-empire.l09",
                      "prompt": "Q?", "options": ["a", "b", "c", "d"], "correct_index": 0, "explanation": "E.",
                      "difficulty": "easy", "status": "needs_check", "review_note": None}]
    new, report, *_ = build_fake(tmp_path / "again", existing=draft)
    assert any("no longer exist" in w for w in report["warnings"])
    assert "G1" in gate.check(new).rules()


def test_unknown_section_and_page_errors(tmp_path):
    with pytest.raises(SeedError, match="has: lead, History, Legacy"):
        build_fake(tmp_path, seed={**SEED, "pages": [{"page": "Test Empire", "sections": ["Economy"]}]})
    with pytest.raises(LookupError, match="not found"):
        build_fake(tmp_path, seed={**SEED, "pages": [{"page": "Nope"}]})


def test_people_titles_need_a_person_block_first(tmp_path):
    with pytest.raises(SeedError, match="person block"):
        build_fake(tmp_path, seed={**SEED, "kind": "leader", "group": "leaders-rome"})


# ---------- CLI ----------

@pytest.fixture
def cli_env(tmp_path, monkeypatch):
    from ingest import cli
    seed_file = tmp_path / "seed.json"
    seed_file.write_text(json.dumps({"titles": [SEED]}), "utf-8")
    monkeypatch.setattr(settings, "media_dir", str(tmp_path / "media"))
    monkeypatch.setattr(cli, "make_client", lambda args: fake_client(tmp_path)[0])
    monkeypatch.setattr(cli, "TITLES_DIR", tmp_path / "titles")
    return cli, seed_file, tmp_path


def test_cli_wiki_writes_a_draft_then_check_and_import(cli_env, capsys, session_factory, monkeypatch):
    cli, seed_file, tmp = cli_env
    out = tmp / "titles"
    assert cli.main(["wiki", "test-empire", "--seed", str(seed_file), "--out", str(out)]) == 0
    text = capsys.readouterr().out
    assert "gate: PASS" in text and "NC photo.jpg: licence not allowed" in text
    draft = json.loads((out / "test-empire.json").read_text("utf-8"))
    assert draft["status"] == "draft"
    assert cli.main(["check", "test-empire"]) == 0
    monkeypatch.setattr("ingest.cli.SessionLocal", session_factory)
    assert cli.main(["import", str(out / "test-empire.json")]) == 0
    assert "test-empire.json: created" in capsys.readouterr().out


def test_cli_wiki_refuses_to_overwrite_published_without_force(cli_env, capsys):
    cli, seed_file, tmp = cli_env
    out = tmp / "titles"
    cli.main(["wiki", "test-empire", "--seed", str(seed_file), "--out", str(out)])
    d = json.loads((out / "test-empire.json").read_text("utf-8"))
    d["status"] = "published"
    (out / "test-empire.json").write_text(json.dumps(d), "utf-8")
    capsys.readouterr()
    assert cli.main(["wiki", "test-empire", "--seed", str(seed_file), "--out", str(out)]) == 1
    assert "Use --force" in capsys.readouterr().out
    assert cli.main(["wiki", "test-empire", "--seed", str(seed_file), "--out", str(out), "--force"]) == 0
    assert json.loads((out / "test-empire.json").read_text("utf-8"))["status"] == "draft"


def test_cli_wiki_unknown_id(cli_env, capsys):
    cli, seed_file, _ = cli_env
    assert cli.main(["wiki", "nope", "--seed", str(seed_file)]) == 2


def test_cli_check_fails_on_samples(capsys):
    from ingest import cli
    assert cli.main(["check", str(BACKEND_DIR / "data" / "samples" / "roman-history.json")]) == 1
    assert "G9 contains the SAMPLE marker" in capsys.readouterr().out


def test_cli_delay_never_below_half_a_second():
    from argparse import Namespace
    from ingest import cli
    c = cli.make_client(Namespace(delay=0.0, refresh=False))
    assert c.delay == 0.5
    c.close()

