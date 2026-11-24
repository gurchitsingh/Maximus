"""Daily chat counters (CONTRACTS 2.10, 16, D19).

- chat_usage: one row per (UTC day, account). The per-account cap and the global cap (SUM for the day) read it.
  Migration 0003 rebuilt it keyed by user_id.
- chat_install_usage: the S14 per-install table (salted install hash), renamed in 0003. Kept as an extra abuse
  signal when the app sends its install id; it holds no account link.
Both keep today and yesterday only.
"""
import uuid

from sqlalchemy import ForeignKey, Integer, String, Uuid
from sqlalchemy.orm import Mapped, mapped_column

from app.db import Base


class ChatUsage(Base):
    __tablename__ = "chat_usage"
    day: Mapped[str] = mapped_column(String, primary_key=True)  # YYYY-MM-DD, UTC
    user_id: Mapped[uuid.UUID] = mapped_column(Uuid, ForeignKey("users.id", ondelete="CASCADE"), primary_key=True)
    count: Mapped[int] = mapped_column(Integer, default=0)


class ChatInstallUsage(Base):
    __tablename__ = "chat_install_usage"
    day: Mapped[str] = mapped_column(String, primary_key=True)  # YYYY-MM-DD, UTC
    install_hash: Mapped[str] = mapped_column(String, primary_key=True)  # sha256(INSTALL_ID_SALT + install_id)
    count: Mapped[int] = mapped_column(Integer, default=0)
