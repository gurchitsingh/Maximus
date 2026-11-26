"""Test doubles for accounts: an outbox mailer, a local Google key pair, and sign-up helpers.
Addresses use example.com / example.org only (RFC 2606); nothing leaves the process."""
import re
import time

import jwt
from cryptography.hazmat.primitives.asymmetric import rsa
from jwt.algorithms import RSAAlgorithm

from app.services.auth.google import GoogleKeys, GoogleVerifier
from app.services.auth.mailer import Mail

CLIENT_ID = "test-client.apps.googleusercontent.com"
PASSWORD = "correct horse battery"


class Outbox:
    name = "outbox"

    def __init__(self):
        self.mails: list[Mail] = []

    def send(self, mail: Mail) -> None:
        self.mails.append(mail)

    def last(self, purpose: str | None = None) -> Mail:
        found = [m for m in self.mails if purpose is None or m.purpose == purpose]
        assert found, f"no {purpose or ''} mail sent"
        return found[-1]

    def token(self, purpose: str) -> str:
        return re.search(r"token=([A-Za-z0-9_\-]+)", self.last(purpose).text).group(1)


class FakeGoogle:
    """Signs Google-shaped ID tokens with a local RSA key served as the JWKS."""

    def __init__(self):
        self.key = rsa.generate_private_key(public_exponent=65537, key_size=2048)
        jwk = RSAAlgorithm.to_jwk(self.key.public_key(), as_dict=True)
        jwk.update(kid="test-kid", alg="RS256", use="sig")
        self.fetches = 0

        def fetch():
            self.fetches += 1
            return {"keys": [jwk]}, 3600

        self.verifier = GoogleVerifier(GoogleKeys(fetch=fetch))

    def token(self, sub="g-123", email="ada@example.com", verified=True, aud=CLIENT_ID,
              iss="https://accounts.google.com", exp_in=3600, kid="test-kid", name="Ada", key=None, alg="RS256",
              hd=None):
        """hd: the Workspace domain claim (SECURITY_AUDIT M4: only Gmail or hd addresses may take a password
        account)."""
        now = int(time.time())
        claims = {"iss": iss, "aud": aud, "sub": sub, "email": email, "email_verified": verified,
                  "iat": now, "exp": now + exp_in, "name": name}
        if hd is not None:
            claims["hd"] = hd
        return jwt.encode(claims, key or self.key, algorithm=alg, headers={"kid": kid})


def signup(client, email="ada@example.com", password=PASSWORD, name=None):
    body = {"email": email, "password": password}
    if name is not None:
        body["display_name"] = name
    r = client.post("/v1/auth/signup", json=body)
    assert r.status_code == 201, r.text
    return r.json()


def bearer(result_or_token) -> dict:
    token = result_or_token["access_token"] if isinstance(result_or_token, dict) else result_or_token
    return {"Authorization": f"Bearer {token}"}
