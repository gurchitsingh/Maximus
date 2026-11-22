"""Wikimedia Commons: licence check and image records (CONTRACTS 2.3, CONTENT_SOURCES 4).

`prop=imageinfo&iiprop=url|size|mime|extmetadata` for up to 50 files per request. Only files hosted on Commons
are used (files local to English Wikipedia are often non-free). Accepted licences: PD, CC0, CC BY, CC BY-SA.
Everything else, an unclear licence, a missing author on a CC file, or a non-free / trademark flag is rejected
with a reason, so the run report can list it.
"""
import re
from html import unescape
from urllib.parse import quote

API = "https://commons.wikimedia.org/w/api.php"
THUMB_WIDTH = 1600
MIN_SIDE = 500
EXT_OK = (".jpg", ".jpeg", ".png", ".tif", ".tiff", ".svg", ".webp")
MIME_OK = {"image/jpeg", "image/png", "image/tiff", "image/svg+xml", "image/webp"}
# weak images for a history title: logos, flags, icons, signatures, UI pictograms (CONTENT_SOURCES 4.4)
BLOCK_WORDS = re.compile(
    r"\b(flags?|logos?|insignia|patch|icon|symbol|signature|autograph|coat of arms|emblem|seal of|wordmark|pictogram|commons-|"
    r"wiki[a-z]*|question book|ambox|edit-clear|padlock|folder|nuvola|crystal|portal|disambig|speaker|sound-|"
    r"loudspeaker|red pog|blue pog|locator dot|arrow|blank|placeholder|stub)\b", re.I)
METADATA_FIELDS = ("LicenseShortName|License|LicenseUrl|UsageTerms|Artist|Credit|Attribution|AttributionRequired|"
                   "ImageDescription|ObjectName|DateTimeOriginal|NonFree|Restrictions|Copyrighted")

CC_CODE = re.compile(r"^cc-(by|by-sa)-(\d\.\d)(?:-([a-z]{2,3}))?$")
CC_SHORT = re.compile(r"^CC[ -](BY|BY-SA)[ -](\d\.\d)(?:[ -]([A-Za-z]{2,3}))?$", re.I)


def plain(html: str | None) -> str:
    """Commons metadata values are HTML: strip tags, unescape, collapse spaces."""
    if not html:
        return ""
    t = re.sub(r"<br\s*/?>", " ", html, flags=re.I)
    t = re.sub(r"<[^>]+>", "", t)
    return re.sub(r"\s+", " ", unescape(t)).strip()


def name_ok(file: str) -> str | None:
    """Reason to skip before asking Commons, or None."""
    if not file.lower().endswith(EXT_OK):
        return "not a still image"
    if BLOCK_WORDS.search(file):
        return "blocked file name (logo, flag, icon, ...)"
    return None


def licence(meta: dict) -> tuple[dict | None, str | None]:
    """extmetadata -> ({license, license_version, license_url, display}, None) or (None, reason)."""
    v = {k: plain((meta.get(k) or {}).get("value")) for k in
         ("LicenseShortName", "License", "LicenseUrl", "UsageTerms", "NonFree", "Restrictions", "Copyrighted")}
    if v["NonFree"].lower() in ("true", "1", "yes"):
        return None, "non-free file"
    if "trademark" in v["Restrictions"].lower():
        return None, "trademarked"
    code, short = v["License"].lower().strip(), v["LicenseShortName"].strip()
    url = v["LicenseUrl"].strip() or None
    if url and url.startswith("//"):
        url = "https:" + url
    if url and url.startswith("http://"):
        url = "https://" + url[len("http://"):]

    m = CC_CODE.match(code)
    s = CC_SHORT.match(short)
    if m or (s and not code):
        kind, ver, port = m.groups() if m else (s.group(1).lower(), s.group(2), s.group(3))
        if m and s and (s.group(1).lower(), s.group(2)) != (kind, ver):
            return None, f"licence fields disagree ({code!r} vs {short!r})"
        name = "CC BY-SA" if kind == "by-sa" else "CC BY"
        if not url:
            url = f"https://creativecommons.org/licenses/{kind}/{ver}/" + (f"{port.lower()}/" if port else "")
        return {"license": name, "license_version": ver, "license_url": url,
                "display": f"{name} {ver}" + (f" {port.upper()}" if port else "")}, None
    if code in ("cc0", "cc-zero") or short.upper().startswith("CC0"):
        return {"license": "CC0", "license_version": None,
                "license_url": url or "https://creativecommons.org/publicdomain/zero/1.0/", "display": "CC0"}, None
    if code == "pd" or code.startswith("pd-") or short.lower() in ("public domain", "pd") or \
            short.lower().startswith("public domain"):
        return {"license": "PD", "license_version": None, "license_url": None, "display": "Public domain"}, None
    return None, f"licence not allowed or unclear ({short or code or 'none'})"


def author(meta: dict) -> str:
    """Attribution replaces Artist + Credit when present (CONTENT_SOURCES 4.2)."""
    for key in ("Attribution", "Artist"):
        a = plain((meta.get(key) or {}).get("value"))
        a = re.sub(r"\[\d+\]", "", a).strip()
        a = re.sub(r"^(.+?)\s*\1$", r"\1", a)  # "Unknown authorUnknown author" (label + hidden copy)
        if a:
            return a[:200].rstrip()
    return ""


def image_kind(file: str, caption: str, meta: dict) -> str:
    text = f"{file} {caption} {plain((meta.get('ImageDescription') or {}).get('value'))}".lower()
    if re.search(r"\bmaps?\b|route|territor|extent|borders|campaign of|location of", text):
        return "map"
    if re.search(r"portrait|depicted|bust of", text):
        return "portrait"
    if re.search(r"painting|oil on|fresco|canvas|watercolou?r|engraving|lithograph|etching|illustration", text):
        return "painting"
    if re.search(r"statue|sculpture|relief|mosaic|coin|denarius|aureus|bust|carving|tapestry|manuscript", text):
        return "art"
    if re.search(r"photo|photograph|nasa|launch|astronaut|crew", text):
        return "photo"
    return "other"


def query(client, files: list[str]) -> dict[str, dict]:
    """File name (no 'File:' prefix) -> imageinfo page dict, for files hosted on Commons."""
    out = {}
    for n in range(0, len(files), 20):  # API allows 50; 20 keeps long file names under URL limits
        batch = files[n:n + 20]
        data = client.get_json(API, {
            "action": "query", "prop": "imageinfo", "iiprop": "url|size|mime|extmetadata",
            "iiurlwidth": str(THUMB_WIDTH), "iiextmetadatafilter": METADATA_FIELDS, "iiextmetadatalanguage": "en",
            "titles": "|".join("File:" + f for f in batch),
        }, action_api=True)
        q = data.get("query") or {}
        alias = {x["to"]: x["from"] for k in ("normalized", "redirects") for x in q.get(k) or []}
        for p in q.get("pages") or []:
            if p.get("missing") or not p.get("imageinfo"):
                continue
            title = p["title"]
            while title in alias:
                title = alias[title]
            out[title.removeprefix("File:")] = p
    return out


def evaluate(file: str, page: dict | None, caption: str | None) -> tuple[dict | None, str | None]:
    """Commons answer -> candidate image fields (no id/url yet) or a rejection reason."""
    if page is None:
        return None, "not on Wikimedia Commons"
    info = page["imageinfo"][0]
    meta = info.get("extmetadata") or {}
    if info.get("mime") not in MIME_OK:
        return None, f"type {info.get('mime')}"
    if max(info.get("width", 0), info.get("height", 0)) < MIN_SIDE:
        return None, f"too small ({info.get('width')}x{info.get('height')})"
    lic, why = licence(meta)
    if lic is None:
        return None, why
    who = author(meta)
    if not who:
        if lic["license"] in ("CC BY", "CC BY-SA"):
            return None, "CC licence but no author to credit"
        who = "Unknown author"
    alt = alt_text(caption, file) or alt_text(plain((meta.get("ImageDescription") or {}).get("value")), file)
    if not alt:
        return None, "no English caption or description written by a person (alt text)"
    thumb = info.get("thumburl") or info["url"]
    tw, th = info.get("thumbwidth") or info["width"], info.get("thumbheight") or info["height"]
    resized = tw != info["width"] or info.get("mime") == "image/svg+xml"  # SVG is rendered to PNG
    credit = f"{who} · {lic['display']} · Wikimedia Commons" + (" · resized" if resized else "")
    if len(credit) > 300:
        who = who[: 300 - len(credit) + len(who) - 1].rstrip() + "…"
        credit = f"{who} · {lic['display']} · Wikimedia Commons" + (" · resized" if resized else "")
    page_url = info.get("descriptionurl") or \
        "https://commons.wikimedia.org/wiki/" + quote(("File:" + file).replace(" ", "_"))
    if page_url.startswith("//"):
        page_url = "https:" + page_url
    return {
        "file": file, "download_url": thumb, "width": int(tw), "height": int(th),
        "alt": alt, "kind": image_kind(file, caption or "", meta), "author": who,
        "license": lic["license"], "license_version": lic["license_version"], "license_url": lic["license_url"],
        "source_page_url": page_url, "credit_line": credit, "modified": bool(resized),
    }, None


def file_stem(file: str) -> str:
    return re.sub(r"[\s_]+", " ", re.sub(r"\.[A-Za-z0-9]{2,5}$", "", file.removeprefix("File:"))).strip().lower()


def alt_text(text: str | None, file: str = "") -> str | None:
    """A caption written by a Wikipedia/Commons editor, shortened to 200 characters at a sentence or word end.
    None when it is really a file name, a URL or upload boilerplate (gate G3: alt written by a person)."""
    if not text:
        return None
    t = re.sub(r"\s+", " ", text).strip().strip("|").strip()
    if len(t.split()) < 2 or re.search(r"\.(jpe?g|png|svg|tiff?|webp|gif)\b", t, re.I):
        return None
    if re.search(r"https?://|www\.|retrieved from|own work|uploaded by|original uploader|transferred from", t, re.I):
        return None
    letters = [c for c in t if c.isalpha()]
    if letters and sum(c.isascii() or "À" <= c <= "ɏ" for c in letters) / len(letters) < 0.8:
        return None  # not English: screen readers need text the reader can follow
    t = re.sub(r"\[(?:\d+|update|needs update|citation needed)\]", "", t, flags=re.I).strip()
    if file and re.sub(r"[\s_]+", " ", t).strip().lower().rstrip(".") == file_stem(file):
        return None
    if len(t) <= 200:
        return t
    cut = t[:200]
    end = max(cut.rfind(". "), cut.rfind("; "))
    if end >= 60:
        return cut[: end + 1]
    return cut[: cut.rfind(" ")].rstrip(",;:") + "…"
