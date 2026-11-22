# Maximus backend (v0)

FastAPI + SQLAlchemy + SQLite (Alembic migrations). Serves the 3 sample titles from `data/samples/`.
The API contract is `docs/CONTRACTS.md` (authoritative); responses are tested against `docs/schemas/`.
Real titles live in `data/titles/` (S11 Wikipedia ingest). Chat (S14) is not built yet.

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

## Endpoints

`GET /healthz`, `/v1/catalogue`, `/v1/titles/{id}`, `/v1/feed?title_ids=a,b&limit=20&seed=1`,
`/v1/on-this-day?date=MM-DD` (live from Wikipedia, cached 24 h), `/v1/credits`, `/v1/fonts`.
ETag + `If-None-Match` (304) on catalogue, titles, credits, fonts, on-this-day. Errors always use
`{"error": {"code", "message", "retry_after_s", "details"}}`.
`POST /v1/titles/{id}/chat` is not here yet (404 `not_found` until S14).

Production serves only `status: published` titles (and reviewed quiz/facts). `SERVE_DRAFTS=true` serves everything.

## Tests

```powershell
.venv\Scripts\python -m pytest             # no network (real HTTP is blocked), temp SQLite per test
..\tools\.venv\Scripts\python ..\tools\validate_samples.py   # from the repo root: contracts, samples, examples
```

## Secrets

None are needed for v0. `backend/.env` is gitignored; only `.env.example` (names, no values) is committed.
