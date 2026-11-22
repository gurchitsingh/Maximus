"""English Wikipedia: article text by section (Action API TextExtracts) and the images each section shows
(Action API parse HTML). Calls go through ingest.client.WikiClient (User-Agent, pacing, cache).

Text: `prop=extracts&explaintext=1&exsectionformat=wiki` already drops templates, references, infoboxes and
tables; `clean_paragraph` removes what is left (footnote marks, empty brackets, pronunciation parentheses,
maths markup, list and table debris) and keeps every line inside the lesson markdown subset (CONTRACTS 2.2).
"""
import re
from html import unescape
from html.parser import HTMLParser
from urllib.parse import unquote

API = "https://en.wikipedia.org/w/api.php"

DROP_SECTIONS = {
    "see also", "references", "notes", "further reading", "external links", "bibliography", "citations",
    "sources", "footnotes", "explanatory notes", "works cited", "general and cited sources", "notes and references",
    "references and notes", "cited sources", "general sources", "primary sources", "secondary sources", "gallery",
    "notes and citations", "bibliography and further reading", "literature", "online sources",
    "general and cited references", "general references", "cited references", "references and further reading",
    "cited literature", "external links and further reading", "films and documentaries", "in popular culture",
    "in popular media",
}
HEADING = re.compile(r"^(={2,6})\s*(.+?)\s*\1\s*$")
FOOTNOTE = re.compile(r"\[(?:\d+|[a-z]|[ivx]+|citation needed|note \d+|nb \d+|clarification needed|when\?|who\?|"
                      r"according to whom\?|page needed|update|needs update|dubious[^\]]*)\]", re.I)
EMPTY_BRACKETS = re.compile(r"\s*[(\[]\s*[,;:\s]*[)\]]")
PRONUNCIATION = re.compile(r"\s*\((?:[^()]*?(?:ˈ|ˌ|listen|pronounced|pronunciation|IPA|/[^/\s]+/)[^()]*?)\)")
LANG_GLOSS = re.compile(r"\s*\((?:[A-Z][a-z]+(?: [A-Z][a-z]+)?|lit\.|abbr\.):[^()]*\)")
IPA_BRACKETS = re.compile(r"\s*\[[^\]]*[ɐ-˿][^\]]*\]")
OPEN_DEBRIS = re.compile(r"\(\s*[,;:]\s*")
MATH = re.compile(r"\{\\displaystyle[^{}]*(?:\{[^{}]*\}[^{}]*)*\}")
SENTENCE_END = re.compile(r"[.!?…][\"'”’)\]]*$")


def norm_heading(h: str | None) -> str | None:
    return None if h is None else re.sub(r"\s+", " ", h).strip().lower()


def clean_paragraph(text: str) -> str | None:
    """One extract line -> one safe paragraph, or None to drop it."""
    t = unescape(text).replace(" ", " ").replace("​", "")
    t = MATH.sub("", t)
    t = FOOTNOTE.sub("", t)
    t = PRONUNCIATION.sub("", t)
    t = IPA_BRACKETS.sub("", t)
    t = OPEN_DEBRIS.sub("(", t)        # "(, Russian: ...)" left behind by a removed pronunciation
    t = LANG_GLOSS.sub("", t)
    t = EMPTY_BRACKETS.sub("", t)
    t = re.sub(r"\(\s+", "(", t)
    t = re.sub(r"\s+\)", ")", t)
    t = t.replace("*", "")                      # `*` is inline markup in the subset; Wikipedia text has none
    t = re.sub(r"<(?=[A-Za-z/!])", "< ", t)     # never a tag (validator: `<[a-zA-Z/]`)
    t = re.sub(r"\]\((?=http)", "] (", t)       # never a link
    t = re.sub(r"\s+", " ", t).strip()
    t = re.sub(r"\s+([,.;:!?])", r"\1", t)
    t = re.sub(r"^[#>|<`\-•·\s]+", "", t).strip()  # nothing a line may not start with (CONTRACTS 2.2)
    if not t:
        return None
    words = t.split()
    # list items, table or caption debris: short and not a sentence
    if not SENTENCE_END.search(t) and len(words) < 12:
        return None
    if len(words) < 3:
        return None
    return t


def parse_extract(text: str) -> list[dict]:
    """Plain extract -> [{'heading': None|str, 'items': [('p'|'sub', text)]}] at level-2 granularity.
    Level-3 headings become ('sub', text) items (they render as `## Text`); deeper headings are dropped
    and their paragraphs flow on. Boilerplate sections (DROP_SECTIONS) and empty sections are removed."""
    sections = [{"heading": None, "items": []}]
    skipping = False
    for raw in text.split("\n"):
        line = raw.strip()
        if not line:
            continue
        m = HEADING.match(line)
        if m:
            level, name = len(m.group(1)), m.group(2).strip()
            if level == 2:
                skipping = norm_heading(name) in DROP_SECTIONS
                sections.append({"heading": name, "items": []})
            elif not skipping:
                if norm_heading(name) in DROP_SECTIONS:
                    continue
                if level == 3:
                    sections[-1]["items"].append(("sub", name))
            continue
        if skipping:
            continue
        p = clean_paragraph(line)
        if p:
            sections[-1]["items"].append(("p", p))
    out = []
    for s in sections:
        if s["heading"] is not None and norm_heading(s["heading"]) in DROP_SECTIONS:
            continue
        items = s["items"]
        # drop sub-headings with no paragraph after them
        items = [it for n, it in enumerate(items)
                 if it[0] == "p" or (n + 1 < len(items) and items[n + 1][0] == "p")]
        if any(k == "p" for k, _ in items):
            out.append({"heading": s["heading"], "items": items})
    return out


# ---------- images per section (parse HTML) ----------

SKIP_CLASSES = ("navbox", "sidebar", "metadata", "noprint", "ambox", "mbox", "portalbox", "sistersitebox",
                "side-box", "hatnote", "reflist", "references", "mw-references", "vertical-navbox", "succession-box",
                "navigation-not-searchable", "authority-control", "shortdescription", "mw-empty-elt")
CAPTION_CLASSES = ("thumbcaption", "gallerytext", "infobox-caption")
VOID = {"img", "br", "hr", "meta", "link", "input", "source", "wbr", "area", "col", "embed", "param", "track"}


class _ImageParser(HTMLParser):
    def __init__(self):
        super().__init__(convert_charrefs=True)
        self.stack = []            # (tag, skip, role) per open element
        self.section = None        # current level-2 heading text
        self.in_h2 = False
        self.h2_text = []
        self.images = []           # {'file', 'caption', 'section'}
        self._caption = None       # list of text parts while inside a caption element
        self._figure = None        # image dict waiting for its caption

    def _skipping(self):
        return any(s for _, s, _ in self.stack)

    def handle_starttag(self, tag, attrs):
        a = dict(attrs)
        cls = a.get("class") or ""
        skip = any(c in cls.split() for c in SKIP_CLASSES) or a.get("role") == "navigation"
        role = None
        if tag == "h2":
            self.in_h2, self.h2_text = True, []
        if tag == "figure" or "thumb" in cls.split() or "gallerybox" in cls.split():
            role = "figure"
        if tag == "figcaption" or any(c in cls.split() for c in CAPTION_CLASSES):
            role = "caption"
            if not self._skipping():
                self._caption = []
        if tag == "a" and not self._skipping():
            href = a.get("href") or ""
            if href.startswith("/wiki/File:"):
                name = unquote(href[len("/wiki/File:"):].split("#")[0]).replace("_", " ")
                img = {"file": name, "caption": None, "section": self.section}
                if all(i["file"] != name for i in self.images):
                    self.images.append(img)
                    self._figure = img
        if tag not in VOID:
            self.stack.append((tag, skip, role))

    def handle_endtag(self, tag):
        if tag in VOID:
            return
        while self.stack:
            t, _, role = self.stack.pop()
            if role == "caption" and self._caption is not None:
                text = re.sub(r"\s+", " ", "".join(self._caption)).strip()
                if self._figure is not None and text and not self._figure["caption"]:
                    self._figure["caption"] = FOOTNOTE.sub("", text).strip()
                self._caption = None
            if role == "figure":
                self._figure = None
            if t == tag:
                break
        if tag == "h2" and self.in_h2:
            self.in_h2 = False
            self.section = re.sub(r"\s+", " ", "".join(self.h2_text)).strip()
            self._figure = None

    def handle_data(self, data):
        if self.in_h2:
            self.h2_text.append(data)
        elif self._caption is not None:
            self._caption.append(data)


def images_by_section(html: str) -> list[dict]:
    """Files shown in the article body in document order: {'file', 'caption', 'section'} (section None = lead).
    Images inside navboxes, sidebars, maintenance boxes and reference lists are ignored."""
    p = _ImageParser()
    p.feed(html)
    p.close()
    return p.images


# ---------- API calls ----------

def fetch_page(client, page: str) -> dict:
    """{'title', 'url', 'revid', 'wikibase_item', 'sections', 'images'} for one article (2 requests)."""
    q = client.get_json(API, {
        "action": "query", "prop": "extracts|pageprops|info", "explaintext": "1", "exsectionformat": "wiki",
        "ppprop": "wikibase_item", "inprop": "url", "redirects": "1", "titles": page,
    }, action_api=True)
    pages = (q.get("query") or {}).get("pages") or []
    if not pages or pages[0].get("missing") or "extract" not in pages[0]:
        raise LookupError(f"Wikipedia page not found: {page!r}")
    pg = pages[0]
    if "disambiguation" in (pg.get("pageprops") or {}):
        raise LookupError(f"Wikipedia page is a disambiguation page: {page!r}")
    parsed = client.get_json(API, {
        "action": "parse", "page": pg["title"], "prop": "text", "redirects": "1", "disableeditsection": "1",
        "disablelimitreport": "1", "disabletoc": "1",
    }, action_api=True)
    html = (parsed.get("parse") or {}).get("text") or ""
    return {
        "title": pg["title"],
        "url": pg.get("canonicalurl") or pg.get("fullurl") or
               "https://en.wikipedia.org/wiki/" + pg["title"].replace(" ", "_"),
        "revid": pg.get("lastrevid"),
        "wikibase_item": (pg.get("pageprops") or {}).get("wikibase_item"),
        "sections": parse_extract(pg["extract"]),
        "images": images_by_section(html),
    }
