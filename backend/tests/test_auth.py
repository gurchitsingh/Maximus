"""Accounts and auth (CONTRACTS 14). No network: Google keys are a local RSA pair, mail goes to an outbox."""
import logging
import uuid
from datetime import timedelta

import jwt
import pytest
from sqlalchemy import select

from app.config import Settings, check_startup, startup_problems
from app.models import EmailToken, RefreshToken, User
from app.services.auth import limits, passwords, tokens
from tests.auth_helpers import PASSWORD, bearer, signup


def err(r, status, code):
    assert r.status_code == status, r.text
    assert r.json()["error"]["code"] == code, r.text
    return r.json()["error"]


@pytest.fixture
def no_ip_limit(monkeypatch):
    """Most tests make more than 10 auth calls; the IP limit has its own test."""
    monkeypatch.setattr(limits.auth_ip, "limit", 10_000)


@pytest.fixture
def at(monkeypatch):
    """Freeze the server clock; at(seconds) moves it forward from the frozen start."""
    base = tokens.utcnow()
    shift = {"s": 0}
    monkeypatch.setattr(tokens, "utcnow", lambda: base + timedelta(seconds=shift["s"]))

    def move(seconds):
        shift["s"] = seconds
    return move


def rows(seeded, model):
    with seeded() as db:
        return list(db.scalars(select(model)))


# ---------- sign up ----------

def test_signup_returns_auth_result_and_sends_verification(client, outbox):
    d = signup(client, email="  Ada@Example.COM ", name="  Ada   Lovelace ")
    assert set(d) == {"user", "access_token", "refresh_token", "expires_in"} and d["expires_in"] == 900
    u = d["user"]
    assert set(u) == {"id", "email", "email_verified", "display_name", "has_password", "has_google", "created_at"}
    assert u["email"] == "ada@example.com" and u["email_verified"] is False and u["display_name"] == "Ada Lovelace"
    assert u["has_password"] is True and u["has_google"] is False and u["created_at"].endswith("Z")
    uuid.UUID(u["id"])
    mail = outbox.last("verify")
    assert mail.to == "ada@example.com" and "/verify-email?token=" in mail.text
    assert client.get("/v1/me", headers=bearer(d)).json() == u


def test_signup_duplicate_email_is_taken(client, no_ip_limit):
    signup(client)
    e = err(client.post("/v1/auth/signup", json={"email": "ADA@example.com", "password": PASSWORD}), 409,
            "email_taken")
    assert e["details"] is None


def test_signup_on_google_only_email_says_use_google(client, google, no_ip_limit):
    client.post("/v1/auth/google", json={"id_token": google.token()})
    e = err(client.post("/v1/auth/signup", json={"email": "ada@example.com", "password": PASSWORD}), 409,
            "email_taken")
    assert e["details"] == {"method": "google"}


@pytest.mark.parametrize("pw", ["short", "x" * 9, "x" * 129])
def test_weak_password(client, pw):
    err(client.post("/v1/auth/signup", json={"email": "ada@example.com", "password": pw}), 422, "weak_password")


@pytest.mark.parametrize("pw", ["x" * 10, "x" * 128, "ten chars!"])
def test_password_bounds_accepted(client, pw, no_ip_limit):
    signup(client, email=f"p{len(pw)}{pw[-1] == '!'}@example.com", password=pw)


@pytest.mark.parametrize("email", ["", "no-at-sign", "a@b", "a b@example.com", "x" * 250 + "@example.com"])
def test_bad_email_is_validation_error(client, email):
    err(client.post("/v1/auth/signup", json={"email": email, "password": PASSWORD}), 422, "validation_error")


def test_missing_fields_are_validation_error(client):
    err(client.post("/v1/auth/signup", json={"email": "ada@example.com"}), 422, "validation_error")


def test_password_is_argon2id_with_owasp_params(client, seeded):
    signup(client)
    (u,) = rows(seeded, User)
    assert u.password_hash.startswith("$argon2id$v=19$m=19456,t=2,p=1$")
    assert PASSWORD not in u.password_hash


def test_passwords_and_tokens_never_logged(client, caplog, outbox, no_ip_limit):
    caplog.set_level(logging.DEBUG)
    d = signup(client)
    client.post("/v1/auth/signin", json={"email": "ada@example.com", "password": "wrong password!"})
    client.post("/v1/auth/refresh", json={"refresh_token": d["refresh_token"]})
    text = caplog.text
    assert PASSWORD not in text and "wrong password!" not in text
    assert d["refresh_token"] not in text and d["access_token"] not in text


# ---------- sign in ----------

def test_signin_ok(client, no_ip_limit):
    d0 = signup(client)
    d = client.post("/v1/auth/signin", json={"email": " ADA@example.com", "password": PASSWORD}).json()
    assert d["user"]["id"] == d0["user"]["id"] and d["refresh_token"] != d0["refresh_token"]


def test_signin_wrong_password_and_unknown_email_look_the_same(client, no_ip_limit):
    signup(client)
    a = err(client.post("/v1/auth/signin", json={"email": "ada@example.com", "password": "nope nope nope"}),
            401, "invalid_credentials")
    b = err(client.post("/v1/auth/signin", json={"email": "bob@example.com", "password": "nope nope nope"}),
            401, "invalid_credentials")
    assert a == b


def test_signin_google_only_account_has_no_password(client, google, no_ip_limit):
    client.post("/v1/auth/google", json={"id_token": google.token()})
    err(client.post("/v1/auth/signin", json={"email": "ada@example.com", "password": PASSWORD}), 401,
        "invalid_credentials")


def test_signin_five_failures_lock_the_email_for_15_minutes(client, no_ip_limit):
    signup(client)
    for _ in range(5):
        err(client.post("/v1/auth/signin", json={"email": "ada@example.com", "password": "bad bad bad"}), 401,
            "invalid_credentials")
    r = client.post("/v1/auth/signin", json={"email": "ada@example.com", "password": PASSWORD})
    e = err(r, 429, "rate_limited")
    assert e["details"] == {"scope": "account"} and 0 < int(r.headers["Retry-After"]) <= 900
    # another email is not locked
    err(client.post("/v1/auth/signin", json={"email": "bob@example.com", "password": "bad bad bad"}), 401,
        "invalid_credentials")


def test_successful_signins_do_not_count_as_failures(client, no_ip_limit):
    signup(client)
    for _ in range(8):
        assert client.post("/v1/auth/signin", json={"email": "ada@example.com", "password": PASSWORD}).status_code == 200


def test_auth_routes_limited_to_10_per_minute_per_ip(client):
    for _ in range(10):
        client.post("/v1/auth/signout", json={"refresh_token": "x"})
    r = client.post("/v1/auth/signin", json={"email": "ada@example.com", "password": PASSWORD})
    assert err(r, 429, "rate_limited")["details"] == {"scope": "ip"} and "Retry-After" in r.headers


# ---------- access tokens ----------

def test_me_requires_bearer(client):
    err(client.get("/v1/me"), 401, "unauthorized")
    err(client.get("/v1/me", headers={"Authorization": "Basic abc"}), 401, "unauthorized")
    err(client.get("/v1/me", headers={"Authorization": "Bearer not.a.jwt"}), 401, "unauthorized")


def test_access_token_claims(client):
    d = signup(client)
    claims = jwt.decode(d["access_token"], options={"verify_signature": False})
    assert set(claims) == {"sub", "iat", "exp", "jti", "iss"} and claims["iss"] == "maximus"
    assert claims["exp"] - claims["iat"] == 900 and claims["sub"] == d["user"]["id"]


def test_access_token_expires_after_15_minutes(client, at):
    d = signup(client)
    at(899)
    assert client.get("/v1/me", headers=bearer(d)).status_code == 200
    at(900)
    err(client.get("/v1/me", headers=bearer(d)), 401, "token_expired")


def test_forged_and_alg_none_tokens_rejected(client):
    d = signup(client)
    claims = jwt.decode(d["access_token"], options={"verify_signature": False})
    forged = jwt.encode(claims, "another-secret-that-is-long-enough-123", algorithm="HS256")
    err(client.get("/v1/me", headers=bearer(forged)), 401, "unauthorized")
    none = jwt.encode(claims, None, algorithm="none")
    err(client.get("/v1/me", headers=bearer(none)), 401, "unauthorized")


def test_token_with_wrong_issuer_rejected(client):
    from app.config import settings
    d = signup(client)
    claims = jwt.decode(d["access_token"], options={"verify_signature": False})
    claims["iss"] = "someone-else"
    err(client.get("/v1/me", headers=bearer(jwt.encode(claims, settings.jwt_secret, algorithm="HS256"))), 401,
        "unauthorized")


# ---------- refresh rotation ----------

def test_refresh_rotates(client, seeded, no_ip_limit):
    d = signup(client)
    r = client.post("/v1/auth/refresh", json={"refresh_token": d["refresh_token"]})
    assert r.status_code == 200
    n = r.json()
    assert n["user"] == d["user"] and n["refresh_token"] != d["refresh_token"]
    assert client.get("/v1/me", headers=bearer(n)).status_code == 200
    stored = rows(seeded, RefreshToken)
    assert len(stored) == 2 and len({t.family_id for t in stored}) == 1
    assert all(t.token_hash != d["refresh_token"] and len(t.token_hash) == 64 for t in stored)  # hashes only


def test_refresh_reuse_revokes_every_session(client, seeded, no_ip_limit):
    d = signup(client)
    other = client.post("/v1/auth/signin", json={"email": "ada@example.com", "password": PASSWORD}).json()
    n = client.post("/v1/auth/refresh", json={"refresh_token": d["refresh_token"]}).json()
    err(client.post("/v1/auth/refresh", json={"refresh_token": d["refresh_token"]}), 401, "token_reused")
    err(client.post("/v1/auth/refresh", json={"refresh_token": n["refresh_token"]}), 401, "token_reused")
    err(client.post("/v1/auth/refresh", json={"refresh_token": other["refresh_token"]}), 401, "token_reused")
    assert all(t.revoked_at is not None for t in rows(seeded, RefreshToken))


def test_refresh_unknown_or_expired_is_token_invalid(client, at, no_ip_limit):
    d = signup(client)
    err(client.post("/v1/auth/refresh", json={"refresh_token": "nope"}), 401, "token_invalid")
    at(60 * 86400 + 1)
    err(client.post("/v1/auth/refresh", json={"refresh_token": d["refresh_token"]}), 401, "token_invalid")


def test_refresh_window_rolls_forward(client, at, no_ip_limit):
    d = signup(client)
    at(59 * 86400)
    n = client.post("/v1/auth/refresh", json={"refresh_token": d["refresh_token"]}).json()
    at(100 * 86400)  # 41 days after the second token was issued
    assert client.post("/v1/auth/refresh", json={"refresh_token": n["refresh_token"]}).status_code == 200


def test_signout_revokes_and_is_idempotent(client, no_ip_limit):
    d = signup(client)
    assert client.post("/v1/auth/signout", json={"refresh_token": d["refresh_token"]}).status_code == 204
    assert client.post("/v1/auth/signout", json={"refresh_token": d["refresh_token"]}).status_code == 204
    assert client.post("/v1/auth/signout", json={"refresh_token": "unknown"}).status_code == 204
    err(client.post("/v1/auth/refresh", json={"refresh_token": d["refresh_token"]}), 401, "token_reused")


# ---------- email verification ----------

def test_verify_email_is_one_use(client, outbox, no_ip_limit):
    d = signup(client)
    token = outbox.token("verify")
    assert client.post("/v1/auth/verify-email", json={"token": token}).status_code == 204
    assert client.get("/v1/me", headers=bearer(d)).json()["email_verified"] is True
    err(client.post("/v1/auth/verify-email", json={"token": token}), 401, "token_invalid")


def test_verify_token_expires_after_24_hours(client, outbox, at):
    signup(client)
    at(24 * 3600 + 1)
    err(client.post("/v1/auth/verify-email", json={"token": outbox.token("verify")}), 401, "token_invalid")


def test_reset_token_cannot_verify_email(client, outbox, no_ip_limit):
    signup(client)
    client.post("/v1/auth/forgot-password", json={"email": "ada@example.com"})
    err(client.post("/v1/auth/verify-email", json={"token": outbox.token("reset")}), 401, "token_invalid")


def test_resend_verification(client, outbox, no_ip_limit):
    d = signup(client)
    err(client.post("/v1/auth/resend-verification"), 401, "unauthorized")
    assert client.post("/v1/auth/resend-verification", headers=bearer(d)).status_code == 202
    assert len([m for m in outbox.mails if m.purpose == "verify"]) == 2
    r = client.post("/v1/auth/resend-verification", headers=bearer(d))
    assert err(r, 429, "rate_limited")["details"] == {"scope": "account"}


def test_resend_after_verified_sends_nothing(client, outbox, no_ip_limit):
    d = signup(client)
    client.post("/v1/auth/verify-email", json={"token": outbox.token("verify")})
    outbox.mails.clear()
    assert client.post("/v1/auth/resend-verification", headers=bearer(d)).status_code == 202
    assert outbox.mails == []


# ---------- password reset ----------

def test_forgot_password_never_reveals_the_email(client, outbox, google, no_ip_limit):
    signup(client)
    client.post("/v1/auth/google", json={"id_token": google.token(sub="g-9", email="gina@example.org")})
    outbox.mails.clear()
    for email in ("ada@example.com", "nobody@example.com", "gina@example.org"):
        r = client.post("/v1/auth/forgot-password", json={"email": email})
        assert r.status_code == 202 and r.content == b""
    assert [(m.to, m.purpose) for m in outbox.mails] == [("ada@example.com", "reset"),
                                                         ("gina@example.org", "reset_google")]


def test_forgot_password_three_per_hour_per_email(client, no_ip_limit):
    for _ in range(3):
        assert client.post("/v1/auth/forgot-password", json={"email": "nobody@example.com"}).status_code == 202
    r = client.post("/v1/auth/forgot-password", json={"email": "NOBODY@example.com"})
    assert err(r, 429, "rate_limited")["details"] == {"scope": "account"}


def test_reset_password_flow(client, outbox, seeded, no_ip_limit):
    d = signup(client)
    client.post("/v1/auth/forgot-password", json={"email": "ada@example.com"})
    token = outbox.token("reset")
    err(client.post("/v1/auth/reset-password", json={"token": token, "new_password": "short"}), 422,
        "weak_password")
    assert client.post("/v1/auth/reset-password", json={"token": token, "new_password": "a brand new pass"}
                       ).status_code == 204
    err(client.post("/v1/auth/reset-password", json={"token": token, "new_password": "a brand new pass"}), 401,
        "token_invalid")
    # every refresh token revoked; old password gone, new one works
    err(client.post("/v1/auth/refresh", json={"refresh_token": d["refresh_token"]}), 401, "token_reused")
    err(client.post("/v1/auth/signin", json={"email": "ada@example.com", "password": PASSWORD}), 401,
        "invalid_credentials")
    n = client.post("/v1/auth/signin", json={"email": "ada@example.com", "password": "a brand new pass"})
    assert n.status_code == 200 and n.json()["user"]["email_verified"] is True


def test_reset_link_expires_after_one_hour(client, outbox, at, no_ip_limit):
    signup(client)
    client.post("/v1/auth/forgot-password", json={"email": "ada@example.com"})
    at(3601)
    err(client.post("/v1/auth/reset-password", json={"token": outbox.token("reset"), "new_password": "x" * 12}),
        401, "token_invalid")


def test_email_tokens_stored_as_hashes(client, outbox, seeded):
    signup(client)
    token = outbox.token("verify")
    (t,) = rows(seeded, EmailToken)
    assert t.token_hash == tokens.hash_opaque(token) and t.purpose == "verify"


# ---------- Google ----------

def test_google_creates_account(client, google):
    r = client.post("/v1/auth/google", json={"id_token": google.token(name="Ada L")})
    assert r.status_code == 200
    u = r.json()["user"]
    assert u["email"] == "ada@example.com" and u["email_verified"] is True and u["has_google"] is True
    assert u["has_password"] is False and u["display_name"] == "Ada L"


def test_google_signs_in_by_sub_even_if_email_changed(client, google, no_ip_limit):
    a = client.post("/v1/auth/google", json={"id_token": google.token()}).json()
    b = client.post("/v1/auth/google", json={"id_token": google.token(email="new@example.com")}).json()
    assert a["user"]["id"] == b["user"]["id"]


def test_google_links_verified_email_account_and_keeps_password(client, google, outbox, no_ip_limit):
    d = signup(client)
    client.post("/v1/auth/verify-email", json={"token": outbox.token("verify")})
    g = client.post("/v1/auth/google", json={"id_token": google.token()}).json()
    assert g["user"]["id"] == d["user"]["id"] and g["user"]["has_password"] and g["user"]["has_google"]
    assert client.post("/v1/auth/signin", json={"email": "ada@example.com", "password": PASSWORD}).status_code == 200
    assert client.post("/v1/auth/refresh", json={"refresh_token": d["refresh_token"]}).status_code == 200


def test_google_link_drops_an_unverified_password(client, google, no_ip_limit):
    """Pre-hijack: someone signs up with another person's address; the owner then uses Google."""
    squatter = signup(client)
    g = client.post("/v1/auth/google", json={"id_token": google.token()}).json()
    assert g["user"]["id"] == squatter["user"]["id"] and g["user"]["has_password"] is False
    err(client.post("/v1/auth/signin", json={"email": "ada@example.com", "password": PASSWORD}), 401,
        "invalid_credentials")
    err(client.post("/v1/auth/refresh", json={"refresh_token": squatter["refresh_token"]}), 401, "token_reused")


@pytest.mark.parametrize("kw", [
    {"aud": "someone-else.apps.googleusercontent.com"},
    {"iss": "https://evil.example.com"},
    {"exp_in": -120},
    {"verified": False},
    {"kid": "unknown-kid"},
    {"email": None},
])
def test_google_token_checks(client, google, kw):
    err(client.post("/v1/auth/google", json={"id_token": google.token(**kw)}), 401, "google_token_invalid")


def test_google_token_signed_by_another_key(client, google):
    from cryptography.hazmat.primitives.asymmetric import rsa
    other = rsa.generate_private_key(public_exponent=65537, key_size=2048)
    err(client.post("/v1/auth/google", json={"id_token": google.token(key=other)}), 401, "google_token_invalid")


def test_google_hs256_token_with_public_key_confusion_rejected(client, google):
    err(client.post("/v1/auth/google", json={"id_token": google.token(key="secret" * 6, alg="HS256")}), 401,
        "google_token_invalid")


def test_google_not_configured(client, google, monkeypatch):
    from app.config import settings
    monkeypatch.setattr(settings, "google_client_id", "")
    err(client.post("/v1/auth/google", json={"id_token": google.token()}), 401, "google_token_invalid")


def test_google_keys_are_cached(google, monkeypatch):
    from app.config import settings
    from tests.auth_helpers import CLIENT_ID
    monkeypatch.setattr(settings, "google_client_id", CLIENT_ID)
    before = google.fetches
    google.verifier.verify(google.token())
    google.verifier.verify(google.token())
    assert google.fetches - before <= 1


# ---------- production start-up (D31 f, D44) ----------

def test_production_refuses_empty_secrets():
    s = Settings(_env_file=None, environment="production", jwt_secret="", install_id_salt="",
                 database_url="postgresql://u:p@db.example.com/x")
    assert startup_problems(s) == ["INSTALL_ID_SALT is empty", "JWT_SECRET is empty"]
    with pytest.raises(RuntimeError, match="Refusing to start"):
        check_startup(s)


def test_production_refuses_short_secret_and_sqlite():
    s = Settings(_env_file=None, environment="production", jwt_secret="short", install_id_salt="salt",
                 database_url="sqlite:///x.db")
    assert len(startup_problems(s)) == 2


def test_render_without_environment_counts_as_production():
    s = Settings(_env_file=None, environment="", render="true")
    assert s.is_production and startup_problems(s)
    assert not Settings(_env_file=None, environment="development", render="true").is_production


def test_production_with_everything_set_starts():
    s = Settings(_env_file=None, environment="production", jwt_secret="x" * 40, install_id_salt="salt",
                 database_url="postgresql://u:p@db.example.com/x")
    check_startup(s)


def test_development_gets_a_random_secret():
    s = Settings(_env_file=None, environment="development", jwt_secret="")
    check_startup(s)
    assert len(s.jwt_secret) >= 32


def test_database_url_normalised_for_psycopg():
    s = Settings(_env_file=None, database_url="postgres://u:p@h/db?sslmode=require")
    assert s.sqlalchemy_url == "postgresql+psycopg://u:p@h/db?sslmode=require"
    s = Settings(_env_file=None, database_url="postgresql://u:p@h/db", database_url_direct="postgresql://u:p@d/db")
    assert s.migration_url == "postgresql+psycopg://u:p@d/db"


def test_rehash_on_signin_when_params_change(client, seeded, monkeypatch, no_ip_limit):
    from argon2 import PasswordHasher
    signup(client)
    with seeded() as db:
        u = db.scalar(select(User))
        u.password_hash = PasswordHasher(time_cost=1, memory_cost=8 * 1024, parallelism=1).hash(PASSWORD)
        db.commit()
    assert client.post("/v1/auth/signin", json={"email": "ada@example.com", "password": PASSWORD}).status_code == 200
    (u,) = rows(seeded, User)
    assert not passwords.needs_rehash(u.password_hash)
