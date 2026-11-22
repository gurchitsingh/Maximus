"""Every endpoint against docs/schemas and docs/examples (CONTRACTS 10, backend API row)."""
import json

import pytest

from app import main
from app.config import settings
from app.db import get_db
from app.models import Title
from app.services import otd
from tests.conftest import SAMPLES, example, schema_errors

TITLES = ["roman-history", "shivaji-maharaj", "chanakya"]


def strip(doc):
    return {k: v for k, v in doc.items() if k != "generated_at"}


# ---------- 200 bodies validate and match the examples ----------

def test_healthz(client):
    r = client.get("/healthz")
    assert r.status_code == 200 and r.headers["cache-control"] == "no-store"
    assert schema_errors(r.json(), "health.schema.json") == []
    assert r.json() == example("health.json")


def test_catalogue_schema_and_example(client):
    r = client.get("/v1/catalogue")
    assert r.status_code == 200
    assert schema_errors(r.json(), "catalogue.schema.json") == []
    assert r.json() == example("catalogue.json")  # incl. catalogue_version hash and generated_at
    assert r.headers["cache-control"] == "no-cache"
    assert [t["id"] for t in r.json()["titles"]] == sorted(TITLES, key=lambda i: (
        next(t["rank"] for t in r.json()["titles"] if t["id"] == i), i))


@pytest.mark.parametrize("tid", TITLES)
def test_title_detail_equals_sample(client, tid):
    r = client.get(f"/v1/titles/{tid}")
    assert r.status_code == 200
    assert schema_errors(r.json(), "title.schema.json") == []
    sample = json.loads((SAMPLES / f"{tid}.json").read_text("utf-8"))
    assert r.json() == sample  # the DB round-trips the import file exactly


def test_feed_schema_and_example(client):
    r = client.get("/v1/feed", params={"title_ids": ",".join(TITLES), "limit": 6, "seed": 42})
    assert r.status_code == 200 and r.headers["cache-control"] == "no-store"
    assert schema_errors(r.json(), "feed.schema.json") == []
    assert strip(r.json()) == strip(example("feed.json"))


def test_feed_defaults_echo_a_seed_and_unknown_ids_give_empty(client):
    r = client.get("/v1/feed", params={"title_ids": "roman-history"})
    assert schema_errors(r.json(), "feed.schema.json") == []
    assert len(r.json()["facts"]) == 8 and isinstance(r.json()["seed"], int)
    r = client.get("/v1/feed", params={"title_ids": "nope"})
    assert r.status_code == 200 and r.json()["facts"] == []
    assert schema_errors(r.json(), "feed.schema.json") == []


def test_credits_schema_and_example(client):
    r = client.get("/v1/credits")
    assert r.status_code == 200
    assert schema_errors(r.json(), "credits.schema.json") == []
    assert r.json() == example("credits.json")


def test_fonts_schema_and_example(client):
    r = client.get("/v1/fonts")
    assert r.status_code == 200
    assert schema_errors(r.json(), "credits.schema.json#/$defs/font_list") == []
    assert r.json() == example("fonts.json")


# ---------- On This Day (Wikipedia mocked, no network) ----------

WIKI = {"selected": [
    {"year": 1783, "text": "First free balloon flight.", "pages": [{
        "normalizedtitle": "Jean-François Pilâtre de Rozier",
        "content_urls": {"desktop": {"page": "https://en.wikipedia.org/wiki/Pil%C3%A2tre"}}}]},
    {"year": -27, "text": "Augustus is named.", "pages": [{
        "normalizedtitle": "Ancient Rome",
        "content_urls": {"desktop": {"page": "https://en.wikipedia.org/wiki/Ancient_Rome"}}}]},
    {"year": 5, "text": "No page, skipped.", "pages": []},
]}


def test_on_this_day_success_links_and_caches(client, monkeypatch):
    calls = []
    monkeypatch.setattr(otd, "fetch_wikipedia", lambda d: calls.append(d) or WIKI)
    r = client.get("/v1/on-this-day", params={"date": "11-21"})
    assert r.status_code == 200 and r.headers["cache-control"] == "max-age=3600"
    body = r.json()
    assert schema_errors(body, "on-this-day.schema.json") == []
    assert body["stale"] is False and len(body["items"]) == 2
    assert [i["linked_title_id"] for i in body["items"]] == [None, "roman-history"]  # Ancient_Rome is a text source
    assert body["source"]["url"].endswith("Selected_anniversaries/November_21")
    client.get("/v1/on-this-day", params={"date": "11-21"})
    assert calls == ["11-21"]  # second call served from the 24 h cache


def test_on_this_day_failure_serves_stale_copy(client, monkeypatch, seeded):
    monkeypatch.setattr(otd, "fetch_wikipedia", lambda d: WIKI)
    client.get("/v1/on-this-day", params={"date": "11-21"})
    from app.models import OnThisDayCache
    with seeded() as db:  # age the cache past 24 h
        db.get(OnThisDayCache, "11-21").fetched_at = "2020-01-01T00:00:00Z"
        db.commit()

    def boom(d):
        raise RuntimeError("wikipedia down")
    monkeypatch.setattr(otd, "fetch_wikipedia", boom)
    r = client.get("/v1/on-this-day", params={"date": "11-21"})
    assert r.status_code == 200 and r.json()["stale"] is True
    assert schema_errors(r.json(), "on-this-day.schema.json") == []


def test_on_this_day_failure_without_cache_is_503(client, monkeypatch):
    def boom(d):
        raise RuntimeError("wikipedia down")
    monkeypatch.setattr(otd, "fetch_wikipedia", boom)
    r = client.get("/v1/on-this-day", params={"date": "03-05"})
    assert r.status_code == 503 and r.headers["retry-after"] == "600"
    assert r.json()["error"]["code"] == "upstream_unavailable"
    assert schema_errors(r.json(), "error.schema.json") == []


def test_on_this_day_bad_date_is_422(client):
    for bad in ("13-01", "1-1", "02-30x", "abc"):
        r = client.get("/v1/on-this-day", params={"date": bad})
        assert r.status_code == 422 and r.json()["error"]["code"] == "validation_error"


# ---------- ETag + 304 ----------

@pytest.mark.parametrize("path", ["/v1/catalogue", "/v1/titles/roman-history", "/v1/credits", "/v1/fonts"])
def test_etag_and_304(client, path):
    r = client.get(path)
    tag = r.headers["etag"]
    assert tag.startswith('"') and len(tag) == 18
    r2 = client.get(path, headers={"If-None-Match": tag})
    assert r2.status_code == 304 and r2.content == b""
    assert client.get(path, headers={"If-None-Match": '"0000000000000000"'}).status_code == 200


def test_etag_ignores_generated_at_but_tracks_content(client, seeded):
    tag = client.get("/v1/titles/chanakya").headers["etag"]
    with seeded() as db:
        t = db.get(Title, "chanakya")
        t.brief = "changed"
        db.commit()
    assert client.get("/v1/titles/chanakya").headers["etag"] != tag


# ---------- errors: status, body shape, Retry-After ----------

def check_error(r, status, code):
    assert r.status_code == status
    assert schema_errors(r.json(), "error.schema.json") == []
    e = r.json()["error"]
    assert e["code"] == code
    if e["retry_after_s"] is not None:
        assert r.headers["retry-after"] == str(e["retry_after_s"])
    return e


def test_error_title_not_found(client):
    e = check_error(client.get("/v1/titles/nope"), 404, "title_not_found")
    assert e["details"] == {"title_id": "nope"}


def test_error_unknown_path_and_method(client):
    check_error(client.get("/v1/nothing"), 404, "not_found")
    check_error(client.post("/v1/catalogue"), 405, "not_found")


@pytest.mark.parametrize("params", [{}, {"title_ids": "a", "limit": 0}, {"title_ids": "a", "limit": 51},
                                    {"title_ids": "Bad Slug"}, {"title_ids": "a", "seed": -1},
                                    {"title_ids": ",".join(f"t{i}" for i in range(31))}])
def test_error_feed_validation(client, params):
    e = check_error(client.get("/v1/feed", params=params), 422, "validation_error")
    assert e["details"]["fields"]


def test_error_rate_limited(client):
    main.limiter.limit = 3
    try:
        for _ in range(3):
            assert client.get("/v1/credits").status_code == 200
        r = client.get("/v1/credits")
        e = check_error(r, 429, "rate_limited")
        assert e["details"] == {"scope": "ip"} and e["retry_after_s"] >= 1
        assert client.get("/healthz").status_code == 200  # healthz is not limited
    finally:
        main.limiter.limit = settings.rate_limit_ip_per_min


def test_error_internal_never_leaks(client, monkeypatch):
    monkeypatch.setattr("app.routers.v1.store.build_credits", lambda db: 1 / 0)
    r = client.get("/v1/credits")
    e = check_error(r, 500, "internal_error")
    assert "Zero" not in json.dumps(r.json()) and e["details"] is None


# ---------- served set: production vs SERVE_DRAFTS ----------

def test_production_serves_published_only(client, seeded, monkeypatch):
    monkeypatch.setattr(settings, "serve_drafts", False)
    assert client.get("/v1/catalogue").json()["titles"] == []
    check_error(client.get("/v1/titles/roman-history"), 404, "title_not_found")
    assert client.get("/v1/feed", params={"title_ids": "roman-history"}).json()["facts"] == []
    with seeded() as db:
        db.get(Title, "roman-history").status = "published"
        db.commit()
    cat = client.get("/v1/catalogue").json()
    assert schema_errors(cat, "catalogue.schema.json") == []
    assert [t["id"] for t in cat["titles"]] == ["roman-history"]
    detail = client.get("/v1/titles/roman-history").json()
    # samples are needs_check, so a published title serves no unreviewed quiz or facts
    assert detail["quiz"] == [] and detail["feed_facts"] == []
    assert detail["quiz_count"] == 0 and cat["titles"][0]["quiz_count"] == 0
    assert schema_errors(detail, "title.schema.json") == []
