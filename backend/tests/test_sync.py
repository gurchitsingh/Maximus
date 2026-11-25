"""GET/POST /v1/me/sync (CONTRACTS 15): last write wins, tombstones, server seq cursor."""
import json
from datetime import datetime, timedelta, timezone

import pytest
from sqlalchemy import select

from app.config import settings
from app.models import User, UserRecord
from app.services import sync
from app.services.auth import limits
from tests.auth_helpers import bearer, signup

URL = "/v1/me/sync"
T0 = "2026-11-24T10:00:00Z"
T1 = "2026-11-24T10:05:00Z"
QUIZ_ID = "8d3c1b2a-4e5f-4a6b-9c7d-0e1f2a3b4c5d"

VALID = {
    "setting": ("theme", {"value": "light"}),
    "interest": ("topic_pick:roman-history",
                 {"kind": "topic_pick", "title_id": "roman-history", "position": 0, "picked_at": T0}),
    "study_item": ("roman-history", {"title_id": "roman-history", "added_at": T0}),
    "rating": ("roman-history", {"title_id": "roman-history", "value": 1, "rated_at": T0}),
    "progress": ("roman-history.l02", {"lesson_id": "roman-history.l02", "title_id": "roman-history",
                                       "lesson_index": 2, "last_opened_at": T0, "completed_at": None}),
    "quiz_result": (QUIZ_ID, {"id": QUIZ_ID, "title_id": "roman-history", "score": 5, "total": 6,
                              "question_ids": ["roman-history.q001", "roman-history.q002"],
                              "wrong_ids": ["roman-history.q002"], "content_version": 1, "taken_at": T0}),
    "feed_item": ("roman-history.f001", {"fact_id": "roman-history.f001", "title_id": "roman-history",
                                         "saved": True, "reaction": 1, "seen_at": T0}),
}


def rec(kind="rating", rid=None, data=None, updated_at=T0, deleted=False):
    vid, vdata = VALID[kind]
    return {"kind": kind, "id": rid or vid, "data": None if deleted else (data or vdata), "updated_at": updated_at,
            "deleted": deleted}


@pytest.fixture
def user(client, monkeypatch):
    monkeypatch.setattr(limits.auth_ip, "limit", 10_000)
    monkeypatch.setattr(limits.account_writes, "limit", 10_000)
    return bearer(signup(client))


def push(client, h, *records):
    r = client.post(URL, json={"records": list(records)}, headers=h)
    assert r.status_code == 200, r.text
    return r.json()


def pull(client, h, since=0, limit=200):
    r = client.get(URL, params={"since": since, "limit": limit}, headers=h)
    assert r.status_code == 200, r.text
    return r.json()


def test_requires_bearer(client):
    assert client.get(URL).status_code == 401
    assert client.post(URL, json={"records": [rec()]}).json()["error"]["code"] == "unauthorized"


@pytest.mark.parametrize("kind", list(VALID))
def test_every_kind_round_trips(client, user, kind):
    out = push(client, user, rec(kind))
    assert out["applied"] == [{"kind": kind, "id": VALID[kind][0], "seq": 1}] and out["cursor"] == 1
    got = pull(client, user)
    assert got == {"records": [{**rec(kind), "seq": 1}], "cursor": 1, "has_more": False, "reset": False}


def test_newer_wins_older_is_superseded(client, user):
    push(client, user, rec(data={"title_id": "roman-history", "value": 1, "rated_at": T1}, updated_at=T1))
    out = push(client, user, rec(data={"title_id": "roman-history", "value": -1, "rated_at": T0}, updated_at=T0))
    assert out["applied"] == [] and out["superseded"][0]["data"]["value"] == 1 and out["superseded"][0]["seq"] == 1
    out = push(client, user, rec(data={"title_id": "roman-history", "value": 0, "rated_at": T1},
                                 updated_at="2026-11-24T10:05:00.001Z"))
    assert out["applied"][0]["seq"] == 2
    assert pull(client, user)["records"][0]["data"]["value"] == 0


def test_equal_time_edit_loses_to_stored(client, user):
    push(client, user, rec())
    out = push(client, user, rec(data={"title_id": "roman-history", "value": -1, "rated_at": T0}))
    assert out["applied"] == [] and out["superseded"][0]["data"]["value"] == 1


def test_delete_beats_edit_at_the_same_instant(client, user):
    push(client, user, rec())
    out = push(client, user, rec(deleted=True))
    assert out["applied"] == [{"kind": "rating", "id": "roman-history", "seq": 2}]
    r = pull(client, user)["records"][0]
    assert r["deleted"] is True and r["data"] is None and r["updated_at"] == T0
    # and an edit at that same instant does not bring it back
    out = push(client, user, rec())
    assert out["superseded"][0]["deleted"] is True


def test_newer_edit_revives_a_tombstone(client, user):
    push(client, user, rec(deleted=True))
    out = push(client, user, rec(updated_at=T1))
    assert out["applied"] and pull(client, user)["records"][0]["deleted"] is False


def test_quiz_results_are_append_only(client, user):
    push(client, user, rec("quiz_result"))
    edited = dict(VALID["quiz_result"][1], score=6)
    out = push(client, user, rec("quiz_result", data=edited, updated_at=T1))
    assert out["applied"] == [] and out["superseded"][0]["data"]["score"] == 5
    assert push(client, user, rec("quiz_result", deleted=True, updated_at=T0))["applied"]  # tombstone always wins
    out = push(client, user, rec("quiz_result", updated_at="2026-11-25T00:00:00Z"))
    assert out["applied"] == [] and out["superseded"][0]["deleted"] is True  # never revived


def test_seq_is_per_user_and_increasing(client, user, monkeypatch):
    other = bearer(signup(client, email="bob@example.com"))
    push(client, user, rec(), rec("study_item"))
    out = push(client, other, rec("setting"))
    assert out["applied"][0]["seq"] == 1
    assert [r["seq"] for r in pull(client, user)["records"]] == [1, 2]
    assert [r["kind"] for r in pull(client, other)["records"]] == ["setting"]  # users never see each other's data


def test_pull_pages_by_seq(client, user):
    ids = [f"title-{i}" for i in range(5)]
    push(client, user, *[rec("study_item", rid=i, data={"title_id": i, "added_at": T0}) for i in ids])
    p1 = pull(client, user, 0, 2)
    assert [r["id"] for r in p1["records"]] == ids[:2] and p1["cursor"] == 2 and p1["has_more"] is True
    p2 = pull(client, user, p1["cursor"], 2)
    p3 = pull(client, user, p2["cursor"], 2)
    assert [r["id"] for r in p2["records"] + p3["records"]] == ids[2:] and p3["has_more"] is False
    assert pull(client, user, p3["cursor"]) == {"records": [], "cursor": 5, "has_more": False, "reset": False}


def test_pull_returns_only_the_latest_version(client, user):
    push(client, user, rec())
    push(client, user, rec(updated_at=T1))
    got = pull(client, user)
    assert len(got["records"]) == 1 and got["records"][0]["seq"] == 2


def test_one_bad_record_does_not_fail_the_batch(client, user):
    out = push(client, user, rec(), {"kind": "nope", "id": "x", "data": {}, "updated_at": T0},
               rec("rating", data={"title_id": "roman-history", "value": 5, "rated_at": T0}, rid="vikings"))
    assert len(out["applied"]) == 1
    assert out["rejected"] == [{"kind": "nope", "id": "x", "reason": "invalid_kind"},
                               {"kind": "rating", "id": "vikings", "reason": "invalid_data"}]


@pytest.mark.parametrize("bad", [
    rec("setting", rid="install_id", data={"value": "3f1c9a52-7b4e-4d2a-9c61-0e8b5a7d2f10"}),  # never synced
    rec("rating", rid="other-title"),                       # id does not match data
    rec("rating", data={"title_id": "roman-history", "value": 1, "rated_at": T0, "extra": 1}),
    rec("rating", data={"title_id": "roman-history", "value": "1", "rated_at": T0}),
    rec("rating", updated_at="2026-11-24 10:00:00"),         # not UTC Z
    rec("rating", updated_at="2026-11-24T10:00:00+05:30"),
    rec("interest", rid="roman-history"),
    rec("quiz_result", rid="not-a-uuid"),
    {"kind": "rating", "id": "roman-history", "updated_at": T0},  # data missing
    {"kind": "rating", "id": "roman-history", "data": VALID["rating"][1], "updated_at": T0, "deleted": "no"},
    "not an object",
])
def test_invalid_records_rejected(client, user, bad):
    out = push(client, user, bad)
    assert out["applied"] == [] and out["rejected"][0]["reason"] == "invalid_data"


def test_too_large_data(client, user):
    big = {"value": "x" * 200}
    assert push(client, user, rec("setting", data=big))["applied"]
    huge = {"kind": "quiz_result", "id": QUIZ_ID, "data": dict(VALID["quiz_result"][1], pad="y" * 9000),
            "updated_at": T0}  # size is checked before the shape
    assert push(client, user, huge)["rejected"][0]["reason"] == "too_large"


def test_future_updated_at_is_clamped(client, user):
    now = datetime.now(timezone.utc)
    future = (now + timedelta(days=365)).strftime("%Y-%m-%dT%H:%M:%SZ")
    push(client, user, rec(updated_at=future))
    stored = datetime.fromisoformat(pull(client, user)["records"][0]["updated_at"].replace("Z", "+00:00"))
    assert stored <= now + timedelta(minutes=5, seconds=5)


def test_millisecond_times_echo_exactly(client, user):
    push(client, user, rec(updated_at="2026-11-24T10:00:00.123Z"))
    assert pull(client, user)["records"][0]["updated_at"] == "2026-11-24T10:00:00.123Z"


@pytest.mark.parametrize("body", [{"records": []}, {"records": "x"}, {}, [1, 2]])
def test_bad_batches_are_400(client, user, body):
    r = client.post(URL, json=body, headers=user)
    assert r.status_code == 400 and r.json()["error"]["code"] == "bad_request"


def test_over_500_records_or_512_kb_is_400(client, user):
    r = client.post(URL, json={"records": [rec()] * 501}, headers=user)
    assert r.status_code == 400
    raw = json.dumps({"records": [rec("setting", data={"value": "x" * 200})] * 2, "pad": "z" * 600_000})
    r = client.post(URL, content=raw, headers={**user, "Content-Type": "application/json"})
    assert r.status_code == 400 and r.json()["error"]["details"] == {"reason": "body_too_large"}


def test_quota_blocks_new_live_records_only(client, user, monkeypatch):
    monkeypatch.setattr(settings, "sync_record_quota", 2)
    out = push(client, user, rec(), rec("study_item"), rec("setting"))
    assert len(out["applied"]) == 2 and out["rejected"] == [{"kind": "setting", "id": "theme", "reason": "quota"}]
    assert push(client, user, rec(updated_at=T1))["applied"]          # editing a live record is fine
    assert push(client, user, rec(deleted=True, updated_at="2026-11-24T11:00:00Z"))["applied"]
    assert push(client, user, rec("setting"))["applied"]             # a delete freed a slot


def test_limit_query_bounds(client, user):
    assert client.get(URL, params={"limit": 0}, headers=user).status_code == 422
    assert client.get(URL, params={"limit": 501}, headers=user).status_code == 422
    assert client.get(URL, params={"since": -1}, headers=user).status_code == 422


def test_tombstone_purge_and_reset(client, user, seeded):
    push(client, user, rec(deleted=True, updated_at="2026-01-01T00:00:00Z"), rec("study_item"))
    push(client, user, rec("setting"))
    with seeded() as db:
        n = sync.purge_tombstones(db, datetime(2026, 11, 24, tzinfo=timezone.utc))
        assert n == 1
        assert db.scalar(select(User)).purged_seq == 1
    assert pull(client, user, since=0)["reset"] is False   # a full pull needs no reset
    assert pull(client, user, since=1)["reset"] is False   # already past the purged tombstone
    with seeded() as db:
        db.scalar(select(User)).purged_seq = 2
        db.commit()
    assert pull(client, user, since=1) == {"records": [], "cursor": 0, "has_more": False, "reset": True}


def test_recent_tombstones_are_kept(client, user, seeded):
    push(client, user, rec(deleted=True, updated_at="2026-11-01T00:00:00Z"))
    with seeded() as db:
        assert sync.purge_tombstones(db, datetime(2026, 11, 24, tzinfo=timezone.utc)) == 0
        assert db.scalar(select(UserRecord)).deleted is True


def test_push_rate_limited_per_account(client, user, monkeypatch):
    monkeypatch.setattr(limits.account_writes, "limit", 2)
    push(client, user, rec())
    push(client, user, rec())
    r = client.post(URL, json={"records": [rec()]}, headers=user)
    assert r.status_code == 429 and r.json()["error"]["details"] == {"scope": "account"}


def test_responses_are_not_cached(client, user):
    assert client.get(URL, headers=user).headers["Cache-Control"] == "no-store"


@pytest.mark.skipif(not __import__("tests.conftest", fromlist=["x"]).TEST_DATABASE_URL,
                    reason="row locks are a Postgres property; SQLite serialises writers itself")
def test_concurrent_pushes_never_share_a_seq(client, user, seeded):
    from concurrent.futures import ThreadPoolExecutor
    with seeded() as db:
        uid = db.scalar(select(User)).id

    def one(i):
        with seeded() as db:
            r = {"kind": "study_item", "id": f"t-{i}", "data": {"title_id": f"t-{i}", "added_at": T0},
                 "updated_at": T0}
            return sync.push(db, uid, [r, dict(r, updated_at=T1)], datetime.now(timezone.utc))["applied"]

    with ThreadPoolExecutor(8) as pool:
        seqs = [a["seq"] for applied in pool.map(one, range(24)) for a in applied]
    assert sorted(seqs) == list(range(1, 49))
