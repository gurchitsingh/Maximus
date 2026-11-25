# BACKEND (v3)

FastAPI service. Keeps content, serves it, proxies the chatbot so API keys never ship in the app, and (v3) stores user accounts and synced user data.

# V3 CHANGES (24 Nov 2026) - read first

These override anything below that conflicts.

- **Accounts are in V1.** Sign-in is required. Methods: Google sign-in first, email and password second (defaults, user to confirm order).
- **Database:** content AND user data move to a hosted **Postgres** (default Neon free tier). Render free disk is wiped on redeploy, so SQLite must not hold user data. SQLite stays for local dev and tests.
- **Hosting:** Render free tier (sleeps when idle, first request is slow). Production must refuse to start with an empty INSTALL_ID_SALT or JWT secret.
- **Synced user data:** ratings, study list, lesson progress, quiz scores, feed saves and likes, onboarding picks, settings, chat history.
- **Chat history is stored** per user per title, kept 5 days by default, rolling per message (D46), deletable by the user. This reverses the v2 rule "log failures, not conversations". Chat text is personal data.
- **Account deletion:** an authenticated delete endpoint plus a public web page, as Play Store requires. Deleting removes all user rows.
- **Offline-first sync:** the phone is the working copy. Sync is last-write-wins per record with an updated_at timestamp; deletes are tombstones. Keep it simple.
- **Security:** rate limits on auth endpoints, password hashing (argon2 or bcrypt), password reset for email accounts (no email verification, D48), short-lived access tokens plus refresh tokens, no secrets in the public repo. Run the Cloudflare security-audit skill and Strix before launch.
- **Chat caps:** 20 per account and 200 global per UTC day (`CHAT_ACCOUNT_DAILY_CAP`, `CHAT_GLOBAL_DAILY_CAP`). The per-install cap (`CHAT_DAILY_CAP`, 20) still exists but only applies when a client sends an optional `install_id`; the app does not.

---

## Stack
Python + FastAPI, SQLite (dev) / Postgres (prod), SQLAlchemy + Alembic, httpx. Hosting: Render free tier plus hosted Postgres.

## Data model (content)
- titles: id, slug, name, brief, kind (topic | leader | thinker), category, hero_image_id, accent_colour, title_style_key, lesson_count, read_minutes, source_pages
- people (for kind leader/thinker): title_id, born, died, region, headline, traits (JSON, 3 to 5), changes (JSON), odds_beaten (JSON, leaders), core_ideas (JSON, thinkers), use_today, sources (JSON)
- lessons: id, title_id, position, heading, body, word_count
- images: id, url, local_path, author, licence, source_url, width, height
- lesson_images: lesson_id, image_id
- facts: id, title_id, lesson_id, text (<= 280 chars), image_id (feed cards)
- (daily_facts is NOT built: Fact of the day is a bundled app asset only, CONTRACTS 20)
- quiz_questions: id, title_id, question, options[4], correct_index, explanation
- on_this_day cache: date, payload, fetched_at
- ingest_runs: id, started_at, status, notes
(V2) lens_texts: id, title_id, country, period, lens, body, reviewed

## Data model (users, new in v3)
- users: id, email (nullable for Google-only), password_hash (nullable), google_sub (nullable), display_name, sync_seq, email_verified (unused since D48), created_at
- refresh_tokens: id, user_id, token_hash, family_id, expires_at, revoked_at
- user_records: one generic table for ratings, study list, progress, quiz results, feed state, settings and onboarding picks, keyed by (user_id, kind, record_id) with data, updated_at, deleted and a server-assigned seq (CONTRACTS 15.4). There are no per-resource `user_*` tables.
- email_tokens: id, user_id, purpose (reset | delete), token_hash, expires_at, used_at
- user_chat_messages: id, user_id, title_id, role, text, kind, lesson_refs, created_at (purged after retention)
- chat_usage: per-day counters keyed by user (and a salted install hash); chat_install_usage keeps the optional install cap

## API (/v1) as built
- GET /v1/catalogue (groups, titles, images, catalogue_version)
- GET /v1/titles/{id}
- GET /v1/feed
- GET /v1/on-this-day
- GET /v1/credits, GET /v1/fonts
- POST /v1/titles/{id}/chat (replies whole; caps, burst limits, injection guard)
- GET /healthz
Note: the list route is /catalogue (not /titles), and quiz and lessons come inside the title payload. CONTRACTS is authoritative.

## API (/v1) accounts and sync, as built
- Auth: POST /v1/auth/signup (signs in at once, no email step, D48), signin, google (ID token), refresh, signout, forgot-password, reset-password
- GET /v1/me, DELETE /v1/me (account deletion)
- GET /v1/me/sync?since=&limit= and POST /v1/me/sync (one generic record endpoint pair, CONTRACTS 15.3)
- GET /v1/me/chat/{title_id}, DELETE /v1/me/chat/{title_id}, DELETE /v1/me/chat
- Public HTML pages: GET /privacy, /account/delete (+ request and confirm), /reset-password
- Chat requires a signed-in user

## Content ingestion
1. Seed list from TOPICS.md (28 topics + 51 people) with their Wikipedia page(s). People's traits, changes, odds_beaten and use_today are written text (hand-written or AI-drafted) with cited sources, reviewed before publishing; they are not auto-imported.
2. Fetch article via Wikipedia REST/Action API; split on top-level headings, merge short sections, cap about 400 words per lesson.
3. Fetch images via Commons imageinfo/extmetadata; accept PD, CC0, CC BY, CC BY-SA; store credit; copy image to our storage.
4. Generate facts for the feed (first pass by LLM from stored text, human review) and hand-write quiz banks.
5. Weekly refresh; compliant User-Agent, at most 3 concurrent requests.
Tooling built: python -m ingest.cli (wiki, check, import, seed-samples, merge, report, review, publish, people). Titles must be reviewed and published before /v1/catalogue lists them.

## Chatbot service
- Providers: OpenRouter free model first, Google Gemini free key as fallback. Keys in server env vars.
- Context: the full stored text of the one title (about 80 small titles, so no vector DB).
- System prompt: answer only from supplied text; if not answered there, say so; refuse off-topic; short answers; name the lesson used.
- Guardrails: caps per account and global per UTC day (the optional per-install cap uses salted hashes), burst limits, request size limit, injection guard and output check, canary. Chat is saved to the account; messages are deleted 5 days after their own created_at (daily purge workflow plus a lazy purge on the first chat of each UTC day).
- Free tiers can change or throttle: retry on the other provider, then return "chat is resting".
