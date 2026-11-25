"""SQLAlchemy tables (CONTRACTS 2.10). `index` is reserved in SQL, hence Lesson.idx; `group` is Title.group_key."""
from sqlalchemy import Boolean, Float, ForeignKey, Integer, String, Text
from sqlalchemy.orm import Mapped, mapped_column, relationship

from app.db import Base, JSONType


class Title(Base):
    __tablename__ = "titles"
    id: Mapped[str] = mapped_column(String, primary_key=True)
    kind: Mapped[str] = mapped_column(String)
    name: Mapped[str] = mapped_column(String)
    subtitle: Mapped[str | None] = mapped_column(String)
    poster_lines: Mapped[list] = mapped_column(JSONType)
    group_key: Mapped[str] = mapped_column(String)
    era: Mapped[str] = mapped_column(String)
    region: Mapped[str] = mapped_column(String)
    period_start: Mapped[int | None] = mapped_column(Integer)
    period_end: Mapped[int | None] = mapped_column(Integer)
    themes: Mapped[list] = mapped_column(JSONType)
    bg: Mapped[str] = mapped_column(String)
    tint: Mapped[str] = mapped_column(String)
    lettering: Mapped[str] = mapped_column(String)
    poster_image_id: Mapped[str | None] = mapped_column(String)
    hero_image_id: Mapped[str | None] = mapped_column(String)
    brief: Mapped[str] = mapped_column(Text)
    linked_title_ids: Mapped[list] = mapped_column(JSONType)
    rank: Mapped[int] = mapped_column(Integer, default=0)
    status: Mapped[str] = mapped_column(String)
    content_version: Mapped[int] = mapped_column(Integer, default=1)
    updated_at: Mapped[str] = mapped_column(String)  # UTC ISO 8601 with Z
    payload_hash: Mapped[str] = mapped_column(String)
    person: Mapped[dict | None] = mapped_column(JSONType)

    lessons = relationship("Lesson", cascade="all, delete-orphan", order_by="Lesson.idx")
    images = relationship("Image", cascade="all, delete-orphan", order_by="Image.id")
    quiz_questions = relationship("QuizQuestion", cascade="all, delete-orphan", order_by="QuizQuestion.id")
    feed_facts = relationship("FeedFact", cascade="all, delete-orphan", order_by="FeedFact.id")
    sources = relationship("Source", cascade="all, delete-orphan", order_by="Source.id")


class Lesson(Base):
    __tablename__ = "lessons"
    id: Mapped[str] = mapped_column(String, primary_key=True)
    title_id: Mapped[str] = mapped_column(ForeignKey("titles.id", ondelete="CASCADE"), index=True)
    idx: Mapped[int] = mapped_column(Integer)
    heading: Mapped[str] = mapped_column(String)
    body: Mapped[str] = mapped_column(Text)
    reading_minutes: Mapped[int] = mapped_column(Integer)
    image_ids: Mapped[list] = mapped_column(JSONType)
    read_aloud_text: Mapped[str | None] = mapped_column(Text)
    source_ids: Mapped[list] = mapped_column(JSONType)


class Image(Base):
    __tablename__ = "images"
    id: Mapped[str] = mapped_column(String, primary_key=True)
    title_id: Mapped[str] = mapped_column(ForeignKey("titles.id", ondelete="CASCADE"), index=True)
    url: Mapped[str] = mapped_column(String)
    width: Mapped[int] = mapped_column(Integer)
    height: Mapped[int] = mapped_column(Integer)
    alt: Mapped[str] = mapped_column(String)
    kind: Mapped[str] = mapped_column(String)
    author: Mapped[str] = mapped_column(String)
    license: Mapped[str] = mapped_column(String)
    license_version: Mapped[str | None] = mapped_column(String)
    license_url: Mapped[str | None] = mapped_column(String)
    source_page_url: Mapped[str | None] = mapped_column(String)
    credit_line: Mapped[str] = mapped_column(String)
    modified: Mapped[bool] = mapped_column(Boolean)
    focal_x: Mapped[float] = mapped_column(Float)
    focal_y: Mapped[float] = mapped_column(Float)


class QuizQuestion(Base):
    __tablename__ = "quiz_questions"
    id: Mapped[str] = mapped_column(String, primary_key=True)
    title_id: Mapped[str] = mapped_column(ForeignKey("titles.id", ondelete="CASCADE"), index=True)
    lesson_id: Mapped[str | None] = mapped_column(String)
    prompt: Mapped[str] = mapped_column(String)
    options: Mapped[list] = mapped_column(JSONType)
    correct_index: Mapped[int] = mapped_column(Integer)
    explanation: Mapped[str] = mapped_column(String)
    difficulty: Mapped[str] = mapped_column(String)
    status: Mapped[str] = mapped_column(String)
    review_note: Mapped[str | None] = mapped_column(String)


class FeedFact(Base):
    __tablename__ = "feed_facts"
    id: Mapped[str] = mapped_column(String, primary_key=True)
    title_id: Mapped[str] = mapped_column(ForeignKey("titles.id", ondelete="CASCADE"), index=True)
    lesson_id: Mapped[str | None] = mapped_column(String)
    text: Mapped[str] = mapped_column(String)
    image_id: Mapped[str | None] = mapped_column(String)
    status: Mapped[str] = mapped_column(String)
    review_note: Mapped[str | None] = mapped_column(String)


class Source(Base):
    __tablename__ = "sources"
    id: Mapped[str] = mapped_column(String, primary_key=True)
    title_id: Mapped[str] = mapped_column(ForeignKey("titles.id", ondelete="CASCADE"), index=True)
    title: Mapped[str] = mapped_column(String)
    url: Mapped[str] = mapped_column(String)
    publisher: Mapped[str | None] = mapped_column(String)
    role: Mapped[str] = mapped_column(String)
    license: Mapped[str | None] = mapped_column(String)
    confidence: Mapped[str | None] = mapped_column(String)


class OnThisDayCache(Base):
    __tablename__ = "on_this_day_cache"
    date: Mapped[str] = mapped_column(String, primary_key=True)  # MM-DD
    payload: Mapped[dict] = mapped_column(JSONType)
    fetched_at: Mapped[str] = mapped_column(String)


class IngestRun(Base):
    __tablename__ = "ingest_runs"
    id: Mapped[int] = mapped_column(Integer, primary_key=True, autoincrement=True)
    title_id: Mapped[str] = mapped_column(String)
    kind: Mapped[str] = mapped_column(String)  # wikipedia | import
    started_at: Mapped[str] = mapped_column(String)
    finished_at: Mapped[str | None] = mapped_column(String)
    status: Mapped[str] = mapped_column(String)
    notes: Mapped[str | None] = mapped_column(Text)


from app.models.chat_usage import ChatInstallUsage, ChatUsage  # noqa: E402,F401  (S14 0002, S17 0003)
from app.models.accounts import EmailToken, RefreshToken, User, UserChatMessage, UserRecord  # noqa: E402,F401  (S17, 0003)
