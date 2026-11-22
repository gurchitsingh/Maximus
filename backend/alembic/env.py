from alembic import context
from sqlalchemy import create_engine

from app.config import settings
from app.db import Base
import app.models  # noqa: F401  (register tables)

target_metadata = Base.metadata
url = context.config.get_main_option("sqlalchemy.url") or settings.database_url


def run_migrations_online():
    engine = create_engine(url)
    with engine.connect() as conn:
        context.configure(connection=conn, target_metadata=target_metadata, render_as_batch=True)
        with context.begin_transaction():
            context.run_migrations()


run_migrations_online()
