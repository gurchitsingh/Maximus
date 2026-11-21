from fastapi import FastAPI

app = FastAPI(title="Maximus API")


@app.get("/healthz")
def healthz():
    return {"status": "ok"}
