"""Auth rate limits (CONTRACTS 14.4, 17), in memory per process like 3.1.

- every /v1/auth/* call: 10 per minute per IP
- sign-in: 5 failures per 15 minutes per email (scope "account")
- forgot-password and resend-verification: 3 per hour per email; resend also 1 per 60 s per account
- the public web forms (account deletion, verify, reset): 10 per minute per IP; deletion requests also
  3 per hour per email
- signed-in writes (sync push, chat-history deletes, DELETE /v1/me): 60 per minute per account
"""
from app.services.ratelimit import RateLimiter

auth_ip = RateLimiter(10, 60, scope="ip")
signin_failures = RateLimiter(5, 15 * 60, scope="account")
mail_per_email = RateLimiter(3, 3600, scope="account")
resend_per_account = RateLimiter(1, 60, scope="account")
delete_form_email = RateLimiter(3, 3600, scope="account")
web_form_ip = RateLimiter(10, 60, scope="ip")
account_writes = RateLimiter(60, 60, scope="account")

ALL = (auth_ip, signin_failures, mail_per_email, resend_per_account, delete_form_email, web_form_ip,
       account_writes)


def reset_all() -> None:
    for limiter in ALL:
        limiter.reset()
