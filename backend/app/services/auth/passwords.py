"""Argon2id password hashes (CONTRACTS 14.2): memory 19 MiB, 2 iterations, 1 lane (the OWASP minimum).
Passwords are never logged."""
from argon2 import PasswordHasher
from argon2.exceptions import InvalidHashError, VerificationError, VerifyMismatchError

from app.errors import ApiError

MIN_LEN, MAX_LEN = 10, 128
hasher = PasswordHasher(time_cost=2, memory_cost=19 * 1024, parallelism=1)
# Verified against when the email is unknown, so a miss costs about as long as a wrong password.
_DUMMY = hasher.hash("not-a-real-password-for-timing")


def check_strength(password: str) -> None:
    if not isinstance(password, str) or not MIN_LEN <= len(password) <= MAX_LEN:
        raise ApiError(422, "weak_password", f"Password must be {MIN_LEN} to {MAX_LEN} characters.",
                       details={"min": MIN_LEN, "max": MAX_LEN})


def hash_password(password: str) -> str:
    return hasher.hash(password)


def verify(stored_hash: str | None, password: str) -> bool:
    if not stored_hash:
        try:
            hasher.verify(_DUMMY, password)
        except VerificationError:
            pass
        return False
    try:
        return hasher.verify(stored_hash, password)
    except (VerifyMismatchError, VerificationError, InvalidHashError):
        return False


def needs_rehash(stored_hash: str) -> bool:
    try:
        return hasher.check_needs_rehash(stored_hash)
    except InvalidHashError:
        return True
