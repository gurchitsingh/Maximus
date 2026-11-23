# Maximus backend (v0)

FastAPI + SQLAlchemy + SQLite (Alembic migrations). Serves the 3 sample titles from `data/samples/`.
The API contract is `docs/CONTRACTS.md` (authoritative); responses are tested against `docs/schemas/`.
Real titles live in `data/titles/` (S11 Wikipedia ingest). Chat proxy: S14, see Chat below.

## Run (Windows, PowerShell, from `backend/`)

```powershell
py -3.12 -m venv .venv
.venv\Scripts\pip install -r requirements-dev.txt
copy .env.example .env                      # dev settings: SERVE_DRAFTS=true (samples are drafts)
.venv\Scripts\alembic upgrade head          # creates maximus.db
.venv\Scripts\python -m ingest.cli seed-samples
Get-ChildItem data\titles\*.json | % { .venv\Scripts\python -m ingest.cli import $_.FullName }  # real titles (same id replaces a sample)
.venv\Scripts\uvicorn app.main:app --host 0.0.0.0 --port 8000
```

- On this PC: <http://127.0.0.1:8000/healthz>, interactive docs at <http://127.0.0.1:8000/docs>.
- From the Android emulator the PC is **`http://10.0.2.2:8000`** (use `--host 0.0.0.0` or `127.0.0.1`; both work for the emulator).
- Re-running `seed-samples` is safe: unchanged titles stay at the same `content_version`, a changed file bumps it.
- Import one file: `python -m ingest.cli import data/titles/<id>.json`.

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
- Exit 0 ok, 1 problems in the drafts or title, 2 cannot start (no drafts, no title file).

After a merge, flip items to `reviewed` by hand in the title file; production serves only `reviewed` items.

## Endpoints

`GET /healthz`, `/v1/catalogue`, `/v1/titles/{id}`, `/v1/feed?title_ids=a,b&limit=20&seed=1`,
`/v1/on-this-day?date=MM-DD` (live from Wikipedia, cached 24 h), `/v1/credits`, `/v1/fonts`.
ETag + `If-None-Match` (304) on catalogue, titles, credits, fonts, on-this-day. Errors always use
`{"error": {"code", "message", "retry_after_s", "details"}}`.
`POST /v1/titles/{id}/chat`: see Chat below.

Production serves only `status: published` titles (and reviewed quiz/facts). `SERVE_DRAFTS=true` serves everything.

## Tests

```powershell
.venv\Scripts\python -m pytest             # no network (real HTTP is blocked), temp SQLite per test
..\tools\.venv\Scripts\python ..\tools\validate_samples.py   # from the repo root: contracts, samples, examples
```

## Chat (S14, CONTRACTS 4)

`POST /v1/titles/{id}/chat` with `{"install_id", "message", "history"}` returns one whole JSON reply
`{"kind": "answer"|"out_of_scope", "text", "lesson_refs", "remaining_today"}` (not streamed). Answers come only
from the open title's stored text; anything the output check cannot trust becomes "I only know about {name}.".

- Code: `app/routers/chat.py` (route), `app/services/chat/` (`providers.py` OpenRouter then Gemini behind a small
  `Provider` protocol, `prompt.py` context + system prompt with a per-process canary, `guard.py` injection
  pre-filter + fail-closed output check, `usage.py` daily caps, `service.py` the 10-step pipeline).
- Caps: `CHAT_DAILY_CAP` (20 per install) → 429 `chat_daily_cap`; `CHAT_GLOBAL_DAILY_CAP` (200 server-wide) → 503
  `chat_resting`; both reset at 00:00 UTC. Burst: 6/min per install, 20/min per IP → 429 `rate_limited`.
  Every provider failing → 503 `chat_resting` (`providers_down`, retry 300 s). Only 200 replies are counted.
- Counts live in the `chat_usage` table (migration `0002`; run `alembic upgrade head` on an existing dev DB),
  as `sha256(INSTALL_ID_SALT + install_id)`, kept for today and yesterday. Message text, history and replies
  are never stored or logged.
- History turns that match the injection pre-filter are dropped before the provider call (the message itself
  gets the refusal).

Manual check with real keys (put them in `backend/.env`, never commit it), server running:

```powershell
$b = @{install_id="3f1c9a52-7b4e-4d2a-9c61-0e8b5a7d2f10"; message="Why did the Republic fall?"; history=@()} | ConvertTo-Json
Invoke-RestMethod -Method Post -Uri http://127.0.0.1:8000/v1/titles/roman-history/chat -ContentType application/json -Body $b
```

## Secrets

`backend/.env` is gitignored; only `.env.example` (names, no values) is committed. Chat needs
`OPENROUTER_API_KEY` and/or `GEMINI_API_KEY` (a provider without a key is skipped; with neither, chat answers
503 `chat_resting`). Set `INSTALL_ID_SALT` to a random string in production.
