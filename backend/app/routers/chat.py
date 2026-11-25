"""POST /v1/titles/{id}/chat (CONTRACTS 4, 16) and the stored history under /v1/me/chat (16).
Included by routers/v1.py. Every route needs a signed-in account."""
import re

from fastapi import APIRouter, Depends, Query, Request, Response
from fastapi.responses import JSONResponse
from sqlalchemy.orm import Session
from starlette.concurrency import run_in_threadpool

from app.db import get_db
from app.errors import ApiError
from app.models import User
from app.services.auth import limits
from app.services.auth.deps import client_ip, current_user
from app.services.chat import history, service, usage
from app.services.chat.providers import Provider, default_providers

router = APIRouter()
SLUG = re.compile(r"^[a-z0-9]+(-[a-z0-9]+)*$")
NO_STORE = {"Cache-Control": "no-store"}


def get_providers() -> list[Provider]:
    """The provider chain; tests override this dependency with fakes."""
    return default_providers()


def _slug(title_id: str) -> str:
    if len(title_id) > 100 or not SLUG.match(title_id):
        raise ApiError(404, "title_not_found", "No such title.", details={"title_id": title_id[:100]})
    return title_id


@router.post("/titles/{title_id}/chat")
async def chat(title_id: str, request: Request, user: User = Depends(current_user), db: Session = Depends(get_db),
               providers: list[Provider] = Depends(get_providers)):
    declared = request.headers.get("content-length")
    if declared and declared.isdigit() and int(declared) > service.MAX_BODY_BYTES:
        raw = b"x" * (service.MAX_BODY_BYTES + 1)  # refuse without reading a large body
    else:
        raw = await request.body()
    # Sync pipeline (DB + blocking provider calls) off the event loop.
    reply = await run_in_threadpool(service.handle, db, title_id, raw, client_ip(request), providers, user.id)
    return JSONResponse(reply, headers=NO_STORE)


@router.get("/me/chat/{title_id}")
def chat_history(title_id: str, limit: int = Query(50, ge=1, le=100), before: str | None = Query(None, max_length=64),
                 user: User = Depends(current_user), db: Session = Depends(get_db)):
    return JSONResponse(history.page(db, user.id, _slug(title_id), limit, before, usage.utcnow()), headers=NO_STORE)


@router.delete("/me/chat/{title_id}", status_code=204)
def delete_title_chat(title_id: str, user: User = Depends(current_user), db: Session = Depends(get_db)):
    limits.account_writes.check(str(user.id))
    history.delete_title(db, user.id, _slug(title_id))
    return Response(status_code=204)


@router.delete("/me/chat", status_code=204)
def delete_all_chats(user: User = Depends(current_user), db: Session = Depends(get_db)):
    limits.account_writes.check(str(user.id))
    history.delete_all(db, user.id)
    return Response(status_code=204)
