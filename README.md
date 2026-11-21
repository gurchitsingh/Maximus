# Maximus

Flutter (Android) app + FastAPI backend. Monorepo.

- `app/` Flutter app (org com.gurchit.maximus)
- `backend/` FastAPI service
- `docs/` product, design and content docs (see `docs/DESIGN_BUNDLE.md` for the design export location)

## Run the backend
```
cd backend
py -m venv .venv
.venv\Scripts\activate
pip install -r requirements.txt
copy .env.example .env
uvicorn app.main:app --reload
```
Check: http://127.0.0.1:8000/healthz -> `{"status":"ok"}`

## Run the app
```
flutter emulators --launch Pixel_8
cd app
flutter run
```
