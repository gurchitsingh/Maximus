"""Auth rate limits (CONTRACTS 14.4, 17), in memory per process like 3.1.

- every /v1/auth/* call: 10 per minute per IP
- sign-in (SECURITY_AUDIT L5): 5 failures per 15 minutes per email and client IP, and 50 failures per hour per
  email from all IPs together (both scope "account")
- forgot-password: 3 per hour per email
- the public web forms (account deletion, reset): 10 per minute per IP; deletion requests also
  3 per hour per email
- signed-in writes (sync push, chat-history deletes, DELETE /v1/me): 60 per minute per account
- email sign-ups: SIGNUP_IP_DAILY_CAP (5) successful ones per IP per 24 h (SECURITY_AUDIT M1)
- mail (SECURITY_AUDIT M3): reset and deletion requests together, MAIL_PER_EMAIL_DAILY (5) per address per 24 h;
  and MAIL_DAILY_BUDGET (80) mails sent in all per 24 h, past which mails are dropped with a warning
"""
from app.config import settings
from app.services.ratelimit import RateLimiter

# SECURITY_AUDIT L5: the 5-failures lock is per email AND client IP, so nobody can lock out another person's address
# from their own IP; this looser per-email cap (rolling hour, failures only) still stops guessing spread over many IPs.
SIGNIN_EMAIL_HOURLY_FAILURES = 50

auth_ip = RateLimiter(10, 60, scope="ip")
signin_failures = RateLimiter(5, 15 * 60, scope="account")  # key: signin_keys
signin_email_failures = RateLimiter(SIGNIN_EMAIL_HOURLY_FAILURES, 3600, scope="account")
mail_per_email = RateLimiter(3, 3600, scope="account")
delete_form_email = RateLimiter(3, 3600, scope="account")
web_form_ip = RateLimiter(10, 60, scope="ip")
account_writes = RateLimiter(60, 60, scope="account")
signup_ip_daily = RateLimiter(settings.signup_ip_daily_cap, 24 * 3600, scope="ip")
mail_email_daily = RateLimiter(settings.mail_per_email_daily, 24 * 3600, scope="account")
mail_budget = RateLimiter(settings.mail_daily_budget, 24 * 3600, scope="global")

ALL = (auth_ip, signin_failures, signin_email_failures, mail_per_email, delete_form_email, web_form_ip,
       account_writes, signup_ip_daily, mail_email_daily, mail_budget)


def signin_keys(email: str, ip: str) -> list[tuple[RateLimiter, str]]:
    """The sign-in failure limiters and their keys. A normalised email has no whitespace, so "email ip" is
    unambiguous."""
    return [(signin_failures, f"{email} {ip}"), (signin_email_failures, email)]


def reset_all() -> None:
    for limiter in ALL:
        limiter.reset()
