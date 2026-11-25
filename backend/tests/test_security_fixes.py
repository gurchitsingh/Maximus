"""Fixes from docs/SECURITY_AUDIT.md (H1, M1, M2, M3, M4, L5, L6, ...). Addresses are RFC 2606 / RFC 5737 only."""
import pytest

from app import main
from app.config import settings
from app.services.auth import limits
from tests.auth_helpers import PASSWORD


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
