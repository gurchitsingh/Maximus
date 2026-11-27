"""Account rules (CONTRACTS 14, 17). Functions take a session and `now`, and return what the route sends plus
the mails to deliver after the response (so timing does not depend on whether a mail goes out)."""
import logging
import re
import uuid
from datetime import datetime, timedelta

from sqlalchemy import delete, select, update
from sqlalchemy.exc import IntegrityError
from sqlalchemy.orm import Session

from app.errors import ApiError
from app.models import (ChatUsage, EmailToken, RefreshToken, User, UserChatMessage, UserRecord)
from app.services.auth import mailer, passwords, tokens
from app.services.auth.google import GoogleIdentity

log = logging.getLogger("maximus.auth")
EMAIL_RE = re.compile(r"^[^@\s]{1,64}@[^@\s]+\.[^@\s]+$")
FRESH_FOR_DELETE = timedelta(minutes=5)


def z(dt: datetime) -> str:
    return dt.strftime("%Y-%m-%dT%H:%M:%SZ")


def normalise_email(email) -> str:
    if not isinstance(email, str):
        raise _bad_email()
    e = email.strip().lower()
    if len(e) > 254 or not EMAIL_RE.match(e):
        raise _bad_email()
    return e


def _bad_email() -> ApiError:
    return ApiError(422, "validation_error", "Enter a valid email address.",
                    details={"fields": [{"loc": "body.email", "msg": "not a valid email address"}]})


def clean_name(name) -> str | None:
    if name is None:
        return None
    name = " ".join(str(name).split())
    return name[:80] or None


def user_json(u: User) -> dict:
    return {"id": str(u.id), "email": u.email, "display_name": u.display_name, "has_password": u.password_hash is not None,
            "has_google": u.google_sub is not None, "created_at": z(u.created_at)}


def _issue(db: Session, user: User, now: datetime, family_id: uuid.UUID | None = None) -> dict:
    refresh = tokens.new_opaque()
    db.add(RefreshToken(user_id=user.id, token_hash=tokens.hash_opaque(refresh), family_id=family_id or uuid.uuid4(),
                        expires_at=now + tokens.REFRESH_TTL, created_at=now))
    db.commit()
    return {"user": user_json(user), "access_token": tokens.issue_access(user.id, now), "refresh_token": refresh,
            "expires_in": tokens.ACCESS_TTL_S}


def _email_token(db: Session, user: User, purpose: str, now: datetime) -> str:
    raw = tokens.new_opaque()
    db.add(EmailToken(user_id=user.id, purpose=purpose, token_hash=tokens.hash_opaque(raw),
                      expires_at=now + tokens.EMAIL_TTL[purpose], created_at=now))
    db.commit()
    return raw


def revoke_all(db: Session, user_id: uuid.UUID, now: datetime) -> None:
    """Every session of the user: the refresh tokens, and (M2) every access token issued before now, which
    current_principal refuses by comparing its iat with users.tokens_valid_after. The caller commits."""
    db.execute(update(RefreshToken).where(RefreshToken.user_id == user_id, RefreshToken.revoked_at.is_(None))
               .values(revoked_at=now))
    db.execute(update(User).where(User.id == user_id).values(tokens_valid_after=now))


def find_by_email(db: Session, email: str) -> User | None:
    return db.scalar(select(User).where(User.email == email))


# ---------- sign up / sign in ----------

def signup(db: Session, email, password, display_name, now: datetime) -> dict:
    """No email verification (D48): a valid email and a strong password create the account and sign the user in."""
    email = normalise_email(email)
    passwords.check_strength(password)
    existing = find_by_email(db, email)
    if existing is not None:
        raise _email_taken(existing)
    user = User(email=email, password_hash=passwords.hash_password(password),
                display_name=clean_name(display_name), created_at=now)
    db.add(user)
    try:
        db.commit()
    except IntegrityError:  # a concurrent sign-up with the same email
        db.rollback()
        raise _email_taken(find_by_email(db, email))
    return _issue(db, user, now)


def _email_taken(u: User | None) -> ApiError:
    details = {"method": "google"} if u is not None and u.password_hash is None and u.google_sub else None
    return ApiError(409, "email_taken", "An account with this email already exists.", details=details)


def signin(db: Session, email, password, now: datetime, failure_limits) -> dict:
    """`failure_limits(email)` gives the failure limiters and their keys (limits.signin_keys, L5: per email and
    IP, plus a looser per email): all are checked first, and fed only on a wrong email or password. When more than
    one is full, the 429 gives the longest wait, so the client does not retry into another 429."""
    try:
        email = normalise_email(email)
    except ApiError:
        raise ApiError(401, "invalid_credentials", "Wrong email or password.")
    locks = failure_limits(email)
    full = []
    for limiter, key in locks:
        try:
            limiter.ensure_open(key)
        except ApiError as e:
            full.append(e)
    if full:
        raise max(full, key=lambda e: e.retry_after_s or 0)
    user = find_by_email(db, email)
    ok = passwords.verify(user.password_hash if user else None, password if isinstance(password, str) else "")
    if not ok or user is None:
        for limiter, key in locks:
            limiter.add(key)
        raise ApiError(401, "invalid_credentials", "Wrong email or password.")
    if passwords.needs_rehash(user.password_hash):
        user.password_hash = passwords.hash_password(password)
    return _issue(db, user, now)


def google_signin(db: Session, ident: GoogleIdentity, now: datetime) -> dict:
    """14.3: by google_sub; else link by verified email (password accounts only for Gmail or Workspace, M4); else
    create."""
    user = db.scalar(select(User).where(User.google_sub == ident.sub))
    if user is None:
        user = find_by_email(db, ident.email)
        if user is not None:
            if user.google_sub is not None:  # that email belongs to another Google identity
                raise ApiError(409, "email_taken", "An account with this email already exists.",
                               details={"method": "google"})
            if user.password_hash is not None:
                if not ident.owns_email:
                    # M4: outside Gmail and Workspace, Google does not prove the address is controlled today, so a
                    # password account is never taken over. The user signs in with the password instead.
                    raise ApiError(409, "email_taken", "An account with this email already exists.",
                                   details={"method": "password"})
                # Sign-up never proves ownership of the address (D48), so Google wins: a password set by someone
                # else must not survive the link (account pre-hijacking, D45). Google has just proved ownership.
                user.password_hash = None
                revoke_all(db, user.id, now)
                log.info("google link cleared a password")
            user.google_sub = ident.sub
            user.display_name = user.display_name or ident.name
        else:
            user = User(email=ident.email, google_sub=ident.sub, password_hash=None,
                        display_name=ident.name, created_at=now)
            db.add(user)
        try:
            db.commit()
        except IntegrityError:  # a concurrent first sign-in
            db.rollback()
            user = db.scalar(select(User).where(User.google_sub == ident.sub))
            if user is None:
                raise ApiError(409, "email_taken", "An account with this email already exists.")
    return _issue(db, user, now)


# ---------- refresh / sign out ----------

def refresh(db: Session, raw, now: datetime) -> dict:
    if not isinstance(raw, str) or not raw:
        raise _token_invalid()
    row = db.scalar(select(RefreshToken).where(RefreshToken.token_hash == tokens.hash_opaque(raw)))
    if row is None or row.expires_at <= now:
        raise _token_invalid()
    if row.revoked_at is not None:
        revoke_all(db, row.user_id, now)
        db.commit()
        log.warning("refresh token reused: all sessions of the user revoked")
        raise ApiError(401, "token_reused", "This session was signed out. Sign in again.")
    # Revoke exactly once: of two concurrent refreshes with one token, only one wins.
    won = db.execute(update(RefreshToken).where(RefreshToken.id == row.id, RefreshToken.revoked_at.is_(None))
                     .values(revoked_at=now)).rowcount
    if won != 1:
        db.rollback()
        raise ApiError(401, "token_reused", "This session was signed out. Sign in again.")
    user = db.get(User, row.user_id)
    return _issue(db, user, now, family_id=row.family_id)


def signout(db: Session, raw, now: datetime) -> None:
    if isinstance(raw, str) and raw:
        db.execute(update(RefreshToken).where(RefreshToken.token_hash == tokens.hash_opaque(raw),
                                              RefreshToken.revoked_at.is_(None)).values(revoked_at=now))
        db.commit()


def _token_invalid() -> ApiError:
    return ApiError(401, "token_invalid", "This link or session is no longer valid.")


# ---------- email tokens ----------

def use_email_token(db: Session, raw, purpose: str, now: datetime, consume: bool = True) -> EmailToken:
    if not isinstance(raw, str) or not raw or len(raw) > 200:
        raise _token_invalid()
    row = db.scalar(select(EmailToken).where(EmailToken.token_hash == tokens.hash_opaque(raw),
                                             EmailToken.purpose == purpose))
    if row is None or row.used_at is not None or row.expires_at <= now:
        raise _token_invalid()
    if consume:
        won = db.execute(update(EmailToken).where(EmailToken.id == row.id, EmailToken.used_at.is_(None))
                         .values(used_at=now)).rowcount
        if won != 1:
            db.rollback()
            raise _token_invalid()
    return row


def forgot_password(db: Session, email: str, now: datetime) -> list[mailer.Mail]:
    user = find_by_email(db, email)
    if user is None:
        return []
    if user.password_hash is None:
        return [mailer.reset_google_mail(email)]
    return [mailer.reset_mail(email, _email_token(db, user, "reset", now))]


def reset_password(db: Session, raw, new_password, now: datetime) -> None:
    passwords.check_strength(new_password)
    row = use_email_token(db, raw, "reset", now)
    user = db.get(User, row.user_id)
    user.password_hash = passwords.hash_password(new_password)
    db.execute(update(EmailToken).where(EmailToken.user_id == user.id, EmailToken.purpose == "reset",
                                        EmailToken.used_at.is_(None)).values(used_at=now))
    revoke_all(db, user.id, now)
    db.commit()


# ---------- deletion (17) ----------

def check_delete_allowed(user: User, password, claims: dict, now: datetime) -> None:
    """Email accounts send their password; Google accounts need an access token younger than 5 minutes."""
    if password is not None:
        if user.password_hash is None or not passwords.verify(user.password_hash, password):
            raise ApiError(401, "invalid_credentials", "Wrong password.")
        return
    if user.password_hash is not None and user.google_sub is None:
        raise ApiError(403, "reauth_required", "Enter your password to delete the account.")
    if now.timestamp() - claims["iat"] > FRESH_FOR_DELETE.total_seconds():
        raise ApiError(403, "reauth_required", "Sign in again, then delete the account.")


def delete_user(db: Session, user_id: uuid.UUID) -> None:
    """One transaction, hard delete, no copy kept (17)."""
    for model in (RefreshToken, EmailToken, UserRecord, UserChatMessage, ChatUsage):
        db.execute(delete(model).where(model.user_id == user_id))
    db.execute(delete(User).where(User.id == user_id))
    db.commit()
    log.info("account deleted")


def request_delete_link(db: Session, email: str, now: datetime) -> list[mailer.Mail]:
    user = find_by_email(db, email)
    if user is None:
        return []
    return [mailer.delete_mail(email, _email_token(db, user, "delete", now))]


def confirm_delete_link(db: Session, raw, now: datetime) -> None:
    row = use_email_token(db, raw, "delete", now)
    delete_user(db, row.user_id)
