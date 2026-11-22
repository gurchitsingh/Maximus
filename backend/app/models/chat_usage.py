"""chat_usage (CONTRACTS 2.10, D19): one row per (UTC day, salted install hash). Its own table and migration (0002)."""
from sqlalchemy import Integer, String
from sqlalchemy.orm import Mapped, mapped_column

from app.db import Base


class ChatUsage(Base):
    __tablename__ = "chat_usage"
    day: Mapped[str] = mapped_column(String, primary_key=True)  # YYYY-MM-DD, UTC
    install_hash: Mapped[str] = mapped_column(String, primary_key=True)  # sha256(INSTALL_ID_SALT + install_id)
    count: Mapped[int] = mapped_column(Integer, default=0)
