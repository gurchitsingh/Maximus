"""Engine, session and portable column types (CONTRACTS 18).

DATABASE_URL picks the engine: sqlite:///... for dev and tests, postgresql+psycopg://... (Neon pooled endpoint)
in production. Neon's pooler is PgBouncer in transaction mode, so psycopg must not use server-side prepared
statements, and the pool stays small.
"""
from datetime import datetime, timezone

from sqlalchemy import JSON, DateTime, create_engine, event
from sqlalchemy.dialects.postgresql import JSONB
from sqlalchemy.orm import DeclarativeBase, sessionmaker
from sqlalchemy.types import TypeDecorator

from app.config import normalise_db_url, settings

# JSON on SQLite, JSONB on Postgres.
JSONType = JSON().with_variant(JSONB(), "postgresql")


class UTCDateTime(TypeDecorator):
    """timestamptz on Postgres; on SQLite a naive value read back as UTC. Python side is always aware UTC."""
    impl = DateTime(timezone=True)
    cache_ok = True

    def process_bind_param(self, value, dialect):
        if value is None:
            return None
        if value.tzinfo is None:
            raise ValueError("naive datetime: use UTC-aware values")
        value = value.astimezone(timezone.utc)
        return value.replace(tzinfo=None) if dialect.name == "sqlite" else value

    def process_result_value(self, value, dialect):
        if value is None:
            return None
        if value.tzinfo is None:
            return value.replace(tzinfo=timezone.utc)
        return value.astimezone(timezone.utc)


class Base(DeclarativeBase):
    pass


def make_engine(url: str, pool_size: int | None = None):
    url = normalise_db_url(url)
    if url.startswith("sqlite"):
        engine = create_engine(url, connect_args={"check_same_thread": False})

        @event.listens_for(engine, "connect")
        def _fk(dbapi_conn, _):
            dbapi_conn.execute("PRAGMA foreign_keys=ON")
        return engine
    if url.startswith("postgresql"):
        return create_engine(
            url,
            connect_args={"prepare_threshold": None},  # PgBouncer transaction mode: no prepared statements
            pool_size=pool_size or settings.db_pool_size, max_overflow=0, pool_pre_ping=True, pool_recycle=300,
        )
    return create_engine(url)


engine = make_engine(settings.database_url)
SessionLocal = sessionmaker(bind=engine, expire_on_commit=False)


def utcnow() -> datetime:
    return datetime.now(timezone.utc)


def get_db():
    db = SessionLocal()
    try:
        yield db
    finally:
        db.close()
