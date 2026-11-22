"""On This Day (CONTRACTS 2.7): Wikipedia feed/onthisday/selected, cached per MM-DD for 24 h, stale copy on failure."""
import calendar
from datetime import datetime, timedelta, timezone

import httpx
from sqlalchemy.orm import Session

from app.config import settings
from app.errors import ApiError
from app.models import OnThisDayCache
from app.services.store import now_iso, served_titles

WIKI_URL = "https://en.wikipedia.org/api/rest_v1/feed/onthisday/selected/{mm}/{dd}"
FRESH_FOR = timedelta(hours=24)


def _parse(ts: str) -> datetime:
    return datetime.strptime(ts, "%Y-%m-%dT%H:%M:%SZ").replace(tzinfo=timezone.utc)


def fetch_wikipedia(date: str) -> dict:
    """Raw Wikipedia JSON. Separate function so tests can patch it. 8 s timeout, descriptive User-Agent."""
    mm, dd = date.split("-")
    r = httpx.get(WIKI_URL.format(mm=mm, dd=dd), timeout=8.0, headers={"User-Agent": settings.wiki_user_agent})
    r.raise_for_status()
    return r.json()


def _items(raw: dict, text_pages: dict[str, str]) -> list[dict]:
    out = []
    for e in raw.get("selected", []):
        pages = e.get("pages") or []
        year, text = e.get("year"), (e.get("text") or "").strip()
        if not pages or not isinstance(year, int) or year == 0 or not text:
            continue
        p = pages[0]
        url = ((p.get("content_urls") or {}).get("desktop") or {}).get("page")
        title = p.get("normalizedtitle") or (p.get("titles") or {}).get("normalized")
        if not url or not url.startswith("https://") or not title:
            continue
        out.append({"year": year, "text": text[:400], "page_title": title[:200], "page_url": url,
                    "linked_title_id": text_pages.get(url)})
        if len(out) == 10:
            break
    return out


def on_this_day(db: Session, date: str) -> dict:
    row = db.get(OnThisDayCache, date)
    if row and datetime.now(timezone.utc) - _parse(row.fetched_at) < FRESH_FOR:
        return {**row.payload, "stale": False}
    text_pages = {s["url"]: t["id"] for t in served_titles(db) for s in t["sources"] if s["role"] == "text"}
    try:
        items = _items(fetch_wikipedia(date), text_pages)
    except Exception:
        items = []
    if items:
        mm, dd = date.split("-")
        payload = {"date": date, "fetched_at": now_iso(), "stale": False, "items": items,
                   "source": {"name": "Wikipedia", "license": "CC BY-SA 4.0",
                              "url": f"https://en.wikipedia.org/wiki/Wikipedia:Selected_anniversaries/"
                                     f"{calendar.month_name[int(mm)]}_{int(dd)}"}}
        if row:
            row.payload, row.fetched_at = payload, payload["fetched_at"]
        else:
            db.add(OnThisDayCache(date=date, payload=payload, fetched_at=payload["fetched_at"]))
        db.commit()
        return payload
    if row:
        return {**row.payload, "stale": True}
    raise ApiError(503, "upstream_unavailable", "Wikipedia is unavailable and nothing is cached.",
                   retry_after_s=600, details={"upstream": "wikipedia"})
