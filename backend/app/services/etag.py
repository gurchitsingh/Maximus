"""Canonical JSON, short hashes and ETag responses (CONTRACTS 3.1)."""
import hashlib
import json

from fastapi import Request, Response
from fastapi.responses import JSONResponse


def canonical(obj) -> str:
    return json.dumps(obj, sort_keys=True, separators=(",", ":"), ensure_ascii=False)


def short_hash(obj) -> str:
    return hashlib.sha256(canonical(obj).encode("utf-8")).hexdigest()[:16]


def etag_response(request: Request, body: dict, cache_control: str = "no-cache") -> Response:
    """ETag over the body without its top-level generated_at. Equal If-None-Match -> 304, no body."""
    tag = '"' + short_hash({k: v for k, v in body.items() if k != "generated_at"}) + '"'
    headers = {"ETag": tag, "Cache-Control": cache_control}
    if request.headers.get("if-none-match") == tag:
        return Response(status_code=304, headers=headers)
    return JSONResponse(body, headers=headers)
