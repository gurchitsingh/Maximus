# Maximus backend (v0)

FastAPI + SQLAlchemy + SQLite (Alembic migrations). Serves the 3 sample titles from `data/samples/`.
The API contract is `docs/CONTRACTS.md` (authoritative); responses are tested against `docs/schemas/`.
Chat (S14) and Wikipedia ingest (S11) are not built yet.

## Run (Windows, PowerShell, from `backend/`)

```powershell
py -3.12 -m venv .venv
.venv\Scripts\pip install -r requirements-dev.txt
copy .env.example .env                      # dev settings: SERVE_DRAFTS=true (samples are drafts)
.venv\Scripts\alembic upgrade head          # creates maximus.db
.venv\Scripts\python -m ingest.cli seed-samples
.venv\Scripts\uvicorn app.main:app --host 0.0.0.0 --port 8000
```

- On this PC: <http://127.0.0.1:8000/healthz>, interactive docs at <http://127.0.0.1:8000/docs>.
- From the Android emulator the PC is **`http://10.0.2.2:8000`** (use `--host 0.0.0.0` or `127.0.0.1`; both work for the emulator).
- Re-running `seed-samples` is safe: unchanged titles stay at the same `content_version`, a changed file bumps it.
- Import one file: `python -m ingest.cli import data/titles/<id>.json`.

## Endpoints

`GET /healthz`, `/v1/catalogue`, `/v1/titles/{id}`, `/v1/feed?title_ids=a,b&limit=20&seed=1`,
`/v1/on-this-day?date=MM-DD` (live from Wikipedia, cached 24 h), `/v1/credits`, `/v1/fonts`.
ETag + `If-None-Match` (304) on catalogue, titles, credits, fonts, on-this-day. Errors always use
`{"error": {"code", "message", "retry_after_s", "details"}}`.
`POST /v1/titles/{id}/chat` is not here yet (404 `not_found` until S14).

Production serves only `status: published` titles (and reviewed quiz/facts). `SERVE_DRAFTS=true` serves everything.

## Tests

```powershell
.venv\Scripts\python -m pytest             # no network, temp SQLite per test
..\tools\.venv\Scripts\python ..\tools\validate_samples.py   # from the repo root: contracts, samples, examples
```

## Secrets

None are needed for v0. `backend/.env` is gitignored; only `.env.example` (names, no values) is committed.
