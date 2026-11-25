"""Account deletion (CONTRACTS 17): DELETE /v1/me and the public web flow, plus /privacy and the email-link pages."""
import re
import uuid
from datetime import datetime, timedelta, timezone

import pytest
from sqlalchemy import func, select

from app.models import (ChatInstallUsage, ChatUsage, EmailToken, RefreshToken, User, UserChatMessage,
                        UserRecord)
from app.services.auth import limits, tokens
from tests.auth_helpers import PASSWORD, bearer, signup

USER_TABLES = (User, RefreshToken, EmailToken, UserRecord, UserChatMessage, ChatUsage)
REC = {"kind": "rating", "id": "roman-history", "updated_at": "2026-11-24T10:00:00Z",
       "data": {"title_id": "roman-history", "value": 1, "rated_at": "2026-11-24T10:00:00Z"}}


@pytest.fixture(autouse=True)
def open_limits(monkeypatch):
    monkeypatch.setattr(limits.auth_ip, "limit", 10_000)
    monkeypatch.setattr(limits.web_form_ip, "limit", 10_000)


@pytest.fixture
def at(monkeypatch):
    base = tokens.utcnow()  # frozen, so token expiry checks do not depend on how long the test runs
    shift = {"s": 0}
    monkeypatch.setattr(tokens, "utcnow", lambda: base + timedelta(seconds=shift["s"]))
    return lambda s: shift.__setitem__("s", s)


def counts(seeded) -> dict:
    with seeded() as db:
        return {m.__tablename__: db.scalar(select(func.count()).select_from(m)) for m in USER_TABLES}


def fill(client, seeded, d) -> uuid.UUID:
    """Give the account data in every user table."""
    h = bearer(d)
    assert client.post("/v1/me/sync", json={"records": [REC]}, headers=h).status_code == 200
    client.post("/v1/auth/resend-verification", headers=h)
    uid = uuid.UUID(d["user"]["id"])
    now = datetime.now(timezone.utc)
    with seeded() as db:
        db.add(UserChatMessage(user_id=uid, title_id="roman-history", role="user", text="hi", lesson_refs=[],
                               created_at=now))
        db.add(ChatUsage(day=now.date().isoformat(), user_id=uid, count=3))
        db.commit()
    return uid


def assert_gone(seeded, uid):
    with seeded() as db:
        for m in USER_TABLES:
            col = m.id if m is User else m.user_id
            assert db.scalar(select(func.count()).select_from(m).where(col == uid)) == 0, m.__tablename__


# ---------- DELETE /v1/me ----------

def test_delete_me_with_password_removes_everything(client, seeded):
    d = signup(client)
    keep = signup(client, email="bob@example.com")
    uid = fill(client, seeded, d)
    fill(client, seeded, keep)
    before = counts(seeded)
    r = client.request("DELETE", "/v1/me", json={"password": PASSWORD}, headers=bearer(d))
    assert r.status_code == 204
    assert_gone(seeded, uid)
    after = counts(seeded)
    assert after["users"] == before["users"] - 1 and after["user_records"] == 1  # bob is untouched
    # the still-unexpired access token and the refresh token stop working at once
    assert client.get("/v1/me", headers=bearer(d)).json()["error"]["code"] == "unauthorized"
    assert client.post("/v1/auth/refresh", json={"refresh_token": d["refresh_token"]}).status_code == 401
    assert client.get("/v1/me", headers=bearer(keep)).status_code == 200


def test_delete_me_password_account_needs_the_password(client):
    d = signup(client)
    r = client.request("DELETE", "/v1/me", headers=bearer(d))
    assert r.status_code == 403 and r.json()["error"]["code"] == "reauth_required"
    r = client.request("DELETE", "/v1/me", json={"password": "wrong password"}, headers=bearer(d))
    assert r.status_code == 401 and r.json()["error"]["code"] == "invalid_credentials"
    assert client.get("/v1/me", headers=bearer(d)).status_code == 200


def test_delete_me_google_needs_a_fresh_token(client, google, seeded, at):
    d = client.post("/v1/auth/google", json={"id_token": google.token()}).json()
    at(301)
    r = client.request("DELETE", "/v1/me", headers=bearer(d))
    assert r.status_code == 403 and r.json()["error"]["code"] == "reauth_required"
    at(0)
    fresh = client.post("/v1/auth/google", json={"id_token": google.token()}).json()
    assert client.request("DELETE", "/v1/me", headers=bearer(fresh)).status_code == 204
    assert counts(seeded)["users"] == 0


def test_delete_me_google_account_cannot_use_a_password(client, google):
    d = client.post("/v1/auth/google", json={"id_token": google.token()}).json()
    r = client.request("DELETE", "/v1/me", json={"password": "anything at all"}, headers=bearer(d))
    assert r.status_code == 401 and r.json()["error"]["code"] == "invalid_credentials"


def test_delete_me_requires_bearer(client):
    assert client.request("DELETE", "/v1/me").json()["error"]["code"] == "unauthorized"


def test_install_counters_are_not_linked_to_the_account(client, seeded):
    """chat_install_usage holds salted install hashes with no account link, so it is not part of the deletion."""
    assert "user_id" not in ChatInstallUsage.__table__.columns


# ---------- public web flow ----------

def link_token(outbox) -> str:
    m = outbox.last("delete")
    assert "/account/delete/confirm?token=" in m.text
    return outbox.token("delete")


def test_delete_page_and_form(client):
    r = client.get("/account/delete")
    assert r.status_code == 200 and r.headers["content-type"].startswith("text/html")
    assert 'action="/account/delete/request"' in r.text and "<script" not in r.text
    assert "default-src 'none'" in r.headers["content-security-policy"]
    assert r.headers["referrer-policy"] == "no-referrer" and r.headers["x-frame-options"] == "DENY"
    assert r.headers["cache-control"] == "no-store"


def test_request_always_says_the_same_and_mails_only_real_accounts(client, outbox):
    signup(client)
    outbox.mails.clear()
    a = client.post("/account/delete/request", data={"email": "ADA@example.com"})
    b = client.post("/account/delete/request", data={"email": "nobody@example.com"})
    assert a.status_code == b.status_code == 200 and a.text == b.text and "If an account exists" in a.text
    assert [(m.to, m.purpose) for m in outbox.mails] == [("ada@example.com", "delete")]


def test_bad_email_shows_the_form_again(client):
    r = client.post("/account/delete/request", data={"email": "not an email"})
    assert r.status_code == 422 and "Enter a valid email address." in r.text


def test_confirm_link_shows_a_button_and_does_not_delete_on_get(client, outbox, seeded):
    signup(client)
    client.post("/account/delete/request", data={"email": "ada@example.com"})
    token = link_token(outbox)
    for _ in range(2):  # a mail scanner opening the link deletes nothing
        r = client.get("/account/delete/confirm", params={"token": token})
        assert r.status_code == 200 and "Delete my account" in r.text and f'value="{token}"' in r.text
    assert counts(seeded)["users"] == 1


def test_confirm_post_deletes_everything_once(client, outbox, seeded):
    d = signup(client)
    uid = fill(client, seeded, d)
    client.post("/account/delete/request", data={"email": "ada@example.com"})
    token = link_token(outbox)
    r = client.post("/account/delete/confirm", data={"token": token})
    assert r.status_code == 200 and "Your account and data are deleted" in r.text
    assert_gone(seeded, uid)
    again = client.post("/account/delete/confirm", data={"token": token})
    assert again.status_code == 400 and "invalid or has expired" in again.text


def test_works_for_google_accounts(client, google, outbox, seeded):
    client.post("/v1/auth/google", json={"id_token": google.token()})
    client.post("/account/delete/request", data={"email": "ada@example.com"})
    client.post("/account/delete/confirm", data={"token": link_token(outbox)})
    assert counts(seeded)["users"] == 0


def test_confirm_link_expires_after_one_hour(client, outbox, at, seeded):
    signup(client)
    client.post("/account/delete/request", data={"email": "ada@example.com"})
    token = link_token(outbox)
    at(3601)
    assert client.get("/account/delete/confirm", params={"token": token}).status_code == 400
    assert client.post("/account/delete/confirm", data={"token": token}).status_code == 400
    assert counts(seeded)["users"] == 1


def test_other_purpose_tokens_cannot_delete(client, outbox, seeded):
    signup(client)
    verify = outbox.token("verify")
    assert client.post("/account/delete/confirm", data={"token": verify}).status_code == 400
    assert counts(seeded)["users"] == 1


@pytest.mark.parametrize("token", ["", "x", "<script>alert(1)</script>"])
def test_bad_tokens_get_the_invalid_page(client, token):
    r = client.get("/account/delete/confirm", params={"token": token})
    assert r.status_code == 400 and "<script>alert" not in r.text


def test_request_limited_3_per_hour_per_email(client):
    for _ in range(3):
        assert client.post("/account/delete/request", data={"email": "ada@example.com"}).status_code == 200
    assert client.post("/account/delete/request", data={"email": "ada@example.com"}).status_code == 429
    assert client.post("/account/delete/request", data={"email": "bob@example.com"}).status_code == 200


def test_request_limited_10_per_minute_per_ip(client, monkeypatch):
    monkeypatch.setattr(limits.web_form_ip, "limit", 10)
    for i in range(10):
        client.post("/account/delete/request", data={"email": f"u{i}@example.com"})
    assert client.post("/account/delete/request", data={"email": "z@example.com"}).status_code == 429


def test_oversized_form_is_treated_as_empty(client):
    r = client.post("/account/delete/request", content=b"email=" + b"a" * 5000,
                    headers={"content-type": "application/x-www-form-urlencoded"})
    assert r.status_code == 422


# ---------- privacy and email-link pages ----------

def test_privacy_page(client, monkeypatch):
    from app.config import settings
    monkeypatch.setattr(settings, "chat_retention_days", 5)
    r = client.get("/privacy")
    assert r.status_code == 200 and "<script" not in r.text
    text = re.sub(r"\s+", " ", r.text)
    for needle in ("email address", "display name", "study data", "Your chats", "5 days", "Render", "Neon",
                   "email provider", "OpenRouter", "Google Gemini", "no ads", "/account/delete",
                   "Google Play listing"):
        assert needle in text, needle


def test_privacy_contact_from_env(client, monkeypatch):
    from app.config import settings
    monkeypatch.setattr(settings, "contact_email", "privacy@example.org")
    assert "Write to privacy@example.org." in client.get("/privacy").text


def test_verify_link_page_flow(client, outbox):
    d = signup(client)
    token = outbox.token("verify")
    page = client.get("/verify-email", params={"token": token})
    assert page.status_code == 200 and "Confirm my email" in page.text
    assert client.get("/v1/me", headers=bearer(d)).json()["email_verified"] is False  # GET did nothing
    done = client.post("/verify-email", data={"token": token})
    assert done.status_code == 200 and "Email confirmed" in done.text
    assert client.get("/v1/me", headers=bearer(d)).json()["email_verified"] is True


def test_reset_link_page_flow(client, outbox):
    signup(client)
    client.post("/v1/auth/forgot-password", json={"email": "ada@example.com"})
    token = outbox.token("reset")
    assert 'name="new_password"' in client.get("/reset-password", params={"token": token}).text
    weak = client.post("/reset-password", data={"token": token, "new_password": "short"})
    assert weak.status_code == 422 and "10 to 128" in weak.text
    ok = client.post("/reset-password", data={"token": token, "new_password": "a new long password"})
    assert ok.status_code == 200 and "Password saved" in ok.text
    r = client.post("/v1/auth/signin", json={"email": "ada@example.com", "password": "a new long password"})
    assert r.status_code == 200
    assert client.get("/reset-password", params={"token": token}).status_code == 400
