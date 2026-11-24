"""Alembic runs against DATABASE_URL_DIRECT (Neon's non-pooled endpoint), falling back to DATABASE_URL
(CONTRACTS 18). Run it once per deploy, never from several workers at the same time."""
from alembic import context
from sqlalchemy import create_engine

from app.config import normalise_db_url, settings
from app.db import Base
import app.models  # noqa: F401  (register tables)

target_metadata = Base.metadata
url = normalise_db_url(context.config.get_main_option("sqlalchemy.url") or settings.migration_url)


def run_migrations_online():
    engine = create_engine(url)
    with engine.connect() as conn:
        context.configure(connection=conn, target_metadata=target_metadata, render_as_batch=True)
        with context.begin_transaction():
            context.run_migrations()
    engine.dispose()


run_migrations_online()
