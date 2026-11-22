"""All /v1 GET endpoints and /healthz (CONTRACTS 3.1). Chat (POST) lives in routers/chat.py (S14)."""
import random
import re
from datetime import datetime, timezone

from fastapi import APIRouter, Depends, Query, Request
from fastapi.responses import JSONResponse
from sqlalchemy.orm import Session

from app import __version__
from app.db import get_db
from app.errors import ApiError
from app.routers.chat import router as chat_router
from app.services import otd, store
from app.services.etag import etag_response

DATE_RE = r"^(0[1-9]|1[0-2])-(0[1-9]|[12][0-9]|3[01])$"
SLUG_RE = re.compile(r"^[a-z0-9]+(-[a-z0-9]+)*$")

v1 = APIRouter(prefix="/v1")
v1.include_router(chat_router)
health = APIRouter()


@health.get("/healthz")
def healthz():
    return JSONResponse({"status": "ok", "version": __version__}, headers={"Cache-Control": "no-store"})


@v1.get("/catalogue")
def catalogue(request: Request, db: Session = Depends(get_db)):
    return etag_response(request, store.build_catalogue(db))


@v1.get("/titles/{title_id}")
def title(title_id: str, request: Request, db: Session = Depends(get_db)):
    t = store.get_title(db, title_id)
    if t is None:
        raise ApiError(404, "title_not_found", "No such title.", details={"title_id": title_id})
    return etag_response(request, t)


@v1.get("/feed")
def feed(title_ids: str = Query(...), limit: int = Query(20, ge=1, le=50),
         seed: int | None = Query(None, ge=0, le=2**31 - 1), db: Session = Depends(get_db)):
    ids = [i for i in title_ids.split(",")]
    if not 1 <= len(ids) <= 30 or not all(SLUG_RE.match(i) for i in ids):
        raise ApiError(422, "validation_error", "title_ids must be 1 to 30 comma-separated slugs.",
                       details={"fields": [{"loc": "query.title_ids", "msg": "1 to 30 comma-separated slugs"}]})
    seed = random.SystemRandom().randrange(2**31) if seed is None else seed
    return JSONResponse(store.build_feed(db, ids, limit, seed), headers={"Cache-Control": "no-store"})


@v1.get("/on-this-day")
def on_this_day(request: Request, date: str | None = Query(None, pattern=DATE_RE), db: Session = Depends(get_db)):
    date = date or datetime.now(timezone.utc).strftime("%m-%d")
    return etag_response(request, otd.on_this_day(db, date), cache_control="max-age=3600")


@v1.get("/credits")
def credits(request: Request, db: Session = Depends(get_db)):
    return etag_response(request, store.build_credits(db))


@v1.get("/fonts")
def fonts(request: Request):
    """The bundled-font list (credits.schema.json font_list). The app ships its own copy; this serves the same data."""
    return etag_response(request, store.fonts())
