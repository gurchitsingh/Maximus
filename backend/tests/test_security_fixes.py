"""Fixes from docs/SECURITY_AUDIT.md (H1, M1, M2, M3, M4, L5, L6, ...). Addresses are RFC 2606 / RFC 5737 only."""
import uuid
from datetime import timedelta

import pytest

from app import main
from app.config import settings
from app.models import User
from app.services.auth import limits, tokens
from app.services.chat import service as chat_service
from tests.auth_helpers import PASSWORD, bearer, signup
from tests.fake_llm import FakeProvider, failing
from tests.test_chat import GOOD, chat  # noqa: F401 (the chat fixture)


def err(r, status, code):
    assert r.status_code == status, r.text
    assert r.json()["error"]["code"] == code, r.text
    return r.json()["error"]


# ---------- H1: a client cannot choose its own IP ----------

def _signin(client, i, xff):
    # a new email each time, so only the per-IP limit can stop the run (password spraying)
    return client.post("/v1/auth/signin", json={"email": f"spray{i}@example.com", "password": PASSWORD},
                       headers={"X-Forwarded-For": xff})


def test_h1_spoofed_leftmost_entries_do_not_skip_the_signin_limit(client, monkeypatch):
    """Render-shaped chain: the client sends any X-Forwarded-For, the proxy appends the real address."""
    monkeypatch.setattr(settings, "trusted_proxy_hops", 1)
    for i in range(10):
        r = _signin(client, i, f"198.51.100.{i}, 10.0.0.{i}, 203.0.113.7")
        assert r.status_code == 401, r.text
    e = err(_signin(client, 10, "198.51.100.99, 203.0.113.7"), 429, "rate_limited")
    assert e["details"] == {"scope": "ip"}
    # another real client (another last hop) still gets in
    assert _signin(client, 11, "198.51.100.10, 203.0.113.8").status_code == 401


def test_h1_without_trusted_hops_the_header_is_ignored(client, monkeypatch):
    monkeypatch.setattr(settings, "trusted_proxy_hops", 0)
    for i in range(10):
        assert _signin(client, i, f"203.0.113.{i}").status_code == 401
    err(_signin(client, 10, "203.0.113.200"), 429, "rate_limited")


def test_h1_a_header_shorter_than_the_hops_falls_back_to_the_peer(client, monkeypatch):
    monkeypatch.setattr(settings, "trusted_proxy_hops", 2)
    for i in range(10):
        assert _signin(client, i, f"203.0.113.{i}").status_code == 401  # one entry < 2 hops: the peer is used
    err(_signin(client, 10, "203.0.113.201"), 429, "rate_limited")


def test_h1_get_limit_uses_the_same_client_ip(client, monkeypatch):
    monkeypatch.setattr(settings, "trusted_proxy_hops", 1)
    monkeypatch.setattr(main.limiter, "limit", 3)
    for i in range(3):
        assert client.get("/v1/catalogue", headers={"X-Forwarded-For": f"198.51.100.{i}, 203.0.113.7"}).status_code == 200
    err(client.get("/v1/catalogue", headers={"X-Forwarded-For": "198.51.100.50, 203.0.113.7"}), 429, "rate_limited")
    assert client.get("/v1/catalogue", headers={"X-Forwarded-For": "203.0.113.9"}).status_code == 200


@pytest.fixture
def no_ip_limit(monkeypatch):
    monkeypatch.setattr(limits.auth_ip, "limit", 10_000)


# ---------- M2: revoking every session also kills the access tokens already issued ----------

@pytest.fixture
def at(monkeypatch):
    """Freeze the server clock; at(seconds) moves it forward from the frozen start."""
    base = tokens.utcnow()
    shift = {"s": 0}
    monkeypatch.setattr(tokens, "utcnow", lambda: base + timedelta(seconds=shift["s"]))

    def move(seconds):
        shift["s"] = seconds
    return move


def test_m2_password_reset_kills_old_access_tokens(client, outbox, at, no_ip_limit):
    old = signup(client)
    client.post("/v1/auth/forgot-password", json={"email": "ada@example.com"})
    at(30)
    r = client.post("/v1/auth/reset-password", json={"token": outbox.token("reset"), "new_password": "a new long password"})
    assert r.status_code == 204, r.text
    err(client.get("/v1/me", headers=bearer(old)), 401, "unauthorized")
    err(client.get("/v1/me/sync", headers=bearer(old)), 401, "unauthorized")
    new = client.post("/v1/auth/signin", json={"email": "ada@example.com", "password": "a new long password"}).json()
    assert client.get("/v1/me", headers=bearer(new)).status_code == 200


def test_m2_google_link_kills_the_pre_registered_password_session(client, google, at, no_ip_limit):
    attacker = signup(client)  # D48: anyone can sign up with someone else's address
    at(60)
    victim = client.post("/v1/auth/google", json={"id_token": google.token()}).json()
    assert victim["user"]["has_google"] is True and victim["user"]["has_password"] is False
    err(client.get("/v1/me", headers=bearer(attacker)), 401, "unauthorized")
    err(client.delete("/v1/me", headers=bearer(attacker)), 401, "unauthorized")
    assert client.get("/v1/me", headers=bearer(victim)).status_code == 200  # issued in the same second: valid


def test_m2_refresh_token_reuse_kills_access_tokens(client, at, no_ip_limit):
    first = signup(client)
    at(10)
    second = client.post("/v1/auth/refresh", json={"refresh_token": first["refresh_token"]}).json()
    assert client.get("/v1/me", headers=bearer(first)).status_code == 200  # a normal refresh revokes nothing else
    assert client.get("/v1/me", headers=bearer(second)).status_code == 200
    at(20)
    err(client.post("/v1/auth/refresh", json={"refresh_token": first["refresh_token"]}), 401, "token_reused")
    err(client.get("/v1/me", headers=bearer(first)), 401, "unauthorized")
    err(client.get("/v1/me", headers=bearer(second)), 401, "unauthorized")
    again = client.post("/v1/auth/signin", json={"email": "ada@example.com", "password": PASSWORD}).json()
    assert client.get("/v1/me", headers=bearer(again)).status_code == 200


def test_m2_a_user_never_revoked_keeps_working(client, seeded):
    d = signup(client)
    with seeded() as db:
        assert db.get(User, uuid.UUID(d["user"]["id"])).tokens_valid_after is None
    assert client.get("/v1/me", headers=bearer(d)).status_code == 200


# ---------- M1: throwaway accounts cannot drain the global chat cap ----------

def test_m1_sixth_signup_from_one_ip_in_a_day_is_limited(client, no_ip_limit):
    for i in range(5):
        signup(client, email=f"throwaway{i}@example.com")
    e = err(client.post("/v1/auth/signup", json={"email": "throwaway5@example.com", "password": PASSWORD}),
            429, "rate_limited")
    assert e["details"] == {"scope": "ip"} and e["retry_after_s"] > 3600


def test_m1_failed_signups_do_not_count(client, no_ip_limit):
    signup(client)
    for _ in range(6):
        err(client.post("/v1/auth/signup", json={"email": "ada@example.com", "password": PASSWORD}), 409, "email_taken")
        err(client.post("/v1/auth/signup", json={"email": "x@example.com", "password": "short"}), 422, "weak_password")
    for i in range(4):
        signup(client, email=f"real{i}@example.com")


def test_m1_signup_cap_is_per_ip(client, monkeypatch, no_ip_limit):
    monkeypatch.setattr(settings, "trusted_proxy_hops", 1)
    for i in range(5):
        signup_from(client, f"a{i}@example.com", "203.0.113.1")
    assert client.post("/v1/auth/signup", json={"email": "a5@example.com", "password": PASSWORD},
                       headers={"X-Forwarded-For": "203.0.113.1"}).status_code == 429
    signup_from(client, "b0@example.com", "203.0.113.2")


def signup_from(client, email, ip):
    r = client.post("/v1/auth/signup", json={"email": email, "password": PASSWORD}, headers={"X-Forwarded-For": ip})
    assert r.status_code == 201, r.text
    return r.json()


def test_m1_one_ip_gets_40_chats_a_day_across_accounts(chat, monkeypatch, no_ip_limit):
    monkeypatch.setattr(chat_service.ip_daily, "limit", settings.chat_ip_daily_cap)
    monkeypatch.setattr(settings, "trusted_proxy_hops", 1)
    xff = {"X-Forwarded-For": "198.51.100.1, 203.0.113.50"}
    second = bearer(signup(chat.client, email="second@example.com"))
    third = bearer(signup(chat.client, email="third@example.com"))
    for headers in ({**chat.headers, **xff}, {**second, **xff}):
        for _ in range(20):
            assert chat.post(install_id=None, headers=headers).status_code == 200
    e = err(chat.post(install_id=None, headers={**third, **xff}), 429, "rate_limited")
    assert e["details"] == {"scope": "ip"}
    # another client IP is not affected, and the global cap (200) was never the limit
    assert chat.post(install_id=None, headers={**third, "X-Forwarded-For": "203.0.113.51"}).status_code == 200


def test_m1_only_200_replies_count_per_ip(chat, monkeypatch):
    monkeypatch.setattr(chat_service.ip_daily, "limit", 2)
    chat.providers = [failing("openrouter")]
    for _ in range(3):
        assert chat.post(install_id=None).status_code == 503
    chat.providers = [FakeProvider("openrouter", [GOOD])]
    assert [chat.post(install_id=None).status_code for _ in range(3)] == [200, 200, 429]
