"""S13 merge tool (CONTRACTS 9.2 step 5): Gemini drafts -> needs_check items in data/titles/<id>.json.
Fake drafts only, no network. Base title = the roman-history sample (stable lesson ids, 10 quiz, 8 feed)."""
import copy
import json
from pathlib import Path

import pytest

from ingest import cli, gate, merge
from tests.conftest import SAMPLES


def q(n=1, **over):
    item = {"lesson_id": "roman-history.l01", "prompt": f"Fake question number {n}?",
            "options": [f"a{n}", f"b{n}", f"c{n}", f"d{n}"], "correct_index": n % 4,
            "explanation": f"Because of fake reason {n}.", "difficulty": ["easy", "medium", "hard"][n % 3]}
    item.update(over)
    return item


def f(n=1, **over):
    item = {"lesson_id": "roman-history.l02", "text": f"Fake surprising fact number {n}.", "image_id": None}
    item.update(over)
    return item


@pytest.fixture
def base():
    """Sample title with a gap in the ids (q020, f015 exist), one reviewed item of each kind and a review note."""
    t = json.loads((SAMPLES / "roman-history.json").read_text("utf-8"))
    t["quiz"][0].update(status="reviewed", review_note="checked against l01")
    t["feed_facts"][0].update(status="reviewed")
    t["quiz"][-1]["id"] = "roman-history.q020"
    t["feed_facts"][-1]["id"] = "roman-history.f015"
    return t


@pytest.fixture
def dirs(tmp_path, base):
    titles, drafts = tmp_path / "titles", tmp_path / "drafts"
    titles.mkdir()
    drafts.mkdir()
    (titles / "roman-history.json").write_text(json.dumps(base, ensure_ascii=False, indent=2), "utf-8")
    return titles, drafts


def put(drafts: Path, kind: str, items, key=None, raw=None):
    path = drafts / f"roman-history.{kind}.json"
    key = key or {"quiz": "quiz", "feed": "feed_facts"}[kind]
    path.write_text(raw if raw is not None else json.dumps({key: items}), "utf-8")
    return path


def run(dirs, **kw):
    titles, drafts = dirs
    return merge.merge_title("roman-history", titles, drafts, **kw)


def stored(dirs):
    return json.loads((dirs[0] / "roman-history.json").read_text("utf-8"))


# ---- happy path -----------------------------------------------------------------------------------------------

def test_merge_assigns_next_free_ids_and_needs_check(dirs, base):
    put(dirs[1], "quiz", [q(1), q(2), q(3)])
    put(dirs[1], "feed", [f(1), f(2)])
    res = run(dirs)
    assert res.ok and (len(res.quiz_added), len(res.feed_added)) == (3, 2)
    t = stored(dirs)
    assert [x["id"] for x in t["quiz"][-3:]] == ["roman-history.q021", "roman-history.q022", "roman-history.q023"]
    assert [x["id"] for x in t["feed_facts"][-2:]] == ["roman-history.f016", "roman-history.f017"]
    for x in t["quiz"][-3:] + t["feed_facts"][-2:]:
        assert x["status"] == "needs_check" and x["review_note"] is None and x["title_id"] == "roman-history"
    assert gate.g1_errors(t) == []


def test_existing_items_are_untouched_and_keep_order(dirs, base):
    put(dirs[1], "quiz", [q(1)])
    put(dirs[1], "feed", [f(1)])
    run(dirs)
    t = stored(dirs)
    assert t["quiz"][:len(base["quiz"])] == base["quiz"]
    assert t["feed_facts"][:len(base["feed_facts"])] == base["feed_facts"]
    assert t["quiz"][0]["status"] == "reviewed" and t["quiz"][0]["review_note"] == "checked against l01"
    rest = {k: v for k, v in t.items() if k not in ("quiz", "feed_facts")}
    assert rest == {k: v for k, v in base.items() if k not in ("quiz", "feed_facts")}


def test_only_quiz_or_only_feed_draft_is_fine(dirs, base):
    put(dirs[1], "feed", [f(1)])
    res = run(dirs)
    assert res.ok and not res.quiz_added and len(res.feed_added) == 1
    assert stored(dirs)["quiz"] == base["quiz"]


def test_second_run_is_a_no_op(dirs):
    put(dirs[1], "quiz", [q(1), q(2)])
    put(dirs[1], "feed", [f(1)])
    run(dirs)
    first = (dirs[0] / "roman-history.json").read_bytes()
    res = run(dirs)
    assert res.ok and not res.quiz_added and not res.feed_added and len(res.skipped) == 3
    assert (dirs[0] / "roman-history.json").read_bytes() == first


def test_duplicate_of_an_existing_item_is_skipped_not_added(dirs, base):
    existing = base["quiz"][0]["prompt"]
    put(dirs[1], "quiz", [q(1, prompt="  " + existing.upper()), q(2)])
    res = run(dirs)
    assert res.ok and len(res.quiz_added) == 1
    assert any("duplicate" in s and "roman-history.q001" in s for s in res.skipped)


def test_duplicate_inside_the_draft_is_skipped(dirs):
    put(dirs[1], "feed", [f(1), f(1)])
    res = run(dirs)
    assert res.ok and len(res.feed_added) == 1 and len(res.skipped) == 1


def test_strings_are_trimmed(dirs):
    put(dirs[1], "quiz", [q(1, prompt="  Padded?  ", options=[" a ", "b", "c", "d"])])
    run(dirs)
    added = stored(dirs)["quiz"][-1]
    assert added["prompt"] == "Padded?" and added["options"][0] == "a"


def test_output_format_matches_other_tools(dirs):
    put(dirs[1], "quiz", [q(1, prompt="Café — Rómulo?")])
    run(dirs)
    raw = (dirs[0] / "roman-history.json").read_bytes()
    assert raw.endswith(b"\n") and b"\r" not in raw and "Café — Rómulo?".encode() in raw


def test_drafts_are_left_in_place_and_utf8_bom_and_fences_accepted(dirs):
    p = put(dirs[1], "quiz", None, raw="﻿```json\n" + json.dumps({"quiz": [q(1)]}) + "\n```\n")
    res = run(dirs)
    assert res.ok and len(res.quiz_added) == 1 and p.exists()


def test_dry_run_writes_nothing_but_reports(dirs):
    put(dirs[1], "quiz", [q(1)])
    before = (dirs[0] / "roman-history.json").read_bytes()
    res = run(dirs, dry_run=True)
    assert res.ok and len(res.quiz_added) == 1 and res.written is False
    assert (dirs[0] / "roman-history.json").read_bytes() == before


# ---- item errors (all-or-nothing by default) -------------------------------------------------------------------

BAD_QUIZ = {
    "unknown lesson": (q(1, lesson_id="roman-history.l99"), "lesson_id"),
    "other title's lesson": (q(1, lesson_id="french-revolution.l01"), "lesson_id"),
    "null lesson": (q(1, lesson_id=None), "lesson_id"),
    "3 options": (q(1, options=["a", "b", "c"]), "options"),
    "5 options": (q(1, options=list("abcde")), "options"),
    "repeated options": (q(1, options=["a", "b", "b", "d"]), "options"),
    "repeated options by case": (q(1, options=["Rome", "rome ", "c", "d"]), "options"),
    "blank option": (q(1, options=["a", "  ", "c", "d"]), "options"),
    "option over 80": (q(1, options=["a" * 81, "b", "c", "d"]), "options"),
    "prompt over 200": (q(1, prompt="x" * 201), "prompt"),
    "explanation over 240": (q(1, explanation="x" * 241), "explanation"),
    "empty explanation": (q(1, explanation=""), "explanation"),
    "correct_index 4": (q(1, correct_index=4), "correct_index"),
    "correct_index text": (q(1, correct_index="1"), "correct_index"),
    "correct_index bool": (q(1, correct_index=True), "correct_index"),
    "bad difficulty": (q(1, difficulty="trivial"), "difficulty"),
    "model set status": (q(1, status="reviewed"), "status"),
    "model set id": (q(1, id="roman-history.q001"), "id"),
    "model set title_id": (q(1, title_id="roman-history"), "title_id"),
    "model set review_note": (q(1, review_note="ok"), "review_note"),
    "unknown field": (q(1, hint="x"), "hint"),
}


@pytest.mark.parametrize("name", BAD_QUIZ)
def test_bad_quiz_item_blocks_the_whole_merge(dirs, base, name):
    bad, field = BAD_QUIZ[name]
    put(dirs[1], "quiz", [q(7), bad, q(8)])
    before = (dirs[0] / "roman-history.json").read_bytes()
    res = run(dirs)
    assert not res.ok and not res.quiz_added and res.written is False
    assert (dirs[0] / "roman-history.json").read_bytes() == before, "nothing written when anything is wrong"
    msg = "\n".join(res.errors)
    assert "quiz #2" in msg and field in msg and "quiz #1" not in msg and "quiz #3" not in msg


def test_model_cannot_smuggle_a_reviewed_status(dirs):
    put(dirs[1], "quiz", [q(1, status="reviewed")])
    res = run(dirs)
    assert not res.ok and "status" in "\n".join(res.errors)
    assert all(x["status"] != "reviewed" or x["id"] == "roman-history.q001" for x in stored(dirs)["quiz"])


BAD_FEED = {
    "unknown lesson": (f(1, lesson_id="roman-history.l99"), "lesson_id"),
    "null lesson": (f(1, lesson_id=None), "lesson_id"),
    "41 words": (f(1, text=" ".join(["w"] * 41)), "text"),
    "281 chars": (f(1, text="x" * 281), "text"),
    "empty text": (f(1, text=""), "text"),
    "unknown image": (f(1, image_id="roman-history.i77"), "image_id"),
    "model set status": (f(1, status="reviewed"), "status"),
    "unknown field": (f(1, source="wiki"), "source"),
}


@pytest.mark.parametrize("name", BAD_FEED)
def test_bad_feed_item_blocks_the_whole_merge(dirs, name):
    bad, field = BAD_FEED[name]
    put(dirs[1], "feed", [f(7), bad])
    res = run(dirs)
    assert not res.ok and not res.feed_added
    msg = "\n".join(res.errors)
    assert "feed #2" in msg and field in msg and "feed #1" not in msg


def test_exactly_40_words_and_280_chars_pass(dirs):
    put(dirs[1], "feed", [f(1, text=" ".join(["w"] * 40)), f(2, text="x" * 280)])
    assert run(dirs).ok


def test_known_image_id_and_missing_image_key_are_fine(dirs, base):
    img = base["images"][0]["id"]
    item = f(2)
    del item["image_id"]
    put(dirs[1], "feed", [f(1, image_id=img), item])
    assert run(dirs).ok
    assert stored(dirs)["feed_facts"][-1]["image_id"] is None


def test_all_problems_are_reported_in_one_run(dirs):
    put(dirs[1], "quiz", [q(1, lesson_id="nope"), q(2, options=["a"]), q(3)])
    put(dirs[1], "feed", [f(1, text="")])
    res = run(dirs)
    assert len(res.errors) >= 3
    text = merge.format_report(res)
    assert "quiz #1" in text and "quiz #2" in text and "feed #1" in text and "nothing was written" in text.lower()


def test_skip_invalid_merges_the_good_items_and_lists_the_bad(dirs):
    put(dirs[1], "quiz", [q(1), q(2, options=["a"]), q(3)])
    res = run(dirs, skip_invalid=True)
    assert res.ok and len(res.quiz_added) == 2 and len(res.invalid) == 1
    ids = [x["id"] for x in stored(dirs)["quiz"][-2:]]
    assert ids == ["roman-history.q021", "roman-history.q022"], "no id gap for the skipped item"
    assert "quiz #2" in merge.format_report(res)


def test_would_exceed_schema_limits(dirs, base):
    base["quiz"] = [copy.deepcopy(base["quiz"][0]) | {"id": f"roman-history.q{i:03d}", "prompt": f"P{i}?"}
                    for i in range(1, 80)]
    (dirs[0] / "roman-history.json").write_text(json.dumps(base), "utf-8")
    put(dirs[1], "quiz", [q(1), q(2)])
    res = run(dirs)
    assert not res.ok and "80" in "\n".join(res.errors)


# ---- file-level errors ----------------------------------------------------------------------------------------

def test_invalid_json_reports_line_and_column(dirs):
    put(dirs[1], "quiz", None, raw='{"quiz": [\n  {"lesson_id": "x",}\n]}')
    res = run(dirs)
    assert not res.ok and "line 2" in "\n".join(res.errors) and "roman-history.quiz.json" in "\n".join(res.errors)


@pytest.mark.parametrize("raw", ['[]', '{"feed_facts": []}', '{"quiz": {}}', '{"quiz": [], "extra": 1}', '', 'null'])
def test_wrong_top_level_shape(dirs, raw):
    put(dirs[1], "quiz", None, raw=raw)
    res = run(dirs)
    assert not res.ok and res.errors


def test_item_that_is_not_an_object(dirs):
    put(dirs[1], "quiz", ["a string", 3, q(1)])
    res = run(dirs)
    assert not res.ok and "quiz #1" in "\n".join(res.errors) and "quiz #2" in "\n".join(res.errors)


def test_no_drafts_is_a_usage_error(dirs):
    with pytest.raises(merge.MergeUsage, match="roman-history.quiz.json"):
        run(dirs)


def test_missing_title_file_is_a_usage_error(tmp_path):
    (tmp_path / "d").mkdir()
    (tmp_path / "d" / "ghost.quiz.json").write_text('{"quiz": []}', "utf-8")
    with pytest.raises(merge.MergeUsage, match="ghost"):
        merge.merge_title("ghost", tmp_path, tmp_path / "d")


@pytest.mark.parametrize("bad", ["../x", "Roman History", "a/b", ""])
def test_title_id_must_be_a_slug(tmp_path, bad):
    with pytest.raises(merge.MergeUsage):
        merge.merge_title(bad, tmp_path, tmp_path)


def test_title_file_that_was_already_invalid_blocks(dirs, base):
    base["lessons"][0]["image_ids"] = ["roman-history.i99"]
    (dirs[0] / "roman-history.json").write_text(json.dumps(base), "utf-8")
    put(dirs[1], "quiz", [q(1)])
    res = run(dirs)
    assert not res.ok and "i99" in "\n".join(res.errors) and not res.quiz_added


def test_title_file_id_must_match_file_name(dirs, base):
    base["id"] = "other"
    (dirs[0] / "roman-history.json").write_text(json.dumps(base), "utf-8")
    put(dirs[1], "quiz", [q(1)])
    with pytest.raises(merge.MergeUsage, match="other"):
        run(dirs)


# ---- warnings and report ----------------------------------------------------------------------------------------

def test_warns_when_difficulty_mix_is_far_from_40_40_20(dirs):
    put(dirs[1], "quiz", [q(i, difficulty="easy") for i in range(1, 11)])
    res = run(dirs)
    assert res.ok and any("difficulty" in w for w in res.warnings)


def test_report_lists_counts_and_what_is_left_to_review(dirs):
    put(dirs[1], "quiz", [q(1), q(2)])
    put(dirs[1], "feed", [f(1)])
    text = merge.format_report(run(dirs))
    assert "roman-history" in text and "+2 quiz" in text and "+1 feed" in text
    assert "needs_check" in text and "q021" in text


# ---- CLI ----------------------------------------------------------------------------------------------------------

def cli_run(dirs, *extra):
    return cli.main(["merge", "--titles", str(dirs[0]), "--drafts", str(dirs[1]), *extra])


def test_cli_merge_one_title(dirs, capsys):
    put(dirs[1], "quiz", [q(1)])
    assert cli_run(dirs, "roman-history") == 0
    assert "+1 quiz" in capsys.readouterr().out and len(stored(dirs)["quiz"]) == 11


def test_cli_exit_1_and_message_on_bad_drafts(dirs, capsys):
    put(dirs[1], "quiz", [q(1, options=["a"])])
    assert cli_run(dirs, "roman-history") == 1
    out = capsys.readouterr().out
    assert "quiz #1" in out and "options" in out and len(stored(dirs)["quiz"]) == 10


def test_cli_exit_2_without_drafts_or_id(dirs, capsys):
    assert cli_run(dirs, "roman-history") == 2
    assert cli_run(dirs) == 2
    assert "roman-history.quiz.json" in capsys.readouterr().out


def test_cli_dry_run_and_skip_invalid_flags(dirs, capsys):
    put(dirs[1], "quiz", [q(1), q(2, options=["a"])])
    assert cli_run(dirs, "roman-history", "--dry-run") == 1  # still reports the problem
    assert cli_run(dirs, "roman-history", "--dry-run", "--skip-invalid") == 0
    assert len(stored(dirs)["quiz"]) == 10
    assert cli_run(dirs, "roman-history", "--skip-invalid") == 0
    assert len(stored(dirs)["quiz"]) == 11


def test_cli_all_merges_every_title_with_drafts_and_fails_if_any_fails(dirs, base, capsys):
    # a second title file without drafts must be skipped
    (dirs[0] / "untouched.json").write_text(json.dumps({**base, "id": "untouched"}), "utf-8")
    put(dirs[1], "quiz", [q(1)])
    assert cli_run(dirs, "--all") == 0
    out = capsys.readouterr().out
    assert "roman-history" in out and "untouched" not in out.split("roman-history", 1)[0]
    put(dirs[1], "feed", [f(1, text="")])
    assert cli_run(dirs, "--all") == 1


def test_cli_all_with_no_drafts_at_all_is_exit_2(dirs):
    assert cli_run(dirs, "--all") == 2


def test_merge_result_passes_the_publish_gate_counts(dirs):
    """Gate G10 counts the new items as needs_check; the title still passes G1 to G9."""
    put(dirs[1], "quiz", [q(1), q(2)])
    run(dirs)
    rep = gate.check(stored(dirs))
    assert not [e for e in rep.errors if e[0] in ("G1", "G5", "G6")], rep.lines()
    assert rep.needs_check["quiz"] >= 3


def test_every_problem_of_one_item_is_listed_together(dirs):
    put(dirs[1], "quiz", [q(1, status="reviewed", lesson_id="roman-history.l99", options=["a", "a", "c", "d"])])
    msg = "\n".join(run(dirs).errors)
    assert all(w in msg for w in ("status", "lesson_id", "options"))


def test_rejected_items_do_not_come_back_and_their_ids_are_not_reused(dirs, base):
    rej = dirs[0].parent / "rejected"
    rej.mkdir()
    gone = {"id": "roman-history.q030", "prompt": "Rejected one?"}
    (rej / "roman-history.json").write_text(json.dumps([{"kind": "quiz", "item": gone, "note": "wrong"}]), "utf-8")
    put(dirs[1], "quiz", [q(1, prompt="rejected ONE"), q(2)])
    res = run(dirs)
    assert res.ok and len(res.quiz_added) == 1 and "rejected" in "\n".join(res.skipped)
    assert res.quiz_added[0]["id"] == "roman-history.q031"
