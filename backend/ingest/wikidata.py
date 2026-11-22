"""Wikidata facts for a title (CONTENT_SOURCES 5). Wikidata is CC0.

Read in this order and never guessed:
  period start: P580 start time, P571 inception, P569 date of birth (people)
  period end:   P582 end time, P576 dissolved/abolished, P570 date of death (people)
  image:        P18 (a Commons file; it still goes through the Commons licence check)
The seed wins over Wikidata; the run report shows both so differences get a human look.
"""
import re

API = "https://www.wikidata.org/w/api.php"
START_PROPS = ("P580", "P571", "P569")
END_PROPS = ("P582", "P576", "P570")
TIME = re.compile(r"^([+-])(\d{1,16})-")


def year_of(value: dict) -> int | None:
    """Wikidata time value -> integer year, negative = BCE, no year 0. Precision coarser than a year
    (decade, century, ...) is too vague for a period label and returns None."""
    m = TIME.match(value.get("time") or "")
    if not m or (value.get("precision") or 0) < 9:
        return None
    year = int(m.group(2)) * (-1 if m.group(1) == "-" else 1)
    if year == 0 or not -5000 <= year <= 2100:
        return None
    return year


def _first_year(claims: dict, props) -> tuple[int | None, str | None]:
    for p in props:
        ranked = sorted(claims.get(p) or [], key=lambda c: c.get("rank") != "preferred")
        for c in ranked:
            if c.get("rank") == "deprecated":
                continue
            dv = ((c.get("mainsnak") or {}).get("datavalue") or {})
            if dv.get("type") == "time":
                y = year_of(dv["value"])
                if y is not None:
                    return y, p
    return None, None


def facts(client, qid: str | None) -> dict:
    """{'qid', 'label', 'description', 'period_start', 'period_end', 'start_prop', 'end_prop', 'image'}"""
    empty = {"qid": qid, "label": None, "description": None, "period_start": None, "period_end": None,
             "start_prop": None, "end_prop": None, "image": None}
    if not qid:
        return empty
    data = client.get_json(API, {"action": "wbgetentities", "ids": qid, "props": "claims|labels|descriptions",
                                 "languages": "en"}, action_api=True)
    ent = (data.get("entities") or {}).get(qid) or {}
    if not ent or "missing" in ent:
        return empty
    claims = ent.get("claims") or {}
    start, sp = _first_year(claims, START_PROPS)
    end, ep = _first_year(claims, END_PROPS)
    image = None
    for c in claims.get("P18") or []:
        dv = ((c.get("mainsnak") or {}).get("datavalue") or {})
        if dv.get("type") == "string" and c.get("rank") != "deprecated":
            image = dv["value"]
            break
    return {"qid": qid, "label": ((ent.get("labels") or {}).get("en") or {}).get("value"),
            "description": ((ent.get("descriptions") or {}).get("en") or {}).get("value"),
            "period_start": start, "period_end": end, "start_prop": sp, "end_prop": ep, "image": image}


def year_label(y: int | None) -> str:
    return "" if y is None else (f"{-y} BCE" if y < 0 else str(y))


def period_label(start: int | None, end: int | None) -> str | None:
    """'753 BCE to 476 CE', '1789 to 1799' (CONTRACTS 2.1 subtitle examples)."""
    if start is None and end is None:
        return None
    if start is not None and end is not None:
        if start < 0 < end:
            return f"{-start} BCE to {end} CE"
        return f"{year_label(start)} to {year_label(end)}"
    return f"From {year_label(start)}" if start is not None else f"Until {year_label(end)}"
