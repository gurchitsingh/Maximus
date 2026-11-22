"""chat_usage: per-install daily chat counts (S14, CONTRACTS 2.10). New table only; earlier tables untouched.

Revision ID: 0002
Revises: 0001
"""
from alembic import op
import sqlalchemy as sa


revision = '0002'
down_revision = '0001'
branch_labels = None
depends_on = None


def upgrade() -> None:
    op.create_table('chat_usage',
    sa.Column('day', sa.String(), nullable=False),
    sa.Column('install_hash', sa.String(), nullable=False),
    sa.Column('count', sa.Integer(), nullable=False),
    sa.PrimaryKeyConstraint('day', 'install_hash')
    )


def downgrade() -> None:
    op.drop_table('chat_usage')
