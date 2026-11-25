"""Fixes from docs/SECURITY_AUDIT.md (H1, M1, M2, M3, M4, L5, L6, ...). Addresses are RFC 2606 / RFC 5737 only."""
import uuid
from datetime import timedelta

import pytest

from app import main
from app.config import settings
from app.models import User
from app.services.auth import limits, tokens
from tests.auth_helpers import PASSWORD, bearer, signup


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
