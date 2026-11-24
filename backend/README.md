# Maximus backend (v3)

FastAPI + SQLAlchemy + Alembic. **Production: Postgres (Neon). Dev and tests: SQLite.** Serves the 3 sample titles
from `data/samples/` and the real titles in `data/titles/` (S11 Wikipedia ingest).
The API contract is `docs/CONTRACTS.md` (authoritative); responses are tested against `docs/schemas/`.
Chat proxy: S14, see Chat below. Accounts, sync, chat history and account deletion: S17, see
[Accounts](#accounts-s17-contracts-14), [Sync](#sync-s17-contracts-15), [Account deletion and web pages](#account-deletion-and-web-pages-s17-contracts-17),
[Environment](#environment) and [Deploy, migrations and backups](#deploy-migrations-and-backups).

## Run (Windows, PowerShell, from `backend/`)

```powershell
py -3.12 -m venv .venv
.venv\Scripts\pip install -r requirements-dev.txt
copy .env.example .env                      # dev settings: SERVE_DRAFTS=true (samples are drafts)
.venv\Scripts\alembic upgrade head          # creates maximus.db (and adds 0003 to an existing one)
.venv\Scripts\python -m ingest.cli seed-samples
Get-ChildItem data\titles\*.json | % { .venv\Scripts\python -m ingest.cli import $_.FullName }  # real titles (same id replaces a sample)
.venv\Scripts\uvicorn app.main:app --host 0.0.0.0 --port 8000
```

- On this PC: <http://127.0.0.1:8000/healthz>, interactive docs at <http://127.0.0.1:8000/docs>.
- From the Android emulator the PC is **`http://10.0.2.2:8000`** (use `--host 0.0.0.0` or `127.0.0.1`; both work for the emulator).
- Re-running `seed-samples` is safe: unchanged titles stay at the same `content_version`, a changed file bumps it.
- Import one file: `python -m ingest.cli import data/titles/<id>.json`.
- Dev mail is printed to the server log (`EMAIL_PROVIDER=console`): copy the link to verify an email or reset a
  password. With no `JWT_SECRET` in dev, a random one is made per process, so sign-ins end when the server restarts.

## Content ingest (S11)

```powershell
.venv\Scripts\python -m ingest.cli wiki roman-history        # or: wiki --all  (titles in ingest/seed.json)
.venv\Scripts\python -m ingest.cli check roman-history       # publish gate G1 to G10, exit 1 on failure
.venv\Scripts\python -m ingest.cli import data/titles/roman-history.json
```

- `wiki` reads the seed entry, fetches each page's text (Action API extracts) and the images its sections
  show (parse HTML), Wikidata facts, and Commons licences; it writes `data/titles/<id>.json` with
  `status: draft` and prints a report (pages and revisions, lessons with word counts, every rejected image
  with its reason, seed vs Wikidata differences, gate result).
- Images: only PD, CC0, CC BY, CC BY-SA from Commons, with author, licence, licence URL, file page and a
  credit line. Copies go to `media/` (gitignored), served at `/media`; URLs start with `MEDIA_BASE_URL`.
- Etiquette: `WIKI_USER_AGENT` names the app and the public repo, one request at a time, 1 s apart
  (`--delay`, never under 0.5 s), `maxlag=5`, `Retry-After` honoured. Everything is cached in `.cache/`
  (gitignored), so re-runs make no requests; `--refresh` ignores the cache, `--no-download` skips images.
- Re-running keeps `quiz`, `feed_facts`, `person` and citation sources (S13 owns those) and keeps ids stable.
  A `reviewed`/`published` file is not overwritten without `--force`.
- `import` refuses any file failing G1 (schema + references), and a `status: published` file failing any gate
  rule. Quiz and feed drafts from Gemini go to `data/drafts/` and are merged by the S13 tool.

### Merging Gemini quiz and feed drafts (S13)

```
python -m ingest.cli merge roman-history            # or several ids, or --all
python -m ingest.cli merge roman-history --dry-run  # report only
python -m ingest.cli merge roman-history --skip-invalid
```

Reads `data/drafts/<id>.quiz.json` (`{"quiz": [...]}`) and `<id>.feed.json` (`{"feed_facts": [...]}`), either
one may be missing. Each item is checked against `docs/schemas` and against the title (`lesson_id` is one of its
lessons, options distinct ignoring case, feed `image_id` is one of its images). Passing items are appended to
`data/titles/<id>.json` with the next free ids and `status: needs_check`. Rules:
- Existing items are never changed, moved or removed, so reviewed items stay as they are.
- A draft item may not carry `id`, `title_id`, `status` or `review_note`; the tool sets them.
- All or nothing: one bad item means nothing is written and every problem is listed (`quiz #12 ("..."): options: ...`).
  `--skip-invalid` merges the good ones and lists the bad ones.
- Safe to re-run: an item whose prompt or text already exists (ignoring case and punctuation) is skipped.
- `lesson_id` is required in a draft item: `null` is an error here (the Gemini brief says every item names its
  lesson), although the stored schema allows null.
- Merging into a `reviewed` or `published` title is fine: new items are `needs_check`, so they are not served.
- Draft files (`data/drafts/*.json`) are working files and are gitignored; only `README.txt` stays in git.
- Exit 0 ok, 1 problems in the drafts or title, 2 cannot start (no drafts, no title file).

After a merge, flip items to `reviewed` by hand in the title file; production serves only `reviewed` items.

### Review and publish one title (S13)

```
python -m ingest.cli report roman-history           # what still needs review + publish gate result + next step
python -m ingest.cli review roman-history           # print the items to check (add --lesson l03 --lesson-text)
python -m ingest.cli review roman-history --approve q001-q012 f001 --note "checked against l02"
python -m ingest.cli review roman-history --reject q013 --note "answer is wrong"
python -m ingest.cli review roman-history --approve-all [--kind quiz|feed]
python -m ingest.cli review roman-history --title-reviewed    # draft -> reviewed, after you read the whole title
python -m ingest.cli publish roman-history [--import]         # reviewed -> published; --import also loads the DB
```

- `report` lists every `needs_check` item and runs the whole publish gate (G1 to G10); `--all` for every title,
  `--brief` for counts only.
- `review --approve` sets `reviewed` (ids like `q012`, `f003`, full ids, or ranges `q001-q010`); one unknown id
  stops the call and nothing is written. `--reject` removes a `needs_check` item and logs it in
  `data/rejected/<id>.json`, so merge never adds it back and its id is not reused. Reviewed (served) items are
  edited by hand.
- `publish` refuses unless the title is `reviewed` and the gate passes (G1 to G9); on a refusal the file is
  not touched. Items still `needs_check` do not block it, they are just not served (G10), and publish says how many.
- Typical order: `merge` -> `report` -> `review` ... -> `review --title-reviewed` -> `publish --import`.

### People text (leaders and thinkers)

```
python -m ingest.cli people chanakya --research research/people-1.md    # --replace, --dry-run
```

Reads `data/drafts/<id>.person.json` = `{"person": {...}}`: the CONTRACTS 2.4 person fields, where every claim
lists `sources` (`url`, `title`, optional `publisher`, `confidence` high/medium/low) instead of `source_ids`.
`died`, `odds_beaten`, `core_ideas` and `legend_note` may be left out. Claude writes this file from Perplexity's
`claim | source URL | confidence` tables (llm/perplexity.md). The tool turns each distinct URL into one
`role: citation` source (`<id>.sNN`, reused when the URL is already cited), assigns `source_ids`, checks the block
against the schema and the title against G1, and writes `person` plus the new sources into the title file. With
`--research`, every cited URL must appear in that file and no source may claim more confidence than the research
gave. Claims with fewer than 2 distinct sources, only low-confidence sources, or a missing `legend_note` import
with a warning and are stopped by `publish` (G7, G8). The title file must already exist (kind leader or thinker);
a `draft` title is overwritten on re-run, `reviewed` or `published` needs `--replace`.

## Endpoints

Public: `GET /healthz`, `/v1/catalogue`, `/v1/titles/{id}`, `/v1/feed?title_ids=a,b&limit=20&seed=1`,
`/v1/on-this-day?date=MM-DD` (live from Wikipedia, cached 24 h), `/v1/credits`, `/v1/fonts`.
ETag + `If-None-Match` (304) on catalogue, titles, credits, fonts, on-this-day. Errors always use
`{"error": {"code", "message", "retry_after_s", "details"}}`.

Accounts (no bearer): `POST /v1/auth/signup`, `signin`, `google`, `refresh`, `signout`, `verify-email`,
`forgot-password`, `reset-password`. Bearer (`Authorization: Bearer <access_token>`): `POST
/v1/auth/resend-verification`, `GET /v1/me`, `DELETE /v1/me`, `GET`/`POST /v1/me/sync`,
`POST /v1/titles/{id}/chat`, `GET`/`DELETE /v1/me/chat/{title_id}`, `DELETE /v1/me/chat`.
Web pages (HTML): `/privacy`, `/account/delete`, `/verify-email`, `/reset-password`.

Production serves only `status: published` titles (and reviewed quiz/facts). `SERVE_DRAFTS=true` serves everything.

## Tests

```powershell
.venv\Scripts\python -m pytest             # no network (real HTTP is blocked), temp SQLite per test
..\tools\.venv\Scripts\python ..\tools\validate_samples.py   # from the repo root: contracts, samples, examples
```

The same suite runs on Postgres when `TEST_DATABASE_URL` is set (CI does this in the `postgres` job). Tables are
created once and emptied before each test. A throwaway local server:

```powershell
docker run -d --name maximus-pg -e POSTGRES_USER=maximus -e POSTGRES_PASSWORD=maximus -e POSTGRES_DB=maximus_test -p 55432:5432 postgres:16-alpine
$env:TEST_DATABASE_URL = "postgresql://maximus:maximus@127.0.0.1:55432/maximus_test"; .venv\Scripts\python -m pytest
```

Auth tests sign Google ID tokens with a local RSA key and send mail to an in-memory outbox; addresses are
`example.com` / `example.org` only.

## Chat (S14, CONTRACTS 4; v3 changes in CONTRACTS 16)

`POST /v1/titles/{id}/chat` needs a bearer token. The body is `{"message"}` plus an optional `"install_id"`
(a `history` field is refused: the server builds the last 6 turns of that title from the stored history). It returns
one whole JSON reply `{"kind": "answer"|"out_of_scope", "text", "lesson_refs", "remaining_today", "message_id"}`
(not streamed). Answers come only from the open title's stored text; anything the output check cannot trust becomes
"I only know about {name}.".

- **v3 caps:** `CHAT_ACCOUNT_DAILY_CAP` (20 per account) and, when the app sends `install_id`, `CHAT_DAILY_CAP` (20
  per install, so a new account on the same phone gets no fresh allowance) → 429 `chat_daily_cap`;
  `CHAT_GLOBAL_DAILY_CAP` (200, summed over accounts) → 503 `chat_resting`. Burst: 6/min per account and per
  install, 20/min per IP. `remaining_today` is the tighter of the account and install allowances.
- **v3 history:** both turns of every 200 reply are stored in `user_chat_messages` (refusals too; failures not).
  `GET /v1/me/chat/{title_id}?limit=50&before=<message id>` (newest page first, oldest first in a page),
  `DELETE /v1/me/chat/{title_id}`, `DELETE /v1/me/chat`. Kept `CHAT_RETENTION_DAYS` (30): purged on the first chat
  of each UTC day and by `python -m app.jobs purge`. Chat text is never logged.
- `docs/schemas/chat-request.schema.json`, `chat-response.schema.json` and `error.schema.json` still describe
  the v1 shapes (no `message_id`, `history` required, no auth codes); the tests check v3 against CONTRACTS 16.

- Code: `app/routers/chat.py` (route), `app/services/chat/` (`providers.py` OpenRouter then Gemini behind a small
  `Provider` protocol, `prompt.py` context + system prompt with a per-process canary, `guard.py` injection
  pre-filter + fail-closed output check, `usage.py` daily caps, `service.py` the 10-step pipeline).
- Caps: `CHAT_DAILY_CAP` (20 per install) → 429 `chat_daily_cap`; `CHAT_GLOBAL_DAILY_CAP` (200 server-wide) → 503
  `chat_resting`; both reset at 00:00 UTC. Burst: 6/min per install, 20/min per IP → 429 `rate_limited`.
  Every provider failing → 503 `chat_resting` (`providers_down`, retry 300 s). Only 200 replies are counted.
- Counts: `chat_usage` per (day, account) and `chat_install_usage` per (day, `sha256(INSTALL_ID_SALT +
  install_id)`), both kept for today and yesterday (migration `0003` renamed the S14 table).
- History turns that match the injection pre-filter are dropped before the provider call (the message itself
  gets the refusal).

Manual check with real keys (put them in `backend/.env`, never commit it), server running:

```powershell
$s = Invoke-RestMethod -Method Post -Uri http://127.0.0.1:8000/v1/auth/signup -ContentType application/json -Body (@{email="you@example.com"; password="a long test password"} | ConvertTo-Json)
$h = @{Authorization = "Bearer $($s.access_token)"}
$b = @{message="Why did the Republic fall?"} | ConvertTo-Json
Invoke-RestMethod -Method Post -Uri http://127.0.0.1:8000/v1/titles/roman-history/chat -Headers $h -ContentType application/json -Body $b
```

## Accounts (S17, CONTRACTS 14)

- Code: `app/routers/auth.py`, `app/services/auth/` (`passwords.py` Argon2id 19 MiB / t=2 / p=1, rehashed on
  sign-in; `tokens.py` 15-minute HS256 access JWTs and opaque refresh / email tokens stored as sha256;
  `google.py` ID token checks against Google's keys, cached for their `max-age`; `mailer.py`; `limits.py`;
  `service.py` the account rules; `deps.py` the bearer dependency, which reloads the user on every request).
- Refresh tokens last 60 days and rotate on every use. Presenting a revoked one revokes every session of that
  user (`token_reused`). A password reset also revokes every session.
- Google sign-in finds the account by Google id, else links by the verified email, else creates one. Linking to
  an account whose email was never verified **drops its password**: whoever set it never proved they own the
  address (pre-hijacking guard).
- Limits (in memory, per process): 10/min per IP on every `/v1/auth/*` call, 5 failed sign-ins per 15 minutes
  per email, 3 reset or verification mails per hour per email, 1 resend per minute per account.
- Mail goes out after the response (a background task), so timing does not show whether an address has an
  account; failures are logged without the address and dropped.

## Sync (S17, CONTRACTS 15)

`GET /v1/me/sync?since=<seq>&limit=200` and `POST /v1/me/sync` with `{"records": [...]}` (1 to 500, at most
512 KB). One table, `user_records` (user, kind, id), for the kinds `setting` (synced keys only, never
`install_id`), `interest`, `study_item`, `rating`, `progress`, `quiz_result` (append-only) and `feed_item`; each
`data` shape is checked (`app/services/sync.py`). Newer `updated_at` wins, a delete wins a tie, a future
`updated_at` is clamped to now + 5 minutes. The server hands out `seq` per user under a row lock, so pulls never
skip a record. 50 000 live records per user (`SYNC_RECORD_QUOTA`). Tombstones are purged after
`SYNC_TOMBSTONE_DAYS` (90); a pull from before a purged tombstone gets `reset: true`.

## Account deletion and web pages (S17, CONTRACTS 17)

- `DELETE /v1/me` (body `{"password"}` for email accounts; Google accounts need an access token under 5
  minutes old, else 403 `reauth_required`) hard-deletes `refresh_tokens`, `email_tokens`, `user_records`,
  `user_chat_messages`, `chat_usage` and the `users` row in one transaction. Nothing is kept.
- `GET /account/delete` (link it from the Play Console and the privacy policy): email form → always "If an account
  exists, we sent a link" → a one-hour link to `/account/delete/confirm`, which shows a **Delete my account**
  button; only the POST deletes (mail scanners open links). 3 requests per hour per email, 10 per minute per IP.
- `GET /privacy`: the policy (draft wording, for the owner to review before launch).
- `/verify-email` and `/reset-password` are the pages the email links open (button or form, then POST).
- Templates are plain HTML in `app/templates/`; pages carry no scripts, a strict CSP, `Referrer-Policy:
  no-referrer` (the URLs carry tokens) and `Cache-Control: no-store`.

## Maintenance job

`python -m app.jobs purge` (add `--dry-run` to count only) removes chat history older than `CHAT_RETENTION_DAYS`,
sync tombstones older than `SYNC_TOMBSTONE_DAYS`, chat counters older than yesterday, and refresh or email tokens
that expired over a day ago. Run it daily (a Render cron job, or a scheduled GitHub Action with the database URL as
a secret). The chat route also purges lazily, so a missed day loses nothing.

## Environment

Every setting is an environment variable (or a line in `backend/.env`); empty values use the default.
`.env.example` lists them all with no secrets. Production values live in Render's environment settings only.

| Name | Default | What it is |
|---|---|---|
| `ENVIRONMENT` | (empty) | `development` or `production`. Empty on Render (where Render sets `RENDER`) counts as production |
| `RENDER` | (set by Render) | Present on Render; used only to treat an unset `ENVIRONMENT` as production |
| `DATABASE_URL` | `sqlite:///backend/maximus.db` | Production: Neon's **pooled** URL with `sslmode=require`. `postgres://` and `postgresql://` are accepted |
| `DATABASE_URL_DIRECT` | (empty = `DATABASE_URL`) | Neon's **direct** URL, used by Alembic only |
| `DB_POOL_SIZE` | `5` | Postgres pool size (no overflow, pre-ping, recycle 300 s, no prepared statements) |
| `SERVE_DRAFTS` | `false` | `true` serves draft titles (dev, the samples) |
| `WIKI_USER_AGENT` | MaximusApp/0.1 (repo URL) | User-Agent of the ingest |
| `CORS_ORIGINS` | (empty) | Comma-separated origins; empty = no CORS (the app needs none) |
| `MEDIA_DIR` | `backend/media` | Image store served at `/media` (dev; production storage is open, D44) |
| `MEDIA_BASE_URL` | `http://10.0.2.2:8000/media` | Base of image URLs written by the ingest |
| `RATE_LIMIT_IP_PER_MIN` | `120` | GET `/v1/*` per IP per minute |
| `JWT_SECRET` | (empty) | **Secret.** HS256 key of access tokens; production needs 32+ characters |
| `GOOGLE_CLIENT_ID` | (empty) | Web OAuth client id (the app's `serverClientId`); empty = Google sign-in refused |
| `APP_BASE_URL` | `http://127.0.0.1:8000` | Base of email links and web pages, e.g. the Render URL |
| `CONTACT_EMAIL` | (empty) | Contact line on `/privacy` |
| `EMAIL_PROVIDER` | `console` | `console` (dev log; in production mails are not sent), `resend` or `smtp` |
| `EMAIL_FROM` | (empty) | Sender address of account emails |
| `EMAIL_PROVIDER_API_KEY` | (empty) | **Secret.** Resend API key |
| `SMTP_HOST` | (empty) | SMTP server (with `EMAIL_PROVIDER=smtp`) |
| `SMTP_PORT` | `587` | SMTP port |
| `SMTP_USERNAME` | (empty) | SMTP login |
| `SMTP_PASSWORD` | (empty) | **Secret.** SMTP password |
| `SMTP_STARTTLS` | `true` | Use STARTTLS |
| `OPENROUTER_API_KEY` | (empty) | **Secret.** First chat provider; no key = skipped |
| `OPENROUTER_MODEL` | `meta-llama/llama-3.3-70b-instruct:free` | OpenRouter model id |
| `GEMINI_API_KEY` | (empty) | **Secret.** Fallback chat provider |
| `GEMINI_MODEL` | `gemini-2.5-flash` | Gemini model id |
| `CHAT_ACCOUNT_DAILY_CAP` | `20` | Chats per account per UTC day |
| `CHAT_DAILY_CAP` | `20` | Chats per install per UTC day (when the app sends `install_id`) |
| `CHAT_GLOBAL_DAILY_CAP` | `200` | Chats for everyone per UTC day |
| `CHAT_RETENTION_DAYS` | `30` | Days stored chat history is kept |
| `CHAT_PROVIDER_TIMEOUT_S` | `12` | Per-provider timeout |
| `CHAT_CONTEXT_CHARS` | `24000` | Title text budget in the prompt |
| `CHAT_INSTALL_PER_MIN` | `6` | Chat burst limit per account and per install |
| `CHAT_IP_PER_MIN` | `20` | Chat burst limit per IP |
| `INSTALL_ID_SALT` | (empty) | **Secret.** Salt of the install-id hashes; production refuses to start without it |
| `SYNC_TOMBSTONE_DAYS` | `90` | Days a sync delete is kept before it is purged |
| `SYNC_RECORD_QUOTA` | `50000` | Live sync records per user |

Tests only: `TEST_DATABASE_URL` (run the suite on Postgres).

**Production refuses to start** (`app/config.py` `check_startup`, called when `app.main` is imported) when
`INSTALL_ID_SALT` is empty, `JWT_SECRET` is empty or under 32 characters, or `DATABASE_URL` is SQLite.

## Deploy, migrations and backups

- Start command on Render: `uvicorn app.main:app --host 0.0.0.0 --port $PORT --proxy-headers
  --forwarded-allow-ips="*"`. Without the proxy flags every request has Render's proxy IP and the per-IP limits
  hit everyone at once.
- Migrations: `alembic upgrade head` once per deploy (a pre-deploy command), with `DATABASE_URL_DIRECT` set to
  Neon's direct URL. Never run it from several workers at once. Only the S17 session edits migrations.
- In-memory rate limits are per process: run one worker on Render free, or the limits multiply.
- **Backups (not built):** Neon's free plan keeps only about 6 hours of history for restores, which is not a
  backup. Before launch, set up a scheduled `pg_dump` of the direct URL (for example a daily GitHub Actions
  workflow that runs `pg_dump --format=custom` and stores the file somewhere private and encrypted, with a
  retention of a few weeks), and test a restore once. The dump holds personal data: treat it like the database
  (private storage, deleted on schedule, covered by the privacy policy's processors list).

## Secrets

`backend/.env` is gitignored; only `.env.example` (names, no values) is committed. Chat needs
`OPENROUTER_API_KEY` and/or `GEMINI_API_KEY` (a provider without a key is skipped; with neither, chat answers
503 `chat_resting`). Production also needs `JWT_SECRET` and `INSTALL_ID_SALT` (random strings) and the Neon URLs.
