"""Importer, migration and the committed seed data."""
import json

from alembic import command
from alembic.config import Config
from sqlalchemy import inspect

from app.config import BACKEND_DIR
from app.db import Base, make_engine
from app.models import Lesson, Title
from ingest.cli import main as cli_main
from ingest.import_title import import_title, reading_minutes
from tests.conftest import SAMPLES, schema_errors


def test_samples_validate_against_import_schema():
    for f in SAMPLES.glob("*.json"):
        assert schema_errors(json.loads(f.read_text("utf-8")), "title-import.schema.json") == [], f.name


def test_reimport_unchanged_keeps_version_and_change_bumps(seeded):
    data = json.loads((SAMPLES / "chanakya.json").read_text("utf-8"))
    with seeded() as db:
        assert import_title(db, data) == "unchanged"
        assert db.get(Title, "chanakya").content_version == 1
        data["lessons"][0]["heading"] = "A new heading"
        assert import_title(db, data) == "updated"
        t = db.get(Title, "chanakya")
        assert t.content_version == 2 and t.updated_at != "2026-11-22T00:00:00Z"
        assert db.get(Lesson, "chanakya.l01").heading == "A new heading"
        assert db.query(Lesson).filter_by(title_id="chanakya").count() == len(data["lessons"])  # replaced as a set


def test_removed_child_disappears_on_reimport(seeded):
    data = json.loads((SAMPLES / "roman-history.json").read_text("utf-8"))
    data["quiz"] = data["quiz"][:-1]
    with seeded() as db:
        import_title(db, data)
        assert len(db.get(Title, "roman-history").quiz_questions) == len(data["quiz"])


def test_reading_minutes_rule():
    assert reading_minutes("word " * 400) == 2
    assert reading_minutes("") == 1
    assert reading_minutes("![](x.i01)\n" + "word " * 200) == 1  # image lines are not words


def test_cli_seed_samples_is_idempotent(tmp_path, monkeypatch, capsys):
    engine = make_engine(f"sqlite:///{(tmp_path / 'cli.db').as_posix()}")
    Base.metadata.create_all(engine)
    from sqlalchemy.orm import sessionmaker
    monkeypatch.setattr("ingest.cli.SessionLocal", sessionmaker(bind=engine, expire_on_commit=False))
    assert cli_main(["seed-samples"]) == 0
    assert capsys.readouterr().out.count(": created") == 3
    assert cli_main(["seed-samples"]) == 0
    assert capsys.readouterr().out.count(": unchanged") == 3


def test_alembic_migration_matches_models(tmp_path, monkeypatch):
    url = f"sqlite:///{(tmp_path / 'mig.db').as_posix()}"
    monkeypatch.setenv("DATABASE_URL", url)
    from app.config import settings
    monkeypatch.setattr(settings, "database_url", url)
    cfg = Config(str(BACKEND_DIR / "alembic.ini"))
    cfg.set_main_option("script_location", str(BACKEND_DIR / "alembic"))
    cfg.set_main_option("sqlalchemy.url", url)
    command.upgrade(cfg, "head")
    insp = inspect(make_engine(url))
    assert set(Base.metadata.tables) <= set(insp.get_table_names())
    for name, table in Base.metadata.tables.items():
        assert {c["name"] for c in insp.get_columns(name)} == {c.name for c in table.columns}, name
