"""Settings from the environment / backend/.env (CONTRACTS 11). No secrets have defaults."""
from pathlib import Path

from pydantic_settings import BaseSettings, SettingsConfigDict

BACKEND_DIR = Path(__file__).resolve().parent.parent


class Settings(BaseSettings):
    model_config = SettingsConfigDict(env_file=BACKEND_DIR / ".env", extra="ignore")

    database_url: str = f"sqlite:///{(BACKEND_DIR / 'maximus.db').as_posix()}"
    serve_drafts: bool = False
    wiki_user_agent: str = "MaximusApp/0.1 (https://github.com/gurchitsingh/Maximus)"
    cors_origins: str = ""
    media_dir: str = str(BACKEND_DIR / "media")
    # Absolute base of image URLs written by the ingest (CONTRACTS 2.3, Q9). Dev default = the emulator's view
    # of this PC; rewrite once hosting is decided.
    media_base_url: str = "http://10.0.2.2:8000/media"
    rate_limit_ip_per_min: int = 120


settings = Settings()
