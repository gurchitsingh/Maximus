"""Mailer interface (CONTRACTS 14.5). EMAIL_PROVIDER picks one:

- console (default, dev): writes the mail to the log so you can click the link. In production it logs only that a
  mail was not sent (links carry one-use tokens and must never reach production logs).
- resend: the Resend HTTPS API (EMAIL_PROVIDER_API_KEY, EMAIL_FROM).
- smtp: any SMTP server (SMTP_HOST, SMTP_PORT, SMTP_USERNAME, SMTP_PASSWORD, SMTP_STARTTLS, EMAIL_FROM).

Sending never raises into a request: failures are logged (without the address or body) and dropped, so a mail
outage cannot reveal whether an account exists.
"""
import logging
import smtplib
from dataclasses import dataclass
from email.message import EmailMessage
from typing import Protocol

import httpx

from app.config import settings
from app.errors import ApiError
from app.services.auth import limits

log = logging.getLogger("maximus.mail")


@dataclass
class Mail:
    to: str
    subject: str
    text: str
    purpose: str  # reset | reset_google | delete (for logs and tests)


class Mailer(Protocol):
    name: str

    def send(self, mail: Mail) -> None: ...


class ConsoleMailer:
    name = "console"

    def send(self, mail: Mail) -> None:
        if settings.is_production:
            log.warning("mail not sent (EMAIL_PROVIDER=console) purpose=%s", mail.purpose)
            return
        log.info("DEV MAIL purpose=%s to=%s subject=%s\n%s", mail.purpose, mail.to, mail.subject, mail.text)


class ResendMailer:
    name = "resend"
    URL = "https://api.resend.com/emails"

    def send(self, mail: Mail) -> None:
        r = httpx.post(self.URL, timeout=10, headers={"Authorization": f"Bearer {settings.email_provider_api_key}"},
                       json={"from": settings.email_from, "to": [mail.to], "subject": mail.subject, "text": mail.text})
        r.raise_for_status()


class SmtpMailer:
    name = "smtp"

    def send(self, mail: Mail) -> None:
        msg = EmailMessage()
        msg["From"], msg["To"], msg["Subject"] = settings.email_from, mail.to, mail.subject
        msg.set_content(mail.text)
        with smtplib.SMTP(settings.smtp_host, settings.smtp_port, timeout=10) as s:
            if settings.smtp_starttls:
                s.starttls()
            if settings.smtp_username:
                s.login(settings.smtp_username, settings.smtp_password)
            s.send_message(msg)


def make_mailer() -> Mailer:
    provider = settings.email_provider.strip().lower()
    if provider == "resend":
        return ResendMailer()
    if provider == "smtp":
        return SmtpMailer()
    if provider not in ("", "console"):
        log.warning("unknown EMAIL_PROVIDER, using console")
    return ConsoleMailer()


def deliver(mailer: Mailer, mail: Mail) -> None:
    """Send and swallow failures (run as a background task after the response). Past the daily budget (M3) the
    mail is dropped, so a flood cannot use up the provider quota that real resets and deletions need."""
    try:
        limits.mail_budget.check("all")
    except ApiError:
        log.warning("mail daily budget reached: dropped purpose=%s", mail.purpose)
        return
    try:
        mailer.send(mail)
        log.info("mail sent provider=%s purpose=%s", mailer.name, mail.purpose)
    except Exception as e:
        log.warning("mail failed provider=%s purpose=%s error=%s", mailer.name, mail.purpose, type(e).__name__)


# ---------- message texts ----------

def _link(path: str, token: str) -> str:
    return f"{settings.app_base_url.rstrip('/')}{path}?token={token}"


def reset_mail(to: str, token: str) -> Mail:
    return Mail(to, "Reset your Maximus password",
                "Someone asked to reset the password of your Maximus account. Open this link in the app to choose "
                f"a new password (valid for 1 hour):\n\n{_link('/reset-password', token)}\n\n"
                "If it was not you, ignore this email; your password stays the same.", "reset")


def reset_google_mail(to: str) -> Mail:
    return Mail(to, "Your Maximus account uses Google sign-in",
                "Someone asked to reset the password of your Maximus account. Your account signs in with Google "
                "and has no password: use \"Continue with Google\" in the app.\n\n"
                "If it was not you, ignore this email.", "reset_google")


def delete_mail(to: str, token: str) -> Mail:
    return Mail(to, "Delete your Maximus account",
                "Someone asked to delete your Maximus account and all its data. To confirm, open this link "
                f"(valid for 1 hour):\n\n{_link('/account/delete/confirm', token)}\n\n"
                "If it was not you, ignore this email; nothing is deleted.", "delete")
