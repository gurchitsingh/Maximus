"""Public web pages (CONTRACTS 17): /privacy, the account-deletion flow, and the pages email links open
(/reset-password). Plain HTML templates from app/templates/, no JavaScript, no app needed.

Links in emails never act on GET (mail scanners open links): each page shows one button that POSTs the token.
Every page: no caching, no referrer (the URL carries a token), no framing, a CSP with no scripts.
"""
import html
from pathlib import Path
from string import Template
from urllib.parse import parse_qs

from fastapi import APIRouter, BackgroundTasks, Depends, Query, Request
from fastapi.responses import HTMLResponse
from sqlalchemy.orm import Session
from starlette.concurrency import run_in_threadpool

from app.config import settings
from app.db import get_db
from app.errors import ApiError
from app.routers.auth import get_mailer
from app.services.auth import limits, mailer, service, tokens
from app.services.auth.deps import client_ip

TEMPLATES = Path(__file__).resolve().parent.parent / "templates"
MAX_FORM_BYTES = 4096
HEADERS = {
    "Cache-Control": "no-store",
    "Referrer-Policy": "no-referrer",
    "X-Content-Type-Options": "nosniff",
    "X-Frame-Options": "DENY",
    "Content-Security-Policy": "default-src 'none'; style-src 'unsafe-inline'; form-action 'self'; "
                               "frame-ancestors 'none'; base-uri 'none'",
}

web = APIRouter(include_in_schema=False)


def _tpl(name: str) -> Template:
    return Template((TEMPLATES / name).read_text("utf-8"))


def render(title: str, fragment: str, status: int = 200, raw: dict | None = None, **values) -> HTMLResponse:
    """values are escaped; raw holds HTML we built ourselves (an error line)."""
    fields = {k: html.escape(str(v), quote=True) for k, v in values.items()}
    fields.update(raw or {})
    body = _tpl(fragment).safe_substitute(fields)
    page = _tpl("_layout.html").safe_substitute(title=html.escape(title), body=body)
    return HTMLResponse(page, status_code=status, headers=HEADERS)


def message(title: str, heading: str, text: str, status: int = 200) -> HTMLResponse:
    return render(title, "message.html", status, heading=heading, text=text)


def error_line(text: str) -> dict:
    return {"error": f'<p class="error" role="alert">{html.escape(text)}</p>'}


async def form(request: Request) -> dict[str, str]:
    raw = await request.body()
    if len(raw) > MAX_FORM_BYTES:
        return {}
    try:
        parsed = parse_qs(raw.decode("utf-8"), max_num_fields=10)
    except (UnicodeDecodeError, ValueError):
        return {}
    return {k: v[0] for k, v in parsed.items() if v}


def _too_many() -> HTMLResponse:
    return message("Too many requests", "Too many requests", "Please wait a few minutes and try again.", 429)


INVALID_LINK = ("This link is invalid or has expired", "This link is invalid or has expired",
                "Links work once and only for a short time. Ask for a new one.")


# ---------- privacy ----------

@web.get("/privacy")
def privacy():
    contact = (f"Write to {settings.contact_email}." if settings.contact_email
               else "Contact details are on the app's Google Play listing.")
    return render("Privacy policy", "privacy.html", retention=settings.chat_retention_days, contact=contact)


# ---------- account deletion ----------

@web.get("/account/delete")
def delete_page():
    return render("Delete your account", "delete_request.html", raw={"error": ""})


@web.post("/account/delete/request")
async def delete_request(request: Request, bg: BackgroundTasks, db: Session = Depends(get_db),
                         m: mailer.Mailer = Depends(get_mailer)):
    try:
        limits.web_form_ip.check(client_ip(request))
    except ApiError:
        return _too_many()
    fields = await form(request)
    try:
        email = service.normalise_email(fields.get("email", ""))
    except ApiError:
        return render("Delete your account", "delete_request.html", 422,
                      raw=error_line("Enter a valid email address."))
    try:
        limits.delete_form_email.check(email)
    except ApiError:
        return _too_many()
    for mail in await run_in_threadpool(service.request_delete_link, db, email, tokens.utcnow()):
        bg.add_task(mailer.deliver, m, mail)
    return message("Check your email", "Check your email",
                   "If an account exists for that address, we sent a link to delete it. The link works for one hour.")


@web.get("/account/delete/confirm")
def delete_confirm_page(token: str = Query("", max_length=200), db: Session = Depends(get_db)):
    try:
        service.use_email_token(db, token, "delete", tokens.utcnow(), consume=False)
    except ApiError:
        return message(*INVALID_LINK, status=400)
    return render("Delete your account", "confirm.html", heading="Delete your account?",
                  text="This deletes your account, your study data and your chats. It cannot be undone.",
                  action="/account/delete/confirm", token=token, button="Delete my account", button_class="danger")


@web.post("/account/delete/confirm")
async def delete_confirm(request: Request, db: Session = Depends(get_db)):
    try:
        limits.web_form_ip.check(client_ip(request))
    except ApiError:
        return _too_many()
    fields = await form(request)
    try:
        await run_in_threadpool(service.confirm_delete_link, db, fields.get("token", ""), tokens.utcnow())
    except ApiError:
        return message(*INVALID_LINK, status=400)
    return message("Account deleted", "Your account and data are deleted",
                   "Everything we kept for this account is gone. You can uninstall the app, or sign up again later.")


# ---------- email links ----------

@web.get("/reset-password")
def reset_page(token: str = Query("", max_length=200), db: Session = Depends(get_db)):
    try:
        service.use_email_token(db, token, "reset", tokens.utcnow(), consume=False)
    except ApiError:
        return message(*INVALID_LINK, status=400)
    return render("Choose a new password", "reset_form.html", token=token, raw={"error": ""})


@web.post("/reset-password")
async def reset_submit(request: Request, db: Session = Depends(get_db)):
    try:
        limits.web_form_ip.check(client_ip(request))
    except ApiError:
        return _too_many()
    fields = await form(request)
    token = fields.get("token", "")
    try:
        await run_in_threadpool(service.reset_password, db, token, fields.get("new_password", ""), tokens.utcnow())
    except ApiError as e:
        if e.code == "weak_password":
            return render("Choose a new password", "reset_form.html", 422, token=token,
                          raw=error_line("Use 10 to 128 characters."))
        return message(*INVALID_LINK, status=400)
    return message("Password saved", "Password saved", "Sign in again in the app with your new password.")
