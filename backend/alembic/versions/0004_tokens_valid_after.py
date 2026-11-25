"""users.tokens_valid_after: access tokens issued before it are refused (SECURITY_AUDIT M2).

Set by revoke_all (password reset, Google link, refresh-token reuse). NULL = no revocation yet.

Revision ID: 0004
Revises: 0003
"""
from alembic import op
import sqlalchemy as sa

from app.db import UTCDateTime

revision = '0004'
down_revision = '0003'
branch_labels = None
depends_on = None


def upgrade() -> None:
    with op.batch_alter_table('users') as batch:
        batch.add_column(sa.Column('tokens_valid_after', UTCDateTime(), nullable=True))


def downgrade() -> None:
    with op.batch_alter_table('users') as batch:
        batch.drop_column('tokens_valid_after')
