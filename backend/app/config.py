"""Settings from the environment / backend/.env (CONTRACTS 11, 14.5, 18). No secrets have defaults.

Every name is documented in backend/README.md ("Environment"). Empty values fall back to these defaults
(env_ignore_empty), so a .env copied from .env.example works for local runs.
"""
import logging
import secrets
from pathlib import Path

from pydantic_settings import BaseSettings, SettingsConfigDict

BACKEND_DIR = Path(__file__).resolve().parent.parent
log = logging.getLogger("maximus")


def normalise_db_url(url: str) -> str:
    """Hosts (Neon, Render) hand out postgres:// or postgresql:// URLs; SQLAlchemy needs the psycopg 3 driver name."""
    for prefix in ("postgres://", "postgresql://"):
        if url.startswith(prefix):
            return "postgresql+psycopg://" + url[len(prefix):]
    return url


class Settings(BaseSettings):
    model_config = SettingsConfigDict(env_file=BACKEND_DIR / ".env", extra="ignore", env_ignore_empty=True)

    # "development" or "production". Unset on Render (RENDER=true) counts as production.
    environment: str = ""
    render: str = ""

    # Database (CONTRACTS 18). Production: Neon's pooled URL with sslmode=require. Never committed.
    database_url: str = f"sqlite:///{(BACKEND_DIR / 'maximus.db').as_posix()}"
    database_url_direct: str = ""        # non-pooled URL, used by Alembic only (fallback DATABASE_URL)
    db_pool_size: int = 5

    serve_drafts: bool = False
    wiki_user_agent: str = "MaximusApp/0.1 (https://github.com/gurchitsingh/Maximus)"
    cors_origins: str = ""
    media_dir: str = str(BACKEND_DIR / "media")
    # Absolute base of image URLs written by the ingest (CONTRACTS 2.3, Q9). Dev default = the emulator's view
    # of this PC; rewrite once hosting is decided.
    media_base_url: str = "http://10.0.2.2:8000/media"
    rate_limit_ip_per_min: int = 120
    # Proxies in front of the app that each append one X-Forwarded-For entry (SECURITY_AUDIT H1). 0 = ignore the
    # header and use the TCP peer (local runs). Render: 1, the last entry, which its proxy appends.
    trusted_proxy_hops: int = 0

    # Chat (CONTRACTS 4, 11, 16). Keys only from the environment / backend/.env; a provider with no key is skipped.
    openrouter_api_key: str = ""
    openrouter_model: str = "meta-llama/llama-3.3-70b-instruct:free"
    gemini_api_key: str = ""
    gemini_model: str = "gemini-2.5-flash"
    chat_daily_cap: int = 20             # per install per UTC day (Q4), when the app sends install_id
    chat_account_daily_cap: int = 20     # per account per UTC day (CONTRACTS 16)
    chat_global_daily_cap: int = 200     # all accounts per UTC day (Q4)
    chat_retention_days: int = 5         # stored chat history, rolling per message (D46)
    chat_provider_timeout_s: float = 12
    chat_context_chars: int = 24000
    install_id_salt: str = ""
    chat_install_per_min: int = 6        # burst limits (CONTRACTS 3.1); the account burst uses the same number
    chat_ip_per_min: int = 20
    # SECURITY_AUDIT M1: free sign-ups must not let one person drain the global cap. Per client IP, rolling 24 h,
    # in memory like the other limits; only 200 replies and successful sign-ups count.
    chat_ip_daily_cap: int = 40
    signup_ip_daily_cap: int = 5

    # Auth (CONTRACTS 14)
    jwt_secret: str = ""
    google_client_id: str = ""           # the web OAuth client id; not a secret
    app_base_url: str = "http://127.0.0.1:8000"  # email links and the web pages
    contact_email: str = ""              # shown on /privacy; empty = "see the Play Store listing"

    # Email (CONTRACTS 14.5): console (dev: printed to the log), resend (HTTPS API) or smtp
    email_provider: str = "console"
    email_from: str = ""
    email_provider_api_key: str = ""
    smtp_host: str = ""
    smtp_port: int = 587
    smtp_username: str = ""
    smtp_password: str = ""
    smtp_starttls: bool = True

    # Sync (CONTRACTS 15)
    sync_tombstone_days: int = 90
    sync_record_quota: int = 50000

    @property
    def is_production(self) -> bool:
        env = self.environment.strip().lower()
        if env:
            return env == "production"
        return bool(self.render)

    @property
    def sqlalchemy_url(self) -> str:
        return normalise_db_url(self.database_url)

    @property
    def migration_url(self) -> str:
        return normalise_db_url(self.database_url_direct or self.database_url)


def startup_problems(s: Settings) -> list[str]:
    """What stops production from starting (D31 f, D44, CONTRACTS 14.2)."""
    if not s.is_production:
        return []
    problems = []
    if not s.install_id_salt.strip():
        problems.append("INSTALL_ID_SALT is empty")
    if not s.jwt_secret.strip():
        problems.append("JWT_SECRET is empty")
    elif len(s.jwt_secret) < 32:
        problems.append("JWT_SECRET is shorter than 32 characters")
    if s.sqlalchemy_url.startswith("sqlite"):
        problems.append("DATABASE_URL is SQLite (Render's disk is wiped on redeploy; use Postgres)")
    return problems


def check_startup(s: Settings) -> None:
    problems = startup_problems(s)
    if problems:
        raise RuntimeError("Refusing to start in production: " + "; ".join(problems))
    if not s.is_production and not s.jwt_secret:
        # Dev only: a per-process secret, so access tokens stop working when the server restarts.
        s.jwt_secret = secrets.token_urlsafe(48)
        log.warning("JWT_SECRET is empty: using a random per-process secret (development only)")
    if s.is_production and s.email_provider == "console":
        log.warning("EMAIL_PROVIDER is console in production: reset and deletion mails are not sent")


settings = Settings()  # check_startup(settings) runs in app.main, so the ingest CLI can import this without secrets
