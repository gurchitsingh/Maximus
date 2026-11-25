"""/v1/auth/* and /v1/me (CONTRACTS 14.1, 17). Every /v1/auth/* call counts against 10 per minute per IP."""
from fastapi import APIRouter, BackgroundTasks, Depends, Request, Response
from fastapi.responses import JSONResponse
from pydantic import BaseModel, ConfigDict, Field
from sqlalchemy.orm import Session

from app.db import get_db
from app.services.auth import limits, mailer, service, tokens
from app.services.auth.deps import Principal, client_ip, current_principal, current_user
from app.services.auth.google import GoogleVerifier, default_verifier
from app.models import User

NO_STORE = {"Cache-Control": "no-store"}


def auth_ip_limit(request: Request) -> None:
    limits.auth_ip.check(client_ip(request))


def get_mailer() -> mailer.Mailer:
    """Tests override this with an outbox."""
    return mailer.make_mailer()


def get_google() -> GoogleVerifier:
    return default_verifier()


auth = APIRouter(prefix="/auth", dependencies=[Depends(auth_ip_limit)])
me = APIRouter()


class _Body(BaseModel):
    model_config = ConfigDict(extra="ignore")


class SignUp(_Body):
    email: str = Field(max_length=320)
    password: str = Field(max_length=1024)
    display_name: str | None = Field(None, max_length=200)


class SignIn(_Body):
    email: str = Field(max_length=320)
    password: str = Field(max_length=1024)


class GoogleBody(_Body):
    id_token: str = Field(max_length=8192)


class RefreshBody(_Body):
    refresh_token: str = Field(max_length=200)


class TokenBody(_Body):
    token: str = Field(max_length=200)


class EmailBody(_Body):
    email: str = Field(max_length=320)


class ResetBody(_Body):
    token: str = Field(max_length=200)
    new_password: str = Field(max_length=1024)


class DeleteMe(_Body):
    password: str | None = Field(None, max_length=1024)


def _send(bg: BackgroundTasks, m: mailer.Mailer, mails: list[mailer.Mail]) -> None:
    for mail in mails:
        bg.add_task(mailer.deliver, m, mail)


def _json(body: dict, status: int = 200) -> JSONResponse:
    return JSONResponse(body, status_code=status, headers=NO_STORE)


@auth.post("/signup", status_code=201)
def signup(body: SignUp, bg: BackgroundTasks, db: Session = Depends(get_db), m: mailer.Mailer = Depends(get_mailer)):
    result, mails = service.signup(db, body.email, body.password, body.display_name, tokens.utcnow())
    _send(bg, m, mails)
    return _json(result, 201)


@auth.post("/signin")
def signin(body: SignIn, db: Session = Depends(get_db)):
    return _json(service.signin(db, body.email, body.password, tokens.utcnow(), limits.signin_failures))


@auth.post("/google")
def google(body: GoogleBody, db: Session = Depends(get_db), verifier: GoogleVerifier = Depends(get_google)):
    ident = verifier.verify(body.id_token)
    return _json(service.google_signin(db, ident, tokens.utcnow()))


@auth.post("/refresh")
def refresh(body: RefreshBody, db: Session = Depends(get_db)):
    return _json(service.refresh(db, body.refresh_token, tokens.utcnow()))


@auth.post("/signout", status_code=204)
def signout(body: RefreshBody, db: Session = Depends(get_db)):
    service.signout(db, body.refresh_token, tokens.utcnow())
    return Response(status_code=204)


@auth.post("/verify-email", status_code=204)
def verify_email(body: TokenBody, db: Session = Depends(get_db)):
    service.verify_email(db, body.token, tokens.utcnow())
    return Response(status_code=204)


@auth.post("/resend-verification", status_code=202)
def resend_verification(bg: BackgroundTasks, user: User = Depends(current_user), db: Session = Depends(get_db),
                        m: mailer.Mailer = Depends(get_mailer)):
    limits.resend_per_account.check(str(user.id))
    if user.email:
        limits.mail_per_email.check(user.email)
    _send(bg, m, service.resend_verification(db, user, tokens.utcnow()))
    return Response(status_code=202)


@auth.post("/forgot-password", status_code=202)
def forgot_password(body: EmailBody, bg: BackgroundTasks, db: Session = Depends(get_db),
                    m: mailer.Mailer = Depends(get_mailer)):
    email = service.normalise_email(body.email)
    limits.mail_per_email.check(email)
    _send(bg, m, service.forgot_password(db, email, tokens.utcnow()))
    return Response(status_code=202)


@auth.post("/reset-password", status_code=204)
def reset_password(body: ResetBody, db: Session = Depends(get_db)):
    service.reset_password(db, body.token, body.new_password, tokens.utcnow())
    return Response(status_code=204)


@me.get("/me")
def get_me(user: User = Depends(current_user)):
    return _json(service.user_json(user))


@me.delete("/me", status_code=204)
def delete_me(body: DeleteMe | None = None, p: Principal = Depends(current_principal), db: Session = Depends(get_db)):
    limits.account_writes.check(str(p.user.id))
    password = body.password if body else None
    service.check_delete_allowed(p.user, password, p.claims, tokens.utcnow())
    service.delete_user(db, p.user.id)
    return Response(status_code=204)

