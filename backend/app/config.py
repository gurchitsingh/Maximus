"""Settings from the environment / backend/.env (CONTRACTS 11). No secrets have defaults."""
from pathlib import Path

from pydantic_settings import BaseSettings, SettingsConfigDict

BACKEND_DIR = Path(__file__).resolve().parent.parent


class Settings(BaseSettings):
    model_config = SettingsConfigDict(env_file=BACKEND_DIR / ".env", extra="ignore", env_ignore_empty=True)

    database_url: str = f"sqlite:///{(BACKEND_DIR / 'maximus.db').as_posix()}"
    serve_drafts: bool = False
    wiki_user_agent: str = "MaximusApp/0.1 (https://github.com/gurchitsingh/Maximus)"
    cors_origins: str = ""
    media_dir: str = str(BACKEND_DIR / "media")
    # Absolute base of image URLs written by the ingest (CONTRACTS 2.3, Q9). Dev default = the emulator's view
    # of this PC; rewrite once hosting is decided.
    media_base_url: str = "http://10.0.2.2:8000/media"
    rate_limit_ip_per_min: int = 120

    # Chat (CONTRACTS 4, 11). Keys only from the environment / backend/.env; a provider with no key is skipped.
    # Empty values in .env fall back to these defaults (env_ignore_empty).
    openrouter_api_key: str = ""
    openrouter_model: str = "meta-llama/llama-3.3-70b-instruct:free"
    gemini_api_key: str = ""
    gemini_model: str = "gemini-2.5-flash"
    chat_daily_cap: int = 20             # per install per UTC day (Q4)
    chat_global_daily_cap: int = 200     # all installs per UTC day (Q4)
    chat_provider_timeout_s: float = 12
    chat_context_chars: int = 24000
    install_id_salt: str = ""
    chat_install_per_min: int = 6        # burst limits (CONTRACTS 3.1)
    chat_ip_per_min: int = 20


settings = Settings()
