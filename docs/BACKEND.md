# BACKEND (v2)

Stateless FastAPI service. No user accounts. Keeps content, serves it, and proxies the chatbot so API keys never ship in the app.

## Stack
Python + FastAPI, SQLite (dev) / Postgres (prod), SQLAlchemy + Alembic, httpx. Hosting TBD (Render, Railway or Fly.io free tiers; free tiers sleep, plan for cold starts).

## Data model
- titles: id, slug, name, brief, kind (topic | leader | thinker), category, hero_image_id, accent_colour, title_style_key, lesson_count, read_minutes, source_pages
- people (for kind leader/thinker): title_id, born, died, region, headline, traits (JSON, 3 to 5), changes (JSON), odds_beaten (JSON, leaders), core_ideas (JSON, thinkers), use_today, sources (JSON)
- lessons: id, title_id, position, heading, body, word_count
- images: id, url, local_path, author, licence, source_url, width, height
- lesson_images: lesson_id, image_id
- facts: id, title_id, lesson_id, text (<= 280 chars), image_id (feed cards)
- quiz_questions: id, title_id, question, options[4], correct_index, explanation
- on_this_day cache: date, payload, fetched_at
- ingest_runs: id, started_at, status, notes
(V2) lens_texts: id, title_id, country, period, lens, body, reviewed

## API (/v1)
- GET /titles (list, with category and hero), GET /titles/{id} (brief + lesson list)
- GET /titles/{id}/lessons/{n}
- GET /titles/{id}/quiz (6 random, no answers leaked beyond what client grades; answers included since graded on device)
- GET /feed?topics=a,b,c&cursor=
- GET /on-this-day
- POST /titles/{id}/chat  body: {message, history[last 6]} returns {answer, lesson_refs[]}
- GET /healthz
Match %, ratings, study list, progress: all on device, not in the API.

## Content ingestion
1. Seed list from TOPICS.md (28 topics + 51 people) with their Wikipedia page(s). People's traits, changes, odds_beaten and use_today are written text (hand-written or AI-drafted) with cited sources, reviewed before publishing; they are not auto-imported.
2. Fetch article via Wikipedia REST/Action API; split on top-level headings, merge short sections, cap about 400 words per lesson.
3. Fetch images via Commons imageinfo/extmetadata; accept PD, CC0, CC BY, CC BY-SA; store credit; copy image to our storage.
4. Generate facts for the feed (first pass by LLM from stored text, human review) and hand-write quiz banks.
5. Weekly refresh; compliant User-Agent, at most 3 concurrent requests.

## Chatbot service
- Providers: OpenRouter free model first, Google Gemini free key as fallback. Keys in server env vars.
- Context: the full stored text of the one title (about 80 small titles, so no vector DB). If a title exceeds the model's context, send top lessons by keyword score.
- System prompt: answer only from supplied text; if not answered there, say so; refuse off-topic; short answers; name the lesson used.
- Guardrails: per-device daily cap (device id is a random install id, not an account), request size limit, basic prompt-injection test set, log failures not conversations.
- Free tiers can change or throttle: retry on the other provider, then return "chat is resting".
