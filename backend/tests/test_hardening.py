"""Production hardening (S22): docs hidden, security headers, CORS, token redaction in logs, and render.yaml
staying in step with the documented environment names."""
import logging
import re
from pathlib import Path

from fastapi.testclient import TestClient

from app.config import BACKEND_DIR, Settings
from app.main import API_HEADERS, RedactTokens, build_app

REPO = BACKEND_DIR.parent


def prod(**kw) -> Settings:
    base = dict(environment="production", jwt_secret="x" * 40, install_id_salt="salt",
                database_url="postgresql://u:p@h/db", cors_origins="")
    return Settings(_env_file=None, **{**base, **kw})


def dev(**kw) -> Settings:
    return Settings(_env_file=None, environment="development", **kw)


def test_docs_and_openapi_hidden_in_production():
    c = TestClient(build_app(prod()))
    for path in ("/docs", "/openapi.json", "/redoc"):
        assert c.get(path).status_code == 404, path
    assert c.get("/healthz").status_code == 200


def test_docs_available_in_development():
    c = TestClient(build_app(dev()))
    assert c.get("/docs").status_code == 200
    assert c.get("/openapi.json").status_code == 200


def test_api_security_headers_and_hsts_only_in_production():
    p = TestClient(build_app(prod())).get("/healthz")
    for k, v in API_HEADERS.items():
        assert p.headers[k] == v
    assert p.headers["Strict-Transport-Security"].startswith("max-age=")
    d = TestClient(build_app(dev())).get("/healthz")
    assert d.headers["X-Content-Type-Options"] == "nosniff"
    assert "Strict-Transport-Security" not in d.headers


def test_error_responses_carry_the_headers_too():
    r = TestClient(build_app(prod())).get("/v1/nope")
    assert r.status_code == 404 and r.headers["X-Content-Type-Options"] == "nosniff"


def test_web_pages_keep_their_own_csp():
    r = TestClient(build_app(prod())).get("/privacy")
    assert r.status_code == 200
    assert "style-src" in r.headers["Content-Security-Policy"]  # the page's policy, not the API default


def test_cors_wildcard_dropped_in_production_only():
    def allow(settings):
        c = TestClient(build_app(settings))
        return c.get("/healthz", headers={"Origin": "https://evil.example"}).headers.get("access-control-allow-origin")
    assert allow(prod(cors_origins="*")) is None
    assert allow(prod(cors_origins="https://ok.example")) is None  # other origins are not echoed
    ok = TestClient(build_app(prod(cors_origins="https://ok.example")))
    assert ok.get("/healthz", headers={"Origin": "https://ok.example"}).headers["access-control-allow-origin"] == "https://ok.example"
    assert allow(dev(cors_origins="*")) == "*"


def test_access_log_token_is_redacted():
    rec = logging.LogRecord("uvicorn.access", logging.INFO, "", 0, '%s - "%s %s HTTP/%s" %d',
                            ("1.2.3.4:5", "GET", "/reset-password?token=SECRET123&x=1", "1.1", 200), None)
    assert RedactTokens().filter(rec)
    out = rec.getMessage()
    assert "SECRET123" not in out and "token=[redacted]&x=1" in out


def test_redaction_leaves_other_lines_alone():
    rec = logging.LogRecord("uvicorn.access", logging.INFO, "", 0, '%s "%s %s"', ("a", "GET", "/v1/catalogue?lang=en"), None)
    RedactTokens().filter(rec)
    assert "/v1/catalogue?lang=en" in rec.getMessage()


# ---------- render.yaml ----------

def _render_text() -> str:
    return (REPO / "render.yaml").read_text("utf-8")


def _env_names(block: str) -> list[str]:
    return re.findall(r"- key: ([A-Z0-9_]+)", block)


def test_render_yaml_names_are_documented_and_secrets_are_not_inline():
    text = _render_text()
    readme = (BACKEND_DIR / "README.md").read_text("utf-8")
    documented = set(re.findall(r"^\| `([A-Z0-9_]+)`", readme, re.M))
    names = _env_names(text)
    assert names, "no env vars found in render.yaml"
    assert set(names) - {"PYTHON_VERSION"} <= documented, set(names) - documented  # PYTHON_VERSION is Render's
    # every entry is either sync:false (set in the dashboard) or a short non-secret literal
    live = "\n".join(l for l in text.splitlines() if not l.lstrip().startswith("#"))
    for chunk in re.split(r"\n\s*- key: ", live)[1:]:
        key, _, body = chunk.partition("\n")
        key = key.split()[0]
        if re.search(r"SECRET|PASSWORD|API_KEY|SALT|DATABASE_URL", key):
            own = body.split("- key:")[0]
            assert "sync: false" in own or "generateValue: true" in own, key
    assert not re.search(r"postgres(ql)?://\S+:\S+@", text), "connection string in render.yaml"


def test_render_yaml_services():
    text = _render_text()
    assert "healthCheckPath: /healthz" in text
    assert "alembic upgrade head" in text and "DATABASE_URL_DIRECT" in text
    assert "python -m app.jobs purge" in text
    assert "plan: free" in text and "preDeployCommand" not in text.replace("no preDeployCommand", "")  # not on free
    wf = (REPO / ".github" / "workflows" / "purge.yml").read_text("utf-8")
    assert "python -m app.jobs purge" in wf and "secrets.PURGE_DATABASE_URL" in wf
    assert re.search(r"PYTHON_VERSION\s*\n\s*value: \"?3\.12\.\d+", text)  # pinned to a full version
    assert "--no-proxy-headers" in text and "forwarded-allow-ips" not in text  # H1: uvicorn must not trust XFF
    assert re.search(r"TRUSTED_PROXY_HOPS[^\n]*\n\s*value: \"1\"", text)
    assert "rootDir: backend" in text


def test_backup_script_never_uploads_and_folder_is_ignored():
    ps = (BACKEND_DIR / "tools" / "backup.ps1").read_text("utf-8")
    assert "pg_dump" in ps and "DATABASE_URL_DIRECT" in ps
    assert not re.search(r"Invoke-(WebRequest|RestMethod)|\bcurl\b|gh release|upload-artifact", ps)
    ignore = (REPO / ".gitignore").read_text("utf-8")
    assert "backend/backups/" in ignore
