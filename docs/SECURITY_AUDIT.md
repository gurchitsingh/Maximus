# Security audit: backend and Android app (2026-11-25)

Scope: `main` at `30101f7` (backend, app, workflows, `render.yaml`, full git history). The review read the source and traced code paths. No target code was executed and no deployed server was probed. Tools run: `pip-audit` on a fresh install of `backend/requirements.txt`, `flutter pub outdated`, an OSV lookup of every hosted package in `app/pubspec.lock`, and a grep of every commit on every branch for key patterns. Context read first: CONTRACTS 11, 14 to 17, DECISIONS D34 to D53.

Severity: **High** fully defeats a control with real consequences. **Medium** is a real boundary violation with limited reach or uncommon preconditions. **Low** is a weak control or an availability or hygiene problem. "Unverified" means the source path is confirmed but the outcome depends on something outside the repo (Render, Google), which is named in the finding.

No secret was found in the repo or its history. Nothing needs rotating.

## Summary

| ID | Severity | Area | Title | Status |
|---|---|---|---|---|
| H1 | High (unverified) | Transport / limits | A client-sent `X-Forwarded-For` header sets the client IP, so every per-IP limit can be bypassed | Open |
| M1 | Medium | Chat / auth | Free, unverified sign-ups let one person use up the global chat cap every day | Open |
| M2 | Medium | Auth | Access tokens stay valid for 15 minutes after a revocation (password reset, Google link, token reuse) | Open |
| M3 | Medium | Auth / email | Unverified sign-ups turn the reset and delete mails into a mail-flood and quota-exhaustion tool | Open |
| M4 | Medium (unverified) | Auth / Google | Google linking trusts `email_verified` for any domain and wipes the existing password | Open |
| L1 | Low | Account deletion | The Google-account reauth check for `DELETE /v1/me` passes with any refreshed token | Open |
| L2 | Low | Availability | Request bodies are read whole into memory before any size check | Open |
| L3 | Low | Availability | Rate-limiter keys are never evicted | Open |
| L4 | Low | Availability | A DB connection is held during the LLM calls (pool of 5, no overflow) | Open |
| L5 | Low | Auth | Anyone can lock a victim out of email sign-in for 15 minutes | Open |
| L6 | Low | Chat retention | History older than 5 days is still served until a purge runs, and the purge job can silently not run | Open |
| L7 | Low | Logging | SQL errors are logged with their bound parameters (emails, hashes) | Open |
| L8 | Low | Auth | Sign-up confirms that an account exists and reveals its sign-in method | Open (accepted by D48) |
| L9 | Low | Android | `allowBackup` is not disabled | Open |
| L10 | Low | Android | Release build is signed with the debug key | Open |
| L11 | Low | Android | The default API base URL is cleartext HTTP, and release builds have no HTTPS guard | Open |
| L12 | Low | CI | Actions are pinned to tags, not commit SHAs (the purge job holds the DB URL) | Open |

Counts: Critical 0, High 1, Medium 4, Low 12.

---

## H1. A client-sent `X-Forwarded-For` header sets the client IP, so every per-IP limit can be bypassed

- **Where:** `render.yaml:20` (`--proxy-headers --forwarded-allow-ips="*"`), `backend/app/services/auth/deps.py:22-23` (`client_ip`), `backend/app/main.py:63` (GET limit). The installed uvicorn is 0.54.0, and its `uvicorn/middleware/proxy_headers.py` (`get_trusted_client_address`) returns the **leftmost** `X-Forwarded-For` entry when the trusted list is `*`.
- **What is wrong:** With `*`, uvicorn trusts the whole header chain. The leftmost entry is whatever the client sent, unless Render's edge strips or overwrites the incoming header. Every per-IP limit uses that value: auth 10/min (`limits.py:12`), web forms 10/min (`limits.py:16`), chat 20/min, and GET 120/min.
- **Exploit:** Send a random `X-Forwarded-For: <random ip>` on each request. All per-IP limits stop applying. That allows password spraying across many emails (only the 5-per-email limit remains), mass sign-ups (M1, M3) and unbounded limiter memory (L3).
- **Unverified:** Whether Render's proxy passes on a client-supplied `X-Forwarded-For` (it most likely appends to it). To check once deployed: send 11 `POST /v1/auth/signin` requests in a minute, each with a different `X-Forwarded-For`. If the 11th is not a 429, this finding is confirmed.
- **Smallest fix:** Do not trust the leftmost entry. Drop `--forwarded-allow-ips="*"`. In `client_ip` (and in the GET middleware, which should call `client_ip`), take the entry that Render's own proxy appends: count from the **right** by the number of proxy hops. Log the raw header once on a test deploy to learn that count. Add a test that a spoofed leftmost value does not change the key.

## M1. Free, unverified sign-ups let one person use up the global chat cap every day

- **Where:** `backend/app/services/auth/service.py:80-95` (sign-up needs no proof), `backend/app/services/chat/service.py:80-92` (caps), `backend/app/config.py:51-52` (20 per account, 200 global), `chat/service.py:38` and `:70` (`install_id` is optional and the app does not send it, so the per-install cap never applies).
- **What is wrong:** The per-account cap is the only per-user cap that applies, and accounts cost nothing (D48). The global cap is shared by everyone.
- **Exploit:** Create 10 accounts (one minute at the auth limit, from one IP) and send 20 chats from each. The global cap of 200 is gone, and every real user gets `chat_resting` until UTC midnight. This can be repeated daily. With H1 it is not even slowed down.
- **Smallest fix:** Add a per-IP daily chat count next to the account count (for example 40 per IP per UTC day, in memory like the other limits, or a `chat_ip_usage` row), plus a per-IP daily sign-up limit (for example 5). Both depend on H1 being fixed. Optionally, do not count accounts younger than an hour toward chat.

## M2. Access tokens stay valid for 15 minutes after a revocation

- **Where:** `backend/app/services/auth/deps.py:34-39` (checks the JWT and loads the user, but nothing ties the token to a session), `backend/app/services/auth/service.py:69-71` (`revoke_all` touches refresh tokens only), called from `:133` (Google link), `:160` (reuse detection) and `:219` (password reset).
- **What is wrong:** "Revoke every session" only revokes refresh tokens. Any access token already issued keeps working until its `exp` (up to 900 s).
- **Exploit (the D48 pre-registration case):** An attacker signs up with the victim's email and refreshes every few minutes. The victim later signs in with Google, so the account is linked, the password is removed and refresh tokens are revoked. For up to 15 minutes the attacker can still `GET /v1/me/sync` and `/v1/me/chat/*` (the victim's first sync just uploaded their data) and push records. If the attacker's token is under 5 minutes old, they can also delete the account, because the account now has no password and `check_delete_allowed` (`service.py:233`) only checks `iat`. The same window follows a password reset and a detected refresh-token theft.
- **Smallest fix:** Add a `users.tokens_valid_after` timestamp. Set it to `now` in `revoke_all`, and in `current_principal` reject a token whose `iat` is earlier with `401 unauthorized`. That is one column, one Alembic migration and two lines of code. Add tests for reset, Google link and reuse.

## M3. Unverified sign-ups turn the reset and delete mails into a mail-flood and quota-exhaustion tool

- **Where:** `backend/app/routers/auth.py:105-111` (forgot-password), `backend/app/routers/web.py:94-114` (deletion request), `backend/app/services/auth/limits.py:14-15` (two separate 3-per-hour-per-email limiters), `service.py:80-95` (any address can be registered).
- **What is wrong:** Mails go only to addresses that have an account, but anyone can create an account for any address. The two per-email limiters are separate, and nothing caps the total mail sent per IP or per day.
- **Exploit:** Register accounts at addresses you do not own, then trigger both forms for each one. Each address receives 6 unwanted mails an hour, and the number of addresses is limited only by the auth per-IP limit, which H1 removes. That uses up the Resend quota (the free plan is small), so real users cannot reset passwords or delete accounts by email. Deletion by email is the Play Store deletion path. It also damages the sending domain's reputation.
- **Smallest fix:** Use one shared per-email mail limiter for all mail purposes (for example 3 per day), plus a global daily mail budget well under the provider quota (for example 80) that logs a warning when hit. Fix H1 first.

## M4. Google linking trusts `email_verified` for any domain and wipes the existing password (unverified)

- **Where:** `backend/app/services/auth/google.py:95-102`, `backend/app/services/auth/service.py:122-136`.
- **What is wrong:** Any Google token with `email_verified: true` and a matching email takes over an existing password account, and the password is removed (D45). For addresses outside Gmail and Google Workspace, Google's `email_verified` only shows that the address was verified once, when that Google account was created. It does not prove the address is controlled now.
- **Exploit:** Someone who once controlled an address (a former employee's work address, a lapsed domain, a recycled mailbox) and made a Google account with it can sign in with Google, take the Maximus account and lock out its current owner.
- **Unverified:** This relies on Google's documented meaning of `email_verified` for non-Google domains. It was not tested against Google.
- **Smallest fix:** Auto-link only when the email ends in `@gmail.com` or the token has an `hd` claim (Workspace). Otherwise return `email_taken` with `details.method: "password"`, so the user signs in with the password and the account is not silently taken over.

## L1. The Google-account reauth check for `DELETE /v1/me` passes with any refreshed token

- **Where:** `backend/app/services/auth/service.py:225-234`. A refresh issues a token with a fresh `iat` (`service.py:171`, `tokens.py:27`).
- **What is wrong:** The 5-minute `iat` check is meant to prove a recent sign-in, but a refresh resets `iat`. Anyone holding the refresh token (a lost or unlocked phone, malware) can refresh and then delete the account without signing in with Google again. The deletion cannot be undone.
- **Smallest fix:** Add an `auth_time` claim that is set only by sign-in or Google sign-in and carried unchanged through refreshes (store it on the `refresh_tokens` row), and check `auth_time` instead of `iat`. Alternatively, require a fresh Google `id_token` in the `DELETE` body.

## L2. Request bodies are read whole into memory before any size check

- **Where:** `backend/app/routers/web.py:60` (`await request.body()`, then the 4 KB check), `backend/app/routers/sync.py:26-30` and `backend/app/routers/chat.py:37-41` (the Content-Length guard is skipped for chunked bodies), and every JSON route (FastAPI reads the whole body).
- **What is wrong:** No body size limit applies before reading. A chunked request with no `Content-Length` is fully buffered.
- **Exploit:** Several concurrent multi-hundred-MB chunked POSTs to `/reset-password` can run the 512 MB free instance out of memory. Unverified: Render's edge may cap body size.
- **Smallest fix:** Add one ASGI middleware that rejects a request with a declared `Content-Length` over 600 KB, and counts streamed bytes and aborts past that limit when no length is declared.

## L3. Rate-limiter keys are never evicted

- **Where:** `backend/app/services/ratelimit.py:13` (a `defaultdict`; `check` and `add` create a key for every new IP or email and never remove it).
- **What is wrong:** Memory grows with every distinct key. Sign-in failures key on any valid-looking email, and with H1 every request can bring a new IP.
- **Smallest fix:** In `_trim` callers, delete a key whose deque is empty after trimming. Add a size cap (for example 100 000 keys) that clears the oldest keys when reached.

## L4. A DB connection is held during the LLM calls

- **Where:** `backend/app/services/chat/service.py:77-113` (the session reads usage and history, then calls up to two providers with a 12 s timeout each while the connection stays checked out), `backend/app/db.py:53-57` (`pool_size=5`, `max_overflow=0`).
- **What is wrong:** Five slow chats in flight take every pooled connection. All other requests, including sign-in and sync, wait for the pool timeout.
- **Smallest fix:** Call `db.commit()` just before the provider loop at `service.py:105`. That ends the read transaction and returns the connection to the pool (`expire_on_commit=False`, so loaded objects stay usable). `add_one` and `save_exchange` then take a fresh connection for the short write.

## L5. Anyone can lock a victim out of email sign-in for 15 minutes

- **Where:** `backend/app/services/auth/service.py:109-114`, `backend/app/services/auth/limits.py:13`.
- **What is wrong:** The failure counter is keyed on the email alone, so 5 wrong passwords from anywhere lock that email out for 15 minutes. This can be repeated indefinitely.
- **Smallest fix:** Key the 5-per-15-minutes counter on `(email, ip)`, and add a looser per-email counter (for example 50 per hour) that still stops distributed guessing. This depends on H1.

## L6. Expired chat history is still served, and the purge job can silently not run

- **Where:** `backend/app/services/chat/history.py:18` and `:42` (`recent` and `page` do not filter by age), `backend/app/services/chat/service.py:77-79` (the lazy purge runs only on the first chat of a UTC day), `.github/workflows/purge.yml:23` (skips with exit 0 when `PURGE_DATABASE_URL` is unset). GitHub also disables scheduled workflows in a repo with no activity for 60 days.
- **What is wrong:** With no chats and no working purge job, messages older than 5 days stay in the database and are returned by `GET /v1/me/chat/{title_id}` and used as model context. The privacy policy promises 5 days.
- **Smallest fix:** Add `created_at >= now - CHAT_RETENTION_DAYS` to the queries in `recent` and `page`. Make the purge gate fail the job (exit 1) when the secret is missing, so the run shows red.

## L7. SQL errors are logged with their bound parameters

- **Where:** `backend/app/errors.py:42` (`log.exception`), `backend/app/db.py:53-57` (`create_engine` without `hide_parameters=True`).
- **What is wrong:** SQLAlchemy error messages include a `[parameters: ...]` list. An unexpected DB error during sign-up, sign-in or sync would write emails, password hashes, token hashes or record data to Render's logs. CONTRACTS 11 promises personal data never reaches the logs.
- **Smallest fix:** Pass `hide_parameters=True` to both `create_engine` calls in `make_engine`.

## L8. Sign-up confirms that an account exists and reveals its sign-in method

- **Where:** `backend/app/services/auth/service.py:84-86`, `:98-100` (`409 email_taken`, with `details.method: "google"`). The forgot-password and delete-request handlers also take longer for a known email, because they write a token row (`service.py:203-209`, `:246-250`).
- **What is wrong:** Anyone can test whether an address uses Maximus, and whether it uses Google. This is inherent to D48 (sign-up must say the email is taken) and is limited only by the per-IP limit, which H1 weakens.
- **Smallest fix:** Accept the risk (D48) but keep the per-IP limit honest (H1). Optionally drop `details.method` and let the app suggest both options.

## L9. Android `allowBackup` is not disabled

- **Where:** `app/android/app/src/main/AndroidManifest.xml:4-7` (no `android:allowBackup`, no `dataExtractionRules`; the Android default is `true`).
- **What is wrong:** The drift database (study data, cached chat, install id) is included in Google cloud backup and device-to-device transfer. A restore also copies `flutter_secure_storage`'s encrypted prefs, but their Keystore key does not move, which can break reading the refresh token after a restore.
- **Smallest fix:** Set `android:allowBackup="false"` on `<application>`. Alternatively, add `dataExtractionRules` and `fullBackupContent` that exclude the secure-storage prefs and the database, so the server stays the only backup.

## L10. Release build is signed with the debug key

- **Where:** `app/android/app/build.gradle.kts:33-37` (`signingConfig = signingConfigs.getByName("debug")`).
- **What is wrong:** No release key is committed, which is correct (`.gitignore` covers `*.jks` and `key.properties`). But a release built today is signed with the shared debug key, and anyone with the Android SDK has that key. Play rejects it. `debuggable` is false for release by default, which is fine.
- **Smallest fix:** Read the signing config from a gitignored `key.properties` (Flutter's documented pattern), and enroll in Play App Signing.

## L11. The default API base URL is cleartext HTTP, and release builds have no HTTPS guard

- **Where:** `app/lib/data/api/api_client.dart:15-17` (`defaultValue: 'http://10.0.2.2:8000'`), and `app/lib/features/settings/account_section.dart:24-25` (same pattern for `APP_BASE_URL`).
- **What is wrong:** A release built without `--dart-define=API_BASE_URL=https://...` talks HTTP. `minSdk` is `flutter.minSdkVersion`, which is 24 in Flutter 3.50.1, and Android 7 and 8 (API 24 to 27) allow cleartext unless told otherwise. Today the default host is unreachable off an emulator, so the practical risk is low, but nothing stops a wrong define such as an `http://` Render URL.
- **Smallest fix:** In `main()`, if `kReleaseMode` and `apiBaseUrl` does not start with `https://`, throw at startup. Also add a main (release) `network_security_config` with `cleartextTrafficPermitted="false"`.

## L12. Actions are pinned to tags, not commit SHAs

- **Where:** `.github/workflows/app.yml:22` (`subosito/flutter-action@v2`, a third-party action), and `actions/checkout@v4` and `actions/setup-python@v5` in all three workflows, including `purge.yml`, which gets `secrets.PURGE_DATABASE_URL`.
- **What is wrong:** A moved tag runs new code. In `purge.yml` that code sees the production DB URL, and with it every user's data.
- **Smallest fix:** Pin every `uses:` to a full commit SHA (with the tag in a comment). Turn on Dependabot for `github-actions`.

---

## Looked at and fine

- **JWT:** HS256 is pinned in `decode_access` (no `alg` confusion). `iss` is checked and `sub`, `iat`, `exp`, `jti` are required. The 15-minute expiry is judged by the server, with 60 s of `iat` skew. Production refuses to start with a missing or short `JWT_SECRET` (`config.py:96-109`), and Render generates it (`render.yaml:34-35`).
- **Refresh tokens:** 256-bit opaque tokens, stored as sha256. Rotation revokes exactly once under concurrency (`service.py:165-169`). Reuse of a revoked token revokes all of the user's tokens. Sign-out is idempotent.
- **Google ID token:** RS256 only, `kid` required, JWKS cached with refetch at most once a minute, `aud == GOOGLE_CLIENT_ID`, `iss` from the two Google issuers, `exp` (60 s leeway), `email_verified` required. If `GOOGLE_CLIENT_ID` is empty, verification fails closed.
- **Argon2id** at 19 MiB, t=2, p=1 (the OWASP minimum), with rehash on sign-in. Passwords must be 10 to 128 characters; 1 KB bodies cap the hashing work.
- **Sign-in timing:** an unknown email or a Google-only account verifies against a dummy hash with the same parameters, and the same `invalid_credentials` comes back in every case.
- **Reset and delete tokens:** 256-bit, hashed, 1 hour, single use with an atomic `used_at`. A reset burns the other reset tokens and revokes refresh tokens. Email links never act on GET (mail scanners), and the pages are `no-store` and `no-referrer`. Tokens in query strings are redacted from uvicorn logs (`main.py:30-46`). Links are built from `APP_BASE_URL`, not the `Host` header, so reset links cannot be poisoned.
- **Pre-registration (D48):** a Google sign-in with the same verified email removes the attacker's password and revokes their refresh tokens (`service.py:129-135`). Reset and delete links go only to the address on file. What remains is M2, M3 and M4.
- **IDOR, checked on every `/v1/me` path:** sync pull and push filter and key on `user_id` from the token (`services/sync.py:182-225`, the primary key includes `user_id`). Chat history read, `before` anchor, delete-one and delete-all all filter on `user_id`, and the anchor is checked against `user_id` and `title_id` (`history.py:51-54`). Model context is built from `user_id` plus `title_id` only. `GET` and `DELETE /v1/me` use the token's user. No route takes a user id from the client.
- **Sync input:** strict per-kind schemas with `extra=forbid`, the record id must match the data, 8 KB per record, 500 records and 512 KB per push, 50 000 live records per user, `updated_at` clamped to now + 5 min, the push is serialized per user with `FOR UPDATE`, and 60 pushes per minute per account.
- **Chat guard:** `{message}` only, 1 to 500 characters, 8 KB body, strict schema. Injection pre-filter on the question and on replayed history. The system prompt puts only the curated title text inside fixed delimiters (with `<<<` and `>>>` stripped from the content). The output check fails closed: it needs a `LESSONS:` line naming lessons that were in the context, rejects any URL, canary or "out of scope" text, strips markup and keeps 1200 characters at most. The refusal text is built by the server. History cannot cross users or titles.
- **Account deletion** removes `refresh_tokens`, `email_tokens`, `user_records` (ratings, study list, progress, quiz, feed, settings, interests all live here), `user_chat_messages`, `chat_usage` and `users` in one transaction (`service.py:237-243`). FKs also cascade. `chat_install_usage` is keyed by a salted install hash, not by the user. The deleted user's access tokens fail at once (the user row is loaded on every request).
- **Public deletion page:** always shows the same message, 10 per minute per IP and 3 per hour per email, a POST-only confirm with a single-use token, no CSRF exposure (the token is the authority), CSP with no scripts and `form-action 'self'`, and every value HTML-escaped.
- **Headers:** `nosniff`, `no-referrer`, `X-Frame-Options: DENY`, CSP `default-src 'none'` on the API, HSTS in production. `/docs` and `/openapi.json` are off in production. CORS is off unless `CORS_ORIGINS` is set, and `*` is dropped in production. No cookies are used anywhere. A 500 returns a generic message.
- **Debug flags:** `SERVE_DRAFTS` defaults to false and `render.yaml:28-29` sets it to false. `/media` is mounted only if the gitignored directory exists. The console mailer refuses to print links in production. `ENVIRONMENT=production` is set, and `RENDER=true` counts as production anyway.
- **Logging:** no password, token or chat text is logged. Chat logs lengths and codes only. Google rejections log a reason code. Mail logs omit the address.
- **Secrets and repo:** All 116 commits reachable from any ref (33 refs, including the 16 remote branches) were searched for Google, OpenRouter, Resend, GitHub and Slack key patterns, private keys, credentialed DB URLs and assigned `*_KEY`, `*_SECRET`, `*_PASSWORD`, `*_TOKEN`, `*_SALT` values. The only hits are placeholder URLs in tests (`u:p@h`) and the CI throwaway Postgres password. No `.env`, keystore, `key.properties`, `google-services.json` or DB dump was ever committed. `.gitignore` covers `.env*` (except `.env.example`), `*.jks`, `*.keystore`, `key.properties`, `*.db` and `backend/backups/`. `.env.example` has names only. `render.yaml` holds names only (`sync: false` or `generateValue`). Workflows use `permissions: contents: read`, and the only secret, `PURGE_DATABASE_URL`, comes from GitHub secrets.
- **Dependencies (backend):** `pip-audit` on a fresh `--only-binary` install of `backend/requirements.txt` (2026-11-25) found **no known vulnerabilities**. Resolved versions: fastapi 0.165.0, starlette 1.10.0, uvicorn 0.54.0, pydantic 2.14.4, pydantic-settings 2.16.3, SQLAlchemy 2.1.9, alembic 1.20.1, httpx 0.28.1, h11 0.16.0, psycopg 3.3.9, argon2-cffi 25.1.0, PyJWT 2.15.1, cryptography 50.0.2, jsonschema 4.26.0. Note: requirements use `>=` ranges, so Render resolves new versions on every build. That is acceptable, but an untested major version can arrive with a deploy.
- **Dependencies (app):** `flutter pub outdated` (Flutter 3.50.1): all direct and dev dependencies are up to date. Six transitive packages are one patch behind (sqlite3 3.9.1 → 3.9.2, vector_graphics_compiler 1.3.6 → 1.3.7, vector_math 2.4.3 → 2.4.4, xml 7.0.1 → 7.1.0, material_color_utilities, test_api). OSV advisories for all 150 hosted packages in `pubspec.lock`: **none**. Direct: dio 5.11.1, drift 2.35.4, flutter_secure_storage 11.2.0, google_sign_in 7.2.0, go_router 18.1.4, url_launcher 6.3.3, cached_network_image 4.0.7, connectivity_plus 7.3.2.
- **Android:** only `MainActivity` is exported (the launcher; required). No deep links or app links, no custom intent filters, no providers or receivers. Cleartext is allowed only by a **debug-only** `network_security_config` for `10.0.2.2`, `localhost` and `127.0.0.1`. The refresh token and user fields are in `flutter_secure_storage`, and the access token is memory-only (`auth_tokens.dart:33-53`, `:105-109`). No interceptor logs headers. The `debugPrint` calls in `sync_service.dart` print error text and record ids, not tokens or data. The app holds no API keys: `GOOGLE_CLIENT_ID` is a public OAuth client id passed by `--dart-define`.
- **Cleanup (not a risk):** `auth_tokens.dart:163` still lists `/v1/auth/resend-verification`, which D48 removed. A stray bearer goes to a 404.

## Could not check

- **Render's `X-Forwarded-For` handling** (decides H1), whether its edge limits request body size (L2), and whether Render's own request logs keep full URLs, including `?token=` (the uvicorn log is redacted; the platform's may not be).
- **Production values in the Render dashboard:** `DATABASE_URL` with `sslmode=require`, `EMAIL_PROVIDER=resend` with a working key, `APP_BASE_URL` on `https://`, and `GOOGLE_CLIENT_ID` set. Also that HTTP redirects to HTTPS on the Render host.
- **GitHub settings:** whether `PURGE_DATABASE_URL` is set, branch protection on `main`, whether Actions may run on fork PRs with approval, and secret scanning or push protection.
- **Google Cloud:** that the web and Android OAuth clients are in the same project with the right SHA-1 (release key, L10), and the consent screen. Google's behaviour for `email_verified` on non-Google domains (M4).
- **Live LLM behaviour:** whether a provider answers off-topic but still ends with a valid `LESSONS:` line (the output check cannot detect off-topic content inside a well-formed answer). This needs real provider calls, which were not made.
- **Neon:** backup retention, IP allow-list and role privileges (the app role should not be superuser). Resend: domain SPF, DKIM and DMARC.
- **Runtime:** no load test of the DB pool (L4), and no memory test (L2, L3).

## Do before launch

1. Fix H1 and confirm it on the deployed service with the 11-request test. M1, M3 and L5 depend on it.
2. Add `tokens_valid_after` (M2) and the `auth_time` check for deletion (L1).
3. Add the per-IP daily chat and sign-up caps (M1) and the shared mail limiter with a daily budget (M3).
4. Decide M4: restrict auto-linking to Gmail and Workspace (`hd`) addresses.
5. Pass `hide_parameters=True` (L7), filter chat history by age and make the purge job fail loudly (L6). Then set `PURGE_DATABASE_URL` and run the workflow once by hand.
6. Android: `allowBackup="false"` (L9), release signing from a gitignored `key.properties` plus Play App Signing (L10), and a release-mode HTTPS assert (L11).
7. Pin action SHAs, at least in `purge.yml` (L12).
8. Check every item in "Could not check" against the real Render, GitHub, Google and Neon settings.
