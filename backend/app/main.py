"""Maximus API v0 (S10). Run from backend/: uvicorn app.main:app --host 0.0.0.0 --port 8000"""
import logging
import re

from fastapi import FastAPI, Request
from fastapi.middleware.cors import CORSMiddleware
from fastapi.staticfiles import StaticFiles
from pathlib import Path

from app import __version__
from app.config import Settings, check_startup, settings
from app.errors import ApiError, error_response, install_handlers
from app.routers.v1 import health, v1
from app.routers.web import web
from app.services.auth.deps import client_ip
from app.services.ratelimit import RateLimiter

check_startup(settings)  # production refuses to start without JWT_SECRET, INSTALL_ID_SALT, Postgres

API_HEADERS = {
    "X-Content-Type-Options": "nosniff",
    "Referrer-Policy": "no-referrer",
    "X-Frame-Options": "DENY",
    "Content-Security-Policy": "default-src 'none'; frame-ancestors 'none'",  # JSON API: nothing to load
}
WEB_PATHS = ("/privacy", "/account/", "/reset-password")  # HTML pages set their own headers
HSTS = "max-age=31536000; includeSubDomains"
_TOKEN_QS = re.compile(r"([?&]token=)[^&\s\"]*")


class RedactTokens(logging.Filter):
    """Email links carry a one-time token in the query string (reset, delete). uvicorn's access log
    would write it to Render's logs, so the value is replaced before the record is emitted."""

    def filter(self, record: logging.LogRecord) -> bool:
        if isinstance(record.args, tuple):
            record.args = tuple(_TOKEN_QS.sub(r"\1[redacted]", a) if isinstance(a, str) else a for a in record.args)
        if isinstance(record.msg, str):
            record.msg = _TOKEN_QS.sub(r"\1[redacted]", record.msg)
        return True


def install_log_redaction() -> None:
    for name in ("uvicorn.access", "uvicorn.error", "uvicorn"):
        lg = logging.getLogger(name)
        if not any(isinstance(f, RedactTokens) for f in lg.filters):
            lg.addFilter(RedactTokens())


def build_app(s: Settings) -> FastAPI:
    """Production hides /docs and /openapi.json (the API surface is not a public document) and sends HSTS."""
    prod = s.is_production
    app = FastAPI(title="Maximus API", version=__version__, redoc_url=None,
                  docs_url=None if prod else "/docs", openapi_url=None if prod else "/openapi.json")
    install_handlers(app)
    limiter = RateLimiter(s.rate_limit_ip_per_min)
    app.state.limiter = limiter

    @app.middleware("http")
    async def rate_limit(request: Request, call_next):
        """120 GET/min per client IP across /v1/* (CONTRACTS 3.1)."""
        if request.method == "GET" and request.url.path.startswith("/v1/"):
            try:
                limiter.check(client_ip(request))
            except ApiError as e:  # raised inside middleware: handlers do not see it
                return error_response(e.status, e.code, e.message, e.retry_after_s, e.details)
        return await call_next(request)

    @app.middleware("http")
    async def security_headers(request: Request, call_next):
        resp = await call_next(request)
        path = request.url.path
        if not path.startswith("/docs"):  # Swagger UI needs scripts; it only exists outside production
            for k, v in API_HEADERS.items():
                if k == "Content-Security-Policy" and path.startswith(WEB_PATHS):
                    continue  # the web pages send their own, more specific policy
                resp.headers.setdefault(k, v)
        if prod:
            resp.headers.setdefault("Strict-Transport-Security", HSTS)
        return resp

    origins = [o.strip() for o in s.cors_origins.split(",") if o.strip()]
    if prod:
        origins = [o for o in origins if o != "*"]  # the app needs no CORS; a wildcard is never right in production
    if origins:
        app.add_middleware(CORSMiddleware, allow_origins=origins, allow_methods=["GET", "POST", "DELETE"],
                           allow_headers=["Authorization", "Content-Type", "If-None-Match"])

    app.include_router(health)
    app.include_router(v1)
    app.include_router(web)  # /privacy, /account/delete, email-link pages (CONTRACTS 17)

    media = Path(s.media_dir)
    if media.is_dir():  # dev image store (gitignored); /media/{path}. Production storage is open (DEPLOY.md)
        app.mount("/media", StaticFiles(directory=media), name="media")
    return app


install_log_redaction()
app = build_app(settings)
limiter = app.state.limiter
