"""accounts, sync records, chat history; chat_usage keyed by account (S17, CONTRACTS 14 to 18).

- New: users, refresh_tokens, email_tokens, user_records, user_chat_messages.
- chat_usage (S14, per install hash) is renamed chat_install_usage; a new chat_usage is keyed by (day, user_id).
- Postgres only: the content JSON columns from 0001 become JSONB (CONTRACTS 18 "Types").

Run with the direct (non-pooled) URL: DATABASE_URL_DIRECT, fallback DATABASE_URL (alembic/env.py).

Revision ID: 0003
Revises: 0002
"""
from alembic import op
import sqlalchemy as sa
from sqlalchemy.dialects import postgresql

from app.db import JSONType, UTCDateTime

revision = '0003'
down_revision = '0002'
branch_labels = None
depends_on = None

CONTENT_JSON = {
    'on_this_day_cache': ['payload'],
    'titles': ['poster_lines', 'themes', 'linked_title_ids', 'person'],
    'lessons': ['image_ids', 'source_ids'],
    'quiz_questions': ['options'],
}


def _fk_user():
    return sa.ForeignKey('users.id', ondelete='CASCADE')


def upgrade() -> None:
    op.create_table('users',
        sa.Column('id', sa.Uuid(), nullable=False),
        sa.Column('email', sa.String(length=254), nullable=True),
        sa.Column('password_hash', sa.String(), nullable=True),
        sa.Column('google_sub', sa.String(length=255), nullable=True),
        sa.Column('email_verified', sa.Boolean(), nullable=False),
        sa.Column('display_name', sa.String(length=80), nullable=True),
        sa.Column('sync_seq', sa.BigInteger(), nullable=False, server_default='0'),
        sa.Column('purged_seq', sa.BigInteger(), nullable=False, server_default='0'),
        sa.Column('created_at', UTCDateTime(), nullable=False),
        sa.PrimaryKeyConstraint('id'),
        sa.UniqueConstraint('email'),
        sa.UniqueConstraint('google_sub'),
    )
    op.create_table('refresh_tokens',
        sa.Column('id', sa.Uuid(), nullable=False),
        sa.Column('user_id', sa.Uuid(), _fk_user(), nullable=False),
        sa.Column('token_hash', sa.String(length=64), nullable=False),
        sa.Column('family_id', sa.Uuid(), nullable=False),
        sa.Column('expires_at', UTCDateTime(), nullable=False),
        sa.Column('revoked_at', UTCDateTime(), nullable=True),
        sa.Column('created_at', UTCDateTime(), nullable=False),
        sa.PrimaryKeyConstraint('id'),
        sa.UniqueConstraint('token_hash'),
    )
    op.create_index('ix_refresh_tokens_user_id', 'refresh_tokens', ['user_id'])
    op.create_table('email_tokens',
        sa.Column('id', sa.Uuid(), nullable=False),
        sa.Column('user_id', sa.Uuid(), _fk_user(), nullable=False),
        sa.Column('purpose', sa.String(length=16), nullable=False),
        sa.Column('token_hash', sa.String(length=64), nullable=False),
        sa.Column('expires_at', UTCDateTime(), nullable=False),
        sa.Column('used_at', UTCDateTime(), nullable=True),
        sa.Column('created_at', UTCDateTime(), nullable=False),
        sa.PrimaryKeyConstraint('id'),
        sa.UniqueConstraint('token_hash'),
    )
    op.create_index('ix_email_tokens_user_id', 'email_tokens', ['user_id'])
    op.create_table('user_records',
        sa.Column('user_id', sa.Uuid(), _fk_user(), nullable=False),
        sa.Column('kind', sa.String(length=32), nullable=False),
        sa.Column('record_id', sa.String(length=200), nullable=False),
        sa.Column('data', JSONType, nullable=True),
        sa.Column('updated_at', UTCDateTime(), nullable=False),
        sa.Column('deleted', sa.Boolean(), nullable=False),
        sa.Column('seq', sa.BigInteger(), nullable=False),
        sa.PrimaryKeyConstraint('user_id', 'kind', 'record_id'),
    )
    op.create_index('ix_user_records_user_seq', 'user_records', ['user_id', 'seq'])
    op.create_table('user_chat_messages',
        sa.Column('id', sa.Uuid(), nullable=False),
        sa.Column('user_id', sa.Uuid(), _fk_user(), nullable=False),
        sa.Column('title_id', sa.String(length=100), nullable=False),
        sa.Column('role', sa.String(length=16), nullable=False),
        sa.Column('text', sa.String(length=1200), nullable=False),
        sa.Column('kind', sa.String(length=16), nullable=True),
        sa.Column('lesson_refs', JSONType, nullable=False),
        sa.Column('created_at', UTCDateTime(), nullable=False),
        sa.PrimaryKeyConstraint('id'),
    )
    op.create_index('ix_user_chat_messages_user_title_created', 'user_chat_messages',
                    ['user_id', 'title_id', 'created_at'])
    op.create_index('ix_user_chat_messages_created', 'user_chat_messages', ['created_at'])

    op.rename_table('chat_usage', 'chat_install_usage')
    op.create_table('chat_usage',
        sa.Column('day', sa.String(), nullable=False),
        sa.Column('user_id', sa.Uuid(), _fk_user(), nullable=False),
        sa.Column('count', sa.Integer(), nullable=False),
        sa.PrimaryKeyConstraint('day', 'user_id'),
    )

    if op.get_bind().dialect.name == 'postgresql':
        for table, cols in CONTENT_JSON.items():
            for col in cols:
                op.alter_column(table, col, type_=postgresql.JSONB(), postgresql_using=f'{col}::jsonb')


def downgrade() -> None:
    if op.get_bind().dialect.name == 'postgresql':
        for table, cols in CONTENT_JSON.items():
            for col in cols:
                op.alter_column(table, col, type_=sa.JSON(), postgresql_using=f'{col}::json')
    op.drop_table('chat_usage')
    op.rename_table('chat_install_usage', 'chat_usage')
    op.drop_index('ix_user_chat_messages_created', table_name='user_chat_messages')
    op.drop_index('ix_user_chat_messages_user_title_created', table_name='user_chat_messages')
    op.drop_table('user_chat_messages')
    op.drop_index('ix_user_records_user_seq', table_name='user_records')
    op.drop_table('user_records')
    op.drop_index('ix_email_tokens_user_id', table_name='email_tokens')
    op.drop_table('email_tokens')
    op.drop_index('ix_refresh_tokens_user_id', table_name='refresh_tokens')
    op.drop_table('refresh_tokens')
    op.drop_table('users')
