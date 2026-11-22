# BACKEND (v2)

Stateless FastAPI service. No user accounts. Keeps content, serves it, and proxies the chatbot so API keys never ship in the app.

## Stack
Python + FastAPI, SQLite (dev) / Postgres (prod), SQLAlchemy + Alembic, httpx. Hosting TBD (Render, Railway or Fly.io free tiers; free tiers sleep, plan for cold starts).

## Data model
Full field list: docs/CONTRACTS.md 2.10 (updated in S3; the id is the slug, the person block is one JSON column on titles, there is no separate people or lesson_images table).
- titles: id (slug), kind (topic | leader | thinker), name, subtitle, poster_lines, group, era, region, period_start/end, themes, bg, tint, lettering, poster_image_id, hero_image_id, brief, linked_title_ids, rank, status, content_version, updated_at, payload_hash, person (JSON, leader/thinker only)
- lessons: id, title_id, idx, heading, body, reading_minutes, image_ids (JSON), read_aloud_text, source_ids (JSON)
- images: id, title_id, url, width, height, alt, kind, author, license, license_version, license_url, source_page_url, credit_line, modified, focal_x, focal_y
- feed_facts: id, title_id, lesson_id, text (<= 40 words and 280 chars), image_id, status, review_note
- quiz_questions: id, title_id, lesson_id, prompt, options[4], correct_index, explanation, difficulty, status, review_note
- sources: id, title_id, title, url, publisher, role (text | citation), license, confidence
- on_this_day_cache: date, payload, fetched_at
- chat_usage: day, install_hash, count
- ingest_runs: id, title_id, kind, started_at, finished_at, status, notes
(V2, reserved only) perspectives, events, scenarios, nodes, endings: CONTRACTS.md section 12.

## API (/v1)
Full contract: docs/CONTRACTS.md section 3, schemas in docs/schemas/.
- GET /v1/catalogue (every served title, summary fields, ETag)
- GET /v1/titles/{id} (whole title: lessons, images, the whole quiz bank with answers since grading is on device, feed facts, person, sources)
- GET /v1/feed?title_ids=a,b,c&limit=20&seed= (random facts for titles the device has not cached; no personal weighting)
- GET /v1/on-this-day?date=MM-DD
- POST /v1/titles/{id}/chat  body: {install_id, message, history[last 6]} returns {kind, text, lesson_refs[], remaining_today}; whole reply, not streamed
- GET /v1/credits
- GET /healthz returns {status, version}
One error shape for every error: {error: {code, message, retry_after_s, details}}. No pagination.
Match %, ratings, study list, progress: all on device, not in the API.

## Content ingestion
1. Seed list from TOPICS.md (28 topics + 51 people) with their Wikipedia page(s). People's traits, changes, odds_beaten and use_today are written text (hand-written or AI-drafted) with cited sources, reviewed before publishing; they are not auto-imported.
2. Fetch article via Wikipedia REST/Action API; split on top-level headings, merge short sections, cap about 400 words per lesson.
3. Fetch images via Commons imageinfo/extmetadata; accept PD, CC0, CC BY, CC BY-SA; store credit; copy image to our storage.
4. Draft feed facts and quiz banks with Gemini from the stored lesson text only, then human review of every item (needs_check → reviewed). Import format and the publish gate: CONTRACTS.md section 9.
5. Weekly refresh; compliant User-Agent, at most 3 concurrent requests.

## Chatbot service
- Providers: OpenRouter free model first, Google Gemini free key as fallback. Keys in server env vars.
- Context: the full stored text of the one title (about 80 small titles, so no vector DB). If a title exceeds the model's context, send top lessons by keyword score.
- System prompt: answer only from supplied text; if not answered there, say so; refuse off-topic; short answers; name the lesson used.
- Guardrails: per-device daily cap (device id is a random install id, not an account, stored only as a salted hash), a server-wide daily cap that protects the free-tier quota, request size limit, basic prompt-injection test set, log failures not conversations.
- The reply is checked whole before it is returned (no streaming); anything that fails the check becomes the fixed refusal "I only know about {title}.". Pipeline: CONTRACTS.md section 4.
- Free tiers can change or throttle: retry on the other provider, then return "chat is resting" (HTTP 503 chat_resting).
