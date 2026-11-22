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
    rate_limit_ip_per_min: int = 120


settings = Settings()
