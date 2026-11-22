"""Maximus API v0 (S10). Run from backend/: uvicorn app.main:app --host 0.0.0.0 --port 8000"""
from fastapi import FastAPI, Request
from fastapi.middleware.cors import CORSMiddleware
from fastapi.staticfiles import StaticFiles
from pathlib import Path

from app import __version__
from app.config import settings
from app.errors import ApiError, error_response, install_handlers
from app.routers.v1 import health, v1
from app.services.ratelimit import RateLimiter

app = FastAPI(title="Maximus API", version=__version__, docs_url="/docs", redoc_url=None)
install_handlers(app)
limiter = RateLimiter(settings.rate_limit_ip_per_min)
app.state.limiter = limiter


@app.middleware("http")
async def rate_limit(request: Request, call_next):
    """120 GET/min per client IP across /v1/* (CONTRACTS 3.1)."""
    if request.method == "GET" and request.url.path.startswith("/v1/"):
        try:
            limiter.check(request.client.host if request.client else "unknown")
        except ApiError as e:  # raised inside middleware: handlers do not see it
            return error_response(e.status, e.code, e.message, e.retry_after_s, e.details)
    return await call_next(request)


origins = [o.strip() for o in settings.cors_origins.split(",") if o.strip()]
if origins:
    app.add_middleware(CORSMiddleware, allow_origins=origins, allow_methods=["GET"], allow_headers=["*"])

app.include_router(health)
app.include_router(v1)

media = Path(settings.media_dir)
if media.is_dir():  # dev image store (gitignored); /media/{path}
    app.mount("/media", StaticFiles(directory=media), name="media")
