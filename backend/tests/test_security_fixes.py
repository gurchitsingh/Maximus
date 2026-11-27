"""Fixes from docs/SECURITY_AUDIT.md (H1, M1, M2, M3, M4, L5, L6, ...). Addresses are RFC 2606 / RFC 5737 only."""
import logging
import uuid
from datetime import timedelta

import pytest

from app import main
from app.config import settings
from app.errors import ApiError
from app.models import User
from app.services.auth import limits, tokens
from app.services.chat import service as chat_service
from tests.auth_helpers import PASSWORD, bearer, signup
from tests.fake_llm import FakeProvider, failing
from tests.test_chat import GOOD, chat  # noqa: F401 (the chat fixture, used through chat_h)


@pytest.fixture
def chat_h(request):
    """test_chat's harness (a signed-in account, fake providers, a frozen chat clock)."""
    return request.getfixturevalue("chat")


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
    victim = client.post("/v1/auth/google", json={"id_token": google.token(hd="example.com")}).json()
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


# ---------- M4: Google takes a password account only where Google owns the address ----------

def test_m4_gmail_address_links_and_drops_the_password(client, google, no_ip_limit):
    squatter = signup(client, email="ada.l@gmail.com")
    g = client.post("/v1/auth/google", json={"id_token": google.token(email="ada.l@gmail.com")}).json()
    assert g["user"]["id"] == squatter["user"]["id"]
    assert g["user"]["has_google"] is True and g["user"]["has_password"] is False


def test_m4_workspace_address_links(client, google, no_ip_limit):
    squatter = signup(client)
    g = client.post("/v1/auth/google", json={"id_token": google.token(hd="example.com")}).json()
    assert g["user"]["id"] == squatter["user"]["id"] and g["user"]["has_password"] is False


@pytest.mark.parametrize("hd", [None, "", "   "])
def test_m4_other_domains_never_take_a_password_account(client, google, seeded, no_ip_limit, hd):
    """A Google account made long ago with an address its maker no longer controls (a former work address, a
    lapsed domain) must not take the account of the address's current owner."""
    owner = signup(client)
    e = err(client.post("/v1/auth/google", json={"id_token": google.token(hd=hd)}), 409, "email_taken")
    assert e["details"] == {"method": "password"}
    with seeded() as db:
        u = db.get(User, uuid.UUID(owner["user"]["id"]))
        assert u.password_hash is not None and u.google_sub is None and u.tokens_valid_after is None
    assert client.get("/v1/me", headers=bearer(owner)).status_code == 200
    assert client.post("/v1/auth/signin", json={"email": "ada@example.com", "password": PASSWORD}).status_code == 200
    assert client.post("/v1/auth/refresh", json={"refresh_token": owner["refresh_token"]}).status_code == 200


def test_m4_other_domains_still_create_and_sign_in_google_accounts(client, google, no_ip_limit):
    """Only linking to a password account is restricted: a new address, or a returning Google user, is fine."""
    first = client.post("/v1/auth/google", json={"id_token": google.token(email="bo@example.org")})
    assert first.status_code == 200 and first.json()["user"]["has_google"] is True
    again = client.post("/v1/auth/google", json={"id_token": google.token(email="bo@example.org")})
    assert again.status_code == 200 and again.json()["user"]["id"] == first.json()["user"]["id"]


def test_m4_a_googlemail_lookalike_is_not_gmail(client, google, no_ip_limit):
    signup(client, email="ada@gmail.com.example.com")
    e = err(client.post("/v1/auth/google", json={"id_token": google.token(email="ada@gmail.com.example.com")}),
            409, "email_taken")
    assert e["details"] == {"method": "password"}


# ---------- L5: nobody can lock another person out of email sign-in ----------

def _signin_from(client, ip, password="bad bad bad", email="ada@example.com"):
    return client.post("/v1/auth/signin", json={"email": email, "password": password},
                       headers={"X-Forwarded-For": ip})


def test_l5_failures_from_one_ip_do_not_lock_the_owner_elsewhere(client, monkeypatch, no_ip_limit):
    monkeypatch.setattr(settings, "trusted_proxy_hops", 1)
    signup(client)
    for _ in range(5):
        err(_signin_from(client, "198.51.100.66"), 401, "invalid_credentials")
    e = err(_signin_from(client, "198.51.100.66", password=PASSWORD), 429, "rate_limited")
    assert e["details"] == {"scope": "account"} and 0 < e["retry_after_s"] <= 900
    assert _signin_from(client, "203.0.113.20", password=PASSWORD).status_code == 200  # the owner, elsewhere


def test_l5_the_per_email_cap_stops_guessing_spread_over_many_ips(client, monkeypatch, no_ip_limit):
    monkeypatch.setattr(settings, "trusted_proxy_hops", 1)
    monkeypatch.setattr(limits.signin_email_failures, "limit", 12)
    assert limits.signin_email_failures.window_s == 3600
    signup(client)
    for i in range(12):  # 3 IPs, 4 failures each: no (email, ip) pair reaches 5
        err(_signin_from(client, f"198.51.100.{i % 3}"), 401, "invalid_credentials")
    e = err(_signin_from(client, "203.0.113.30", password=PASSWORD), 429, "rate_limited")
    assert e["details"] == {"scope": "account"} and 900 < e["retry_after_s"] <= 3600
    # another address is not affected
    err(_signin_from(client, "203.0.113.30", email="bob@example.com"), 401, "invalid_credentials")


def test_l5_when_both_limits_are_full_retry_after_is_the_longer_wait(client, monkeypatch, no_ip_limit):
    monkeypatch.setattr(settings, "trusted_proxy_hops", 1)
    monkeypatch.setattr(limits.signin_email_failures, "limit", 5)
    signup(client)
    for _ in range(5):
        err(_signin_from(client, "198.51.100.77"), 401, "invalid_credentials")
    e = err(_signin_from(client, "198.51.100.77", password=PASSWORD), 429, "rate_limited")
    assert 900 < e["retry_after_s"] <= 3600


def test_l5_per_email_cap_is_50_an_hour():
    assert limits.SIGNIN_EMAIL_HOURLY_FAILURES == 50
    assert limits.signin_email_failures.limit == 50 and limits.signin_email_failures.window_s == 3600


def test_l5_successful_signins_feed_neither_limiter(client, monkeypatch, no_ip_limit):
    monkeypatch.setattr(limits.signin_email_failures, "limit", 3)
    signup(client)
    for _ in range(6):
        assert _signin_from(client, "203.0.113.40", password=PASSWORD).status_code == 200


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


def test_m1_one_ip_gets_40_chats_a_day_across_accounts(chat_h, monkeypatch, no_ip_limit):
    monkeypatch.setattr(chat_service.ip_daily, "limit", settings.chat_ip_daily_cap)
    monkeypatch.setattr(settings, "trusted_proxy_hops", 1)
    xff = {"X-Forwarded-For": "198.51.100.1, 203.0.113.50"}
    second = bearer(signup(chat_h.client, email="second@example.com"))
    third = bearer(signup(chat_h.client, email="third@example.com"))
    for headers in ({**chat_h.headers, **xff}, {**second, **xff}):
        for _ in range(20):
            assert chat_h.post(install_id=None, headers=headers).status_code == 200
    e = err(chat_h.post(install_id=None, headers={**third, **xff}), 429, "rate_limited")
    assert e["details"] == {"scope": "ip"}
    # another client IP is not affected, and the global cap (200) was never the limit
    assert chat_h.post(install_id=None, headers={**third, "X-Forwarded-For": "203.0.113.51"}).status_code == 200


def test_m1_only_200_replies_count_per_ip(chat_h, monkeypatch):
    monkeypatch.setattr(chat_service.ip_daily, "limit", 2)
    chat_h.providers = [failing("openrouter")]
    for _ in range(3):
        assert chat_h.post(install_id=None).status_code == 503
    chat_h.providers = [FakeProvider("openrouter", [GOOD])]
    assert [chat_h.post(install_id=None).status_code for _ in range(3)] == [200, 200, 429]


# ---------- M3: the reset and deletion mails cannot be used as a mail flood ----------

def test_m3_reset_and_delete_requests_share_one_daily_limit_per_address(client, outbox, no_ip_limit):
    signup(client)
    for _ in range(3):  # the documented 3 per hour of forgot-password still applies
        assert client.post("/v1/auth/forgot-password", json={"email": "ada@example.com"}).status_code == 202
    for _ in range(2):
        assert client.post("/account/delete/request", data={"email": "ada@example.com"}).status_code == 200
    assert len(outbox.mails) == 5
    r = client.post("/account/delete/request", data={"email": "ada@example.com"})
    assert r.status_code == 429 and "Too many requests" in r.text
    assert len(outbox.mails) == 5
    # another address is not affected
    signup(client, email="bob@example.org")
    assert client.post("/v1/auth/forgot-password", json={"email": "bob@example.org"}).status_code == 202


def test_m3_forgot_password_past_the_shared_daily_limit_is_429(client, no_ip_limit):
    for _ in range(3):
        client.post("/account/delete/request", data={"email": "nobody@example.com"})
    for _ in range(2):
        assert client.post("/v1/auth/forgot-password", json={"email": "nobody@example.com"}).status_code == 202
    e = err(client.post("/v1/auth/forgot-password", json={"email": "nobody@example.com"}), 429, "rate_limited")
    assert e["details"] == {"scope": "account"}


def test_m3_global_mail_budget_drops_mail_and_warns(client, outbox, monkeypatch, caplog, no_ip_limit):
    monkeypatch.setattr(limits.mail_budget, "limit", 2)
    for i in range(3):
        signup(client, email=f"user{i}@example.com")
    with caplog.at_level(logging.WARNING, logger="maximus.mail"):
        for i in range(3):  # the response never says whether a mail went out
            assert client.post("/v1/auth/forgot-password", json={"email": f"user{i}@example.com"}).status_code == 202
    assert [m.to for m in outbox.mails] == ["user0@example.com", "user1@example.com"]
    assert "mail daily budget reached" in caplog.text and "user2" not in caplog.text


# ---------- L6: history past retention is never served, even before a purge ----------

def test_l6_expired_history_is_not_served_or_used_as_context(chat_h, monkeypatch):
    from app.services.chat import usage
    monkeypatch.setattr(usage, "_last_purge", chat_h.now.date())  # no purge has run (lazy or job)
    chat_h.seed_history([("user", "old question"), ("assistant", "old answer")], start=chat_h.now - timedelta(days=6))
    chat_h.seed_history([("user", "new question"), ("assistant", "new answer")], start=chat_h.now - timedelta(hours=1))
    page = chat_h.client.get("/v1/me/chat/roman-history", headers=chat_h.headers).json()
    assert [m["text"] for m in page["messages"]] == ["new question", "new answer"] and page["has_more"] is False
    assert chat_h.post().status_code == 200
    sent = repr(chat_h.fake.calls[-1][1])
    assert "new question" in sent and "old question" not in sent
    assert ("user", "old question", None) in chat_h.stored()  # still in the table until the purge deletes it


# ---------- L7: SQL errors do not carry bound parameters into the logs ----------

def test_l7_db_errors_hide_parameters(tmp_path):
    from sqlalchemy import text
    from sqlalchemy.exc import IntegrityError

    from app.db import make_engine
    engine = make_engine(f"sqlite:///{(tmp_path / 'l7.db').as_posix()}")
    with engine.begin() as conn:
        conn.execute(text("CREATE TABLE t (email TEXT UNIQUE)"))
        conn.execute(text("INSERT INTO t VALUES (:e)"), {"e": "ada@example.com"})
    with pytest.raises(IntegrityError) as exc, engine.begin() as conn:
        conn.execute(text("INSERT INTO t VALUES (:e)"), {"e": "ada@example.com"})
    assert "ada@example.com" not in str(exc.value) and "hidden" in str(exc.value)
    engine.dispose()


# ---------- L4: no DB connection is held while the providers run ----------

def test_l4_connection_returned_to_the_pool_during_provider_calls(chat_h, seeded):
    pool = seeded.kw["bind"].pool
    seen = []

    def answer(system, turns):
        seen.append(pool.checkedout())
        return GOOD
    chat_h.providers = [FakeProvider("openrouter", fn=answer)]
    assert chat_h.post().status_code == 200
    assert seen == [0]
    assert chat_h.stored()[-1][2] == "answer"  # the writes after the call still land


# ---------- L3: rate-limiter keys are evicted ----------

def test_l3_limiter_memory_is_bounded(monkeypatch):
    from app.services import ratelimit
    lim = ratelimit.RateLimiter(2, 60)
    monkeypatch.setattr(lim, "MAX_KEYS", 10)
    clock = {"t": 1000.0}
    monkeypatch.setattr(ratelimit.time, "monotonic", lambda: clock["t"])
    for i in range(10):
        lim.check(f"old{i}")
    clock["t"] += 61  # every old key has expired
    lim.check("new")
    assert set(lim.hits) == {"new"}  # expired keys go first, nothing live is lost
    for i in range(20):
        lim.check(f"live{i}")
    assert len(lim.hits) <= 10 and "live19" in lim.hits
    lim.check("live19")
    with pytest.raises(ApiError):
        lim.check("live19")  # a live key still counts


def test_l3_failure_only_limiter_drops_expired_keys(monkeypatch):
    from app.services import ratelimit
    lim = ratelimit.RateLimiter(5, 60)
    clock = {"t": 1000.0}
    monkeypatch.setattr(ratelimit.time, "monotonic", lambda: clock["t"])
    lim.add("ada@example.com")
    clock["t"] += 61
    lim.ensure_open("ada@example.com")
    assert lim.hits == {}
