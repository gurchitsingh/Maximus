"""GET and POST /v1/me/sync (CONTRACTS 15.3). Bearer auth; pushes count against 60 per minute per account."""
from fastapi import APIRouter, Depends, Query, Request
from fastapi.responses import JSONResponse
from sqlalchemy.orm import Session
from starlette.concurrency import run_in_threadpool

from app.db import get_db
from app.models import User
from app.services import sync
from app.services.auth import limits, tokens
from app.services.auth.deps import current_user

router = APIRouter(prefix="/me/sync")
NO_STORE = {"Cache-Control": "no-store"}


@router.get("")
def pull(since: int = Query(0, ge=0, le=2**62), limit: int = Query(200, ge=1, le=500),
         user: User = Depends(current_user), db: Session = Depends(get_db)):
    return JSONResponse(sync.pull(db, user.id, since, limit), headers=NO_STORE)


@router.post("")
async def push(request: Request, user: User = Depends(current_user), db: Session = Depends(get_db)):
    limits.account_writes.check(str(user.id))
    declared = request.headers.get("content-length")
    if declared and declared.isdigit() and int(declared) > sync.MAX_BODY_BYTES:
        raw = b"x" * (sync.MAX_BODY_BYTES + 1)  # refuse without reading a large body
    else:
        raw = await request.body()
    records = sync.parse_push_body(raw)
    result = await run_in_threadpool(sync.push, db, user.id, records, tokens.utcnow())
    return JSONResponse(result, headers=NO_STORE)
