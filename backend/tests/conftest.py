"""Test fixtures: a fresh database per test, seeded from backend/data/samples, no network.

SQLite (a temp file per test) by default. Set TEST_DATABASE_URL=postgresql://... to run the same suite on
Postgres (CI does, CONTRACTS 18): tables are created once and emptied before each test.
"""
import json
import os
os.environ["ENVIRONMENT"] = "development"  # a developer's .env must not switch the suite to production checks
from pathlib import Path

import httpx
import pytest
from fastapi.testclient import TestClient
from jsonschema import Draft202012Validator, FormatChecker
from referencing import Registry, Resource
from sqlalchemy import text
from sqlalchemy.orm import sessionmaker

from app import main
from app.config import BACKEND_DIR, settings
from app.db import Base, get_db, make_engine
from ingest.import_title import import_file

ROOT = BACKEND_DIR.parent
SCHEMAS = ROOT / "docs" / "schemas"
EXAMPLES = ROOT / "docs" / "examples"
SAMPLES = BACKEND_DIR / "data" / "samples"
BASE = "https://maximus.example/schemas/"


def _registry():
    reg = Registry()
    for f in SCHEMAS.glob("*.schema.json"):
        reg = reg.with_resource(BASE + f.name, Resource.from_contents(json.loads(f.read_text("utf-8"))))
    return reg


REGISTRY = _registry()


def schema_errors(doc, ref: str) -> list[str]:
    """Validate against docs/schemas with formats checked (uri, date-time), as CONTRACTS 10 requires."""
    schema = {"$schema": "https://json-schema.org/draft/2020-12/schema", "$ref": BASE + ref}
    v = Draft202012Validator(schema, registry=REGISTRY, format_checker=FormatChecker())
    return [f"{'/'.join(map(str, e.path))}: {e.message}" for e in v.iter_errors(doc)]


def example(name: str):
    return json.loads((EXAMPLES / name).read_text("utf-8"))


@pytest.fixture(autouse=True)
def no_network(monkeypatch):
    """No test may reach Wikimedia or anything else: real HTTP transports fail loudly.
    Tests use httpx.MockTransport (tests/wiki_fake.py) or patch the fetch function."""
    def refuse(self, request):
        raise RuntimeError(f"network disabled in tests: {request.url}")
    monkeypatch.setattr(httpx.HTTPTransport, "handle_request", refuse)


TEST_DATABASE_URL = os.environ.get("TEST_DATABASE_URL", "")
_pg_engine = None


def _postgres_engine():
    global _pg_engine
    if _pg_engine is None:
        _pg_engine = make_engine(TEST_DATABASE_URL, pool_size=2)
        Base.metadata.drop_all(_pg_engine)
        Base.metadata.create_all(_pg_engine)
    return _pg_engine


@pytest.fixture
def session_factory(tmp_path):
    if TEST_DATABASE_URL:
        engine = _postgres_engine()
        with engine.begin() as conn:
            names = ", ".join(t.name for t in Base.metadata.sorted_tables)
            conn.execute(text(f"TRUNCATE {names} RESTART IDENTITY CASCADE"))
        yield sessionmaker(bind=engine, expire_on_commit=False)
        return
    engine = make_engine(f"sqlite:///{(tmp_path / 'test.db').as_posix()}")
    Base.metadata.create_all(engine)
    yield sessionmaker(bind=engine, expire_on_commit=False)
    engine.dispose()


@pytest.fixture
def seeded(session_factory):
    with session_factory() as db:
        for f in sorted(SAMPLES.glob("*.json")):
            import_file(db, f)
    return session_factory


@pytest.fixture
def client(seeded, monkeypatch):
    """TestClient over the seeded DB with SERVE_DRAFTS=true (the samples are drafts)."""
    monkeypatch.setattr(settings, "serve_drafts", True)

    def _db():
        with seeded() as db:
            yield db

    main.app.dependency_overrides[get_db] = _db
    main.limiter.reset()
    with TestClient(main.app, raise_server_exceptions=False) as c:
        yield c
    main.app.dependency_overrides.clear()
