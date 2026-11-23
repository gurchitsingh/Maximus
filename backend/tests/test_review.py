"""S13 report / review / publish (CONTRACTS 9.1, 9.3). Fake data only: a gate-passing topic built by the fake
Wikipedia client, plus hand-made quiz and feed items."""
import json

import pytest

from app.models import Title
from ingest import cli, gate, review
from ingest.build import build
from ingest.titlefile import UsageError
from tests.test_merge import f, q  # draft-item builders
from tests.wiki_fake import SEED, fake_client

TID = "test-empire"


def item_q(n, status="needs_check", review_note=None, **over):
    d = q(n, lesson_id=f"{TID}.l01", **over)
    return {"id": f"{TID}.q{n:03d}", "title_id": TID, **d, "status": status, "review_note": review_note}


def item_f(n, status="needs_check", review_note=None, **over):
    d = f(n, lesson_id=f"{TID}.l01", **over)
    return {"id": f"{TID}.f{n:03d}", "title_id": TID, **d, "status": status, "review_note": review_note}


@pytest.fixture
def titles(tmp_path):
    client, _ = fake_client(tmp_path)
    t, _ = build(SEED, client, media_dir=tmp_path / "m", media_base_url="http://h/media")
    t["quiz"] = [item_q(1, "reviewed", review_note="ok"), item_q(2), item_q(3), item_q(4)]
    t["feed_facts"] = [item_f(1), item_f(2)]
    assert gate.check(t).ok, gate.check(t).lines()
    d = tmp_path / "titles"
    d.mkdir()
    (d / f"{TID}.json").write_text(json.dumps(t, ensure_ascii=False, indent=2), "utf-8")
    return d


def load(titles):
    return json.loads((titles / f"{TID}.json").read_text("utf-8"))


def save(titles, t):
    (titles / f"{TID}.json").write_text(json.dumps(t, ensure_ascii=False, indent=2), "utf-8")


def statuses(titles, kind="quiz"):
    return {x["id"].rsplit(".", 1)[1]: x["status"] for x in load(titles)[kind]}


def run(titles, **kw):
    return review.review_items(TID, titles, **kw)


# ---- report -----------------------------------------------------------------------------------------------------

def test_report_counts_and_lists_items_to_review(titles):
    rep = review.build_report(load(titles))
    assert (rep.pending_count, len(rep.pending["quiz"]), len(rep.pending["feed_facts"])) == (5, 3, 2)
    text = review.format_report(rep)
    assert "1 reviewed, 3 to review" in text and "to review  test-empire.q002" in text and "f002" in text
    assert "publish gate: PASS" in text and "review test-empire" in text


def test_report_brief_leaves_out_item_lines(titles):
    assert "to review  test" not in review.format_report(review.build_report(load(titles)), items=False)


def test_report_next_step_follows_the_state(titles):
    t = load(titles)
    for k in ("quiz", "feed_facts"):
        for x in t[k]:
            x["status"] = "reviewed"
    assert "--title-reviewed" in review.build_report(t).next_step
    t["status"] = "reviewed"
    assert "publish test-empire" in review.build_report(t).next_step
    t["status"] = "published"
    assert "nothing to do" in review.build_report(t).next_step


def test_report_shows_gate_failures_and_blocks_the_publish_step(titles):
    t = load(titles)
    for x in t["quiz"] + t["feed_facts"]:
        x["status"] = "reviewed"
    t["status"] = "reviewed"
    t["brief"] = "SAMPLE brief"
    rep = review.build_report(t)
    assert "G9" in review.format_report(rep) and "fix the gate" in rep.next_step


def test_report_on_a_broken_file_does_not_crash(titles):
    t = load(titles)
    t["lessons"][0]["image_ids"] = ["test-empire.i99"]
    rep = review.build_report(t)
    assert "G1" in review.format_report(rep) and "fix the title file" in rep.next_step


def test_cli_report_all_and_one(titles, capsys):
    assert cli.main(["report", "--all", "--titles", str(titles)]) == 0
    assert TID in capsys.readouterr().out
    assert cli.main(["report", "ghost", "--titles", str(titles)]) == 2
    assert cli.main(["report", "--titles", str(titles)]) == 2


# ---- review sheet -------------------------------------------------------------------------------------------------

def test_sheet_shows_marked_answer_and_only_unreviewed(titles):
    text = review.review_sheet(load(titles))
    assert "q002" in text and "q001" not in text and "<- marked correct" in text and "why:" in text and "f001" in text


def test_sheet_filters_and_prints_lesson_text(titles):
    t = load(titles)
    t["quiz"][1]["lesson_id"] = f"{TID}.l02"
    assert "q002" not in review.review_sheet(t, lesson="l01") and "q002" in review.review_sheet(t, lesson="l02")
    only_feed = review.review_sheet(t, kind="feed")
    assert "f001" in only_feed and "q003" not in only_feed
    assert t["lessons"][0]["body"][:30] in review.review_sheet(t, lesson="l01", lesson_text=True)
    assert "nothing to review" in review.review_sheet(t, lesson="l09")


# ---- approve / reject ---------------------------------------------------------------------------------------------

@pytest.mark.parametrize("token,expect", [("q002", ["q002"]), (f"{TID}.q003", ["q003"]),
                                          ("q002-q004", ["q002", "q003", "q004"]), ("f001-f002", ["f001", "f002"])])
def test_expand_ids(token, expect):
    assert review.expand_ids(token, TID) == [f"{TID}.{e}" for e in expect]


@pytest.mark.parametrize("token", ["x1", "q12", "q004-q002", "other.q001", "q001-f003", "", "q0001"])
def test_expand_ids_rejects_nonsense(token):
    with pytest.raises(ValueError):
        review.expand_ids(token, TID)


def test_approve_by_ids_and_range_with_note(titles):
    res = run(titles, approve=["q002", "q004"], note="checked against l01")
    assert res.ok and res.approved == [f"{TID}.q002", f"{TID}.q004"] and res.left == 3
    t = load(titles)
    assert statuses(titles) == {"q001": "reviewed", "q002": "reviewed", "q003": "needs_check", "q004": "reviewed"}
    assert t["quiz"][1]["review_note"] == "checked against l01" and t["quiz"][2]["review_note"] is None
    assert t["quiz"][0]["review_note"] == "ok", "an earlier note is kept when no new note is given"
    assert gate.g1_errors(t) == []


def test_approve_changes_only_status_and_note(titles):
    before = load(titles)
    run(titles, approve=["q002-q003"])
    after = load(titles)
    for b, a in zip(before["quiz"], after["quiz"]):
        assert {k: v for k, v in a.items() if k != "status"} == {k: v for k, v in b.items() if k != "status"}
    assert {k: v for k, v in after.items() if k != "quiz"} == {k: v for k, v in before.items() if k != "quiz"}


def test_approve_all_and_kind_filter(titles):
    assert run(titles, approve_all=True, kind="feed").ok
    assert set(statuses(titles, "feed_facts").values()) == {"reviewed"} and statuses(titles)["q002"] == "needs_check"
    res = run(titles, approve_all=True)
    assert res.ok and res.left == 0 and set(statuses(titles).values()) == {"reviewed"}


def test_approving_twice_is_harmless(titles):
    run(titles, approve=["q002"])
    snap = (titles / f"{TID}.json").read_bytes()
    res = run(titles, approve=["q002"])
    assert res.ok and res.already == [f"{TID}.q002"] and not res.approved
    assert (titles / f"{TID}.json").read_bytes() == snap


def test_unknown_id_stops_everything(titles):
    snap = (titles / f"{TID}.json").read_bytes()
    res = run(titles, approve=["q002", "q099"])
    assert not res.ok and "q099" in "\n".join(res.errors) and (titles / f"{TID}.json").read_bytes() == snap
    assert "nothing was written" in review.format_review(res).lower()


def test_reject_removes_logs_and_never_reuses_the_id(titles):
    res = run(titles, reject=["q003"], note="answer is wrong")
    assert res.ok and res.rejected == [f"{TID}.q003"]
    assert "q003" not in statuses(titles)
    log = json.loads((titles.parent / "rejected" / f"{TID}.json").read_text("utf-8"))
    assert log[0]["kind"] == "quiz" and log[0]["item"]["id"] == f"{TID}.q003" and log[0]["note"] == "answer is wrong"
    again = run(titles, reject=["q003"])
    assert not again.ok, "already gone"
    assert len(json.loads((titles.parent / "rejected" / f"{TID}.json").read_text("utf-8"))) == 1


def test_reject_a_reviewed_item_is_refused(titles):
    res = run(titles, reject=["q001"])
    assert not res.ok and "already reviewed" in "\n".join(res.errors) and "q001" in statuses(titles)


def test_approve_and_reject_the_same_item_is_an_error(titles):
    res = run(titles, approve=["q002"], reject=["q002"])
    assert not res.ok and "same call" in "\n".join(res.errors)


def test_approve_all_skips_what_is_rejected_in_the_same_call(titles):
    res = run(titles, approve_all=True, reject=["q004"])
    assert res.ok and f"{TID}.q004" not in res.approved and "q004" not in statuses(titles) and res.left == 0


def test_nothing_to_do_note_too_long_and_dry_run(titles):
    assert "nothing to do" in "\n".join(run(titles).errors)
    assert "300" in "\n".join(run(titles, approve=["q002"], note="x" * 301).errors)
    snap = (titles / f"{TID}.json").read_bytes()
    res = run(titles, approve=["q002"], reject=["q003"], dry_run=True)
    assert res.ok and not res.written and (titles / f"{TID}.json").read_bytes() == snap
    assert not (titles.parent / "rejected").exists()


def test_review_refuses_a_title_that_is_invalid_already(titles):
    t = load(titles)
    t["lessons"][0]["image_ids"] = ["test-empire.i99"]
    save(titles, t)
    assert not run(titles, approve=["q002"]).ok


def test_merge_after_reject_skips_the_rejected_draft(titles):
    (titles.parent / "drafts").mkdir()
    run(titles, reject=["q003"])
    rejected_prompt = item_q(3)["prompt"]
    (titles.parent / "drafts" / f"{TID}.quiz.json").write_text(
        json.dumps({"quiz": [q(3, lesson_id=f"{TID}.l01", prompt=rejected_prompt), q(9, lesson_id=f"{TID}.l01")]}), "utf-8")
    from ingest import merge
    res = merge.merge_title(TID, titles, titles.parent / "drafts")
    assert res.ok and [x["id"] for x in res.quiz_added] == [f"{TID}.q005"] and "rejected" in "\n".join(res.skipped)


# ---- title status and publish -------------------------------------------------------------------------------------

def test_mark_title_reviewed(titles):
    res = review.mark_title_reviewed(TID, titles)
    assert res.ok and res.changed and load(titles)["status"] == "reviewed"
    assert not review.mark_title_reviewed(TID, titles).changed


def test_mark_title_reviewed_refuses_an_invalid_file(titles):
    t = load(titles)
    t["lessons"][0]["image_ids"] = ["test-empire.i99"]
    save(titles, t)
    res = review.mark_title_reviewed(TID, titles)
    assert not res.ok and load(titles)["status"] == "draft"


def test_publish_refuses_a_draft(titles):
    res = review.publish_title(TID, titles)
    assert not res.ok and "reviewed first" in res.message and load(titles)["status"] == "draft"


def test_publish_succeeds_when_the_gate_passes_and_notes_unreviewed_items(titles):
    review.mark_title_reviewed(TID, titles)
    res = review.publish_title(TID, titles)
    assert res.ok and load(titles)["status"] == "published" and "5 item(s) still needs_check" in res.message
    assert gate.check(load(titles)).ok
    again = review.publish_title(TID, titles)
    assert again.ok and "already published" in again.message


GATE_BREAKERS = {
    "G2 short lesson": lambda t: t["lessons"][0].update(body="Far too short.", reading_minutes=1),
    "G4 text source without licence": lambda t: t["sources"][0].update(license=""),
    "G6 long fact": None,  # schema already blocks it: becomes a G1 failure
    "G9 SAMPLE": lambda t: t.update(brief="SAMPLE brief"),
}


@pytest.mark.parametrize("name", [n for n, fn in GATE_BREAKERS.items() if fn])
def test_publish_refuses_any_gate_failure_and_writes_nothing(titles, name):
    t = load(titles)
    GATE_BREAKERS[name](t)
    t["status"] = "reviewed"
    save(titles, t)
    snap = (titles / f"{TID}.json").read_bytes()
    res = review.publish_title(TID, titles)
    assert not res.ok and name.split()[0] in "\n".join(res.problems)
    assert (titles / f"{TID}.json").read_bytes() == snap


def test_publish_refuses_a_g1_failure(titles):
    t = load(titles)
    t["status"] = "reviewed"
    t["feed_facts"][0]["text"] = " ".join(["w"] * 41)
    save(titles, t)
    res = review.publish_title(TID, titles)
    assert not res.ok and "G1" in "\n".join(res.problems) and load(titles)["status"] == "reviewed"


def test_publish_dry_run(titles):
    review.mark_title_reviewed(TID, titles)
    res = review.publish_title(TID, titles, dry_run=True)
    assert res.ok and "would publish" in res.message and load(titles)["status"] == "reviewed"


def test_unknown_title_is_a_usage_error(titles):
    with pytest.raises(UsageError):
        review.publish_title("ghost", titles)
    with pytest.raises(UsageError):
        review.publish_title("../x", titles)


# ---- CLI, end to end ------------------------------------------------------------------------------------------------

def test_cli_end_to_end_merge_report_review_publish(titles, capsys, session_factory, monkeypatch):
    drafts = titles.parent / "drafts"
    drafts.mkdir()
    (drafts / f"{TID}.quiz.json").write_text(json.dumps({"quiz": [q(10, lesson_id=f"{TID}.l01"),
                                                                  q(11, lesson_id=f"{TID}.l01")]}), "utf-8")
    base = ["--titles", str(titles)]
    assert cli.main(["merge", TID, "--titles", str(titles), "--drafts", str(drafts)]) == 0
    assert cli.main(["report", TID, *base]) == 0
    out = capsys.readouterr().out
    assert "to review" in out and "q005" in out
    assert cli.main(["review", TID, *base]) == 0  # sheet
    assert "marked correct" in capsys.readouterr().out
    assert cli.main(["review", TID, "--approve-all", *base]) == 0
    assert cli.main(["publish", TID, *base]) == 1, "title still draft"
    assert cli.main(["review", TID, "--title-reviewed", *base]) == 0
    monkeypatch.setattr(cli, "SessionLocal", session_factory)
    assert cli.main(["publish", TID, "--import", *base]) == 0
    assert "published" in capsys.readouterr().out
    with session_factory() as db:
        assert db.get(Title, TID).status == "published"
    assert statuses(titles) == {f"q{n:03d}": "reviewed" for n in (1, 2, 3, 4, 5, 6)}


def test_cli_review_and_publish_exit_codes(titles, capsys):
    base = ["--titles", str(titles)]
    assert cli.main(["review", TID, "--approve", "q099", *base]) == 1
    assert cli.main(["review", "ghost", *base]) == 2
    assert cli.main(["review", TID, "--approve", "q002", "q004", "--note", "ok", *base]) == 0
    assert cli.main(["review", TID, "--reject", "f001", *base]) == 0
    assert "f001" not in statuses(titles, "feed_facts")
    assert cli.main(["publish", "ghost", *base]) == 2
    assert cli.main(["publish", TID, "--dry-run", *base]) == 1
