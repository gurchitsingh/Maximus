"""The chat pipeline, CONTRACTS 4.1 steps 1 to 10. Replies are whole JSON, never streamed (D1).

Never stored or logged: message text, history, replies, install ids, keys. Logs keep codes, provider, latency, lengths.
"""
import json
import logging
import time
from typing import Literal

from pydantic import BaseModel, ConfigDict, Field, ValidationError
from sqlalchemy.orm import Session

from app.config import settings
from app.errors import ApiError
from app.services import store
from app.services.chat import usage
from app.services.chat.guard import check_output, looks_like_injection
from app.services.chat.prompt import CANARY, build_context, build_turns, system_prompt
from app.services.chat.providers import Provider, ProviderError
from app.services.ratelimit import RateLimiter

log = logging.getLogger("maximus.chat")
MAX_BODY_BYTES = 8 * 1024
PROVIDERS_DOWN_RETRY_S = 300

install_limiter = RateLimiter(settings.chat_install_per_min, scope="install")
ip_limiter = RateLimiter(settings.chat_ip_per_min, scope="ip")


class HistoryTurn(BaseModel):
    model_config = ConfigDict(extra="forbid", strict=True)
    role: Literal["user", "assistant"]
    text: str = Field(min_length=1, max_length=1200)


class ChatRequest(BaseModel):
    """Mirrors docs/schemas/chat-request.schema.json."""
    model_config = ConfigDict(extra="forbid", strict=True)
    install_id: str = Field(pattern=r"^[0-9a-f]{8}-[0-9a-f]{4}-4[0-9a-f]{3}-[89ab][0-9a-f]{3}-[0-9a-f]{12}$")
    message: str = Field(min_length=1, max_length=500)
    history: list[HistoryTurn] = Field(max_length=6)


def parse_body(raw: bytes) -> ChatRequest:
    """Step 1a: ≤8 KB and valid JSON (else 400), schema (else 422)."""
    if len(raw) > MAX_BODY_BYTES:
        raise ApiError(400, "bad_request", "Request body is over 8 KB.", details={"reason": "body_too_large"})
    try:
        doc = json.loads(raw.decode("utf-8"))
    except (UnicodeDecodeError, ValueError):
        raise ApiError(400, "bad_request", "Request body is not valid JSON.", details={"reason": "invalid_json"})
    try:
        return ChatRequest.model_validate(doc)
    except ValidationError as e:
        fields = [{"loc": ".".join(["body", *map(str, err["loc"])]), "msg": err["msg"]} for err in e.errors()]
        raise ApiError(422, "validation_error", "Request failed validation.", details={"fields": fields})


def refusal_text(title: dict) -> str:
    """Fixed, server-built wording (CONTRACTS 4). Never model text."""
    return f"I only know about {title['name']}."


def handle(db: Session, title_id: str, raw_body: bytes, client_ip: str, providers: list[Provider]) -> dict:
    started = time.monotonic()
    # 1 Validate
    req = parse_body(raw_body)
    title = store.get_title(db, title_id)
    if title is None:
        raise ApiError(404, "title_not_found", f"No served title with id '{title_id}'.", details={"title_id": title_id})
    # 2 Burst limits
    ihash = usage.install_hash(req.install_id)
    install_limiter.check(ihash)
    ip_limiter.check(client_ip)
    # 3 Caps
    now = usage.utcnow()
    usage.purge_old(db, now)
    cap = settings.chat_daily_cap
    if usage.used_today(db, ihash, now) >= cap:
        raise ApiError(429, "chat_daily_cap", "Daily chat limit reached for this install.",
                       retry_after_s=usage.seconds_to_midnight(now), details={"cap": cap})
    if usage.used_today_all(db, now) >= settings.chat_global_daily_cap:
        raise ApiError(503, "chat_resting", "The server-wide daily chat limit is reached.",
                       retry_after_s=usage.seconds_to_midnight(now), details={"reason": "global_cap"})

    kind, text, numbers, provider_used, reason = "out_of_scope", refusal_text(title), (), None, ""
    # 4 Pre-filter
    if not req.message.strip() or looks_like_injection(req.message):
        reason = "prefilter"
    else:
        # 5 Context, 6 Prompt
        context, in_context = build_context(title, req.message, settings.chat_context_chars)
        system = system_prompt(title["name"], context, CANARY)
        turns = build_turns([h.model_dump() for h in req.history], req.message)
        # 7 Providers, in order; all failed -> resting
        raw = None
        for p in providers:
            try:
                raw = p.complete(system, turns)
                provider_used = p.name
                break
            except ProviderError as e:
                log.warning("chat provider failed provider=%s reason=%s", p.name, e.reason)
            except Exception:  # a provider bug must not become a 500 or skip the fallback
                log.exception("chat provider crashed provider=%s", p.name)
        if raw is None:
            log.warning("chat resting reason=providers_down title=%s", title_id)
            raise ApiError(503, "chat_resting", "All chat providers are unavailable.",
                           retry_after_s=PROVIDERS_DOWN_RETRY_S, details={"reason": "providers_down"})
        # 8 Output check (fails closed)
        checked = check_output(raw, CANARY, {l["index"] for l in in_context})
        if checked.ok:
            kind, text, numbers = "answer", checked.text, checked.lesson_numbers
        else:
            reason = checked.reason
    # 9 Count every 200 reply
    remaining = max(0, cap - usage.add_one(db, ihash, now))
    # 10 Reply
    by_index = {l["index"]: l["id"] for l in title["lessons"]}
    refs = [{"lesson_id": by_index[n], "index": n} for n in numbers] if kind == "answer" else []
    log.info("chat reply title=%s kind=%s reason=%s provider=%s ms=%d in_len=%d out_len=%d",
             title_id, kind, reason or "-", provider_used or "-", (time.monotonic() - started) * 1000,
             len(req.message), len(text))
    return {"kind": kind, "text": text, "lesson_refs": refs, "remaining_today": remaining}


def reset_limits() -> None:
    install_limiter.reset()
    ip_limiter.reset()
