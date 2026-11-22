"""POST /v1/titles/{id}/chat (CONTRACTS 3.1, 4). Included by routers/v1.py."""
from fastapi import APIRouter, Depends, Request
from fastapi.responses import JSONResponse
from sqlalchemy.orm import Session
from starlette.concurrency import run_in_threadpool

from app.db import get_db
from app.services.chat import service
from app.services.chat.providers import Provider, default_providers

router = APIRouter()


def get_providers() -> list[Provider]:
    """The provider chain; tests override this dependency with fakes."""
    return default_providers()


@router.post("/titles/{title_id}/chat")
async def chat(title_id: str, request: Request, db: Session = Depends(get_db),
               providers: list[Provider] = Depends(get_providers)):
    declared = request.headers.get("content-length")
    if declared and declared.isdigit() and int(declared) > service.MAX_BODY_BYTES:
        raw = b"x" * (service.MAX_BODY_BYTES + 1)  # refuse without reading a large body
    else:
        raw = await request.body()
    ip = request.client.host if request.client else "unknown"
    # Sync pipeline (DB + blocking provider calls) off the event loop.
    reply = await run_in_threadpool(service.handle, db, title_id, raw, ip, providers)
    return JSONResponse(reply, headers={"Cache-Control": "no-store"})
