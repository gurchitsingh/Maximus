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
- **Security:** rate limits on auth endpoints, password hashing (argon2 or bcrypt), email verification and password reset for email accounts, short-lived access tokens plus refresh tokens, no secrets in the public repo. Run the Cloudflare security-audit skill and Strix before launch.
- **Per-install chat caps stay** (20 per install, 200 global per UTC day); add a per-account cap once accounts exist.

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
- daily_facts: date_key or position, text (<= 25 words), thumbnail image (hand-written list of about 100; bundled in the app as well)
- quiz_questions: id, title_id, question, options[4], correct_index, explanation
- on_this_day cache: date, payload, fetched_at
- ingest_runs: id, started_at, status, notes
(V2) lens_texts: id, title_id, country, period, lens, body, reviewed

## Data model (users, new in v3)
- users: id, email (nullable for Google-only), password_hash (nullable), google_sub (nullable), email_verified, created_at, deleted_at
- refresh_tokens: id, user_id, token_hash, expires_at, revoked_at
- user_ratings, user_study_list, user_progress, user_quiz_results, user_feed_state, user_settings (incl. onboarding picks): each keyed by user_id with updated_at and a deleted flag for sync
- user_chat_messages: id, user_id, title_id, role, text, created_at (purged after retention)

## API (/v1) as built
- GET /v1/catalogue (groups, titles, images, catalogue_version)
- GET /v1/titles/{id}
- GET /v1/feed
- GET /v1/on-this-day
- GET /v1/credits, GET /v1/fonts
- POST /v1/titles/{id}/chat (replies whole; caps, burst limits, injection guard)
- GET /healthz
Note: the list route is /catalogue (not /titles), and quiz and lessons come inside the title payload. CONTRACTS is authoritative.

## API (/v1) planned for v3 (S17)
- Auth: sign up, sign in (email), sign in with Google (ID token), refresh, sign out, verify email, forgot and reset password
- GET/PUT /v1/me/sync (pull and push of user data since a timestamp), or per-resource endpoints as CONTRACTS defines
- GET /v1/me/chat/{title_id}, DELETE /v1/me/chat/{title_id}
- DELETE /v1/me (account deletion) and a public deletion web page
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
- Guardrails: caps per install and global per UTC day (salted hashes), burst limits, request size limit, injection guard and output check, canary. v3: per-account cap; chat saved to the account with retention.
- Free tiers can change or throttle: retry on the other provider, then return "chat is resting".
