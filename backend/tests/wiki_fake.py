"""A fake Wikipedia + Commons + Wikidata + upload server for the ingest tests (httpx.MockTransport).
Nothing here touches the network."""
import json

import httpx

from ingest.client import WikiClient


def para(n: int, word: str = "word") -> str:
    """n words in sentences of 10, ending with a full stop."""
    words = [word] * n
    out = []
    for i in range(0, n, 10):
        chunk = words[i:i + 10]
        chunk[0] = chunk[0].capitalize()
        out.append(" ".join(chunk) + ".")
    return " ".join(out)


LEAD = ("The Test Empire (Latin: Imperium Testum [ˈtɛs.tum]) was a large state in the test lands.[1] "
        "It is remembered for its roads ( ; ) and its laws.[citation needed] " + para(230, "lead"))
EXTRACT = "\n".join([
    LEAD,
    para(40, "second"),
    "Short list item",
    "",
    "",
    "== History ==",
    para(150, "history"),
    para(150, "story"),
    "=== Rise ===",
    para(200, "rise"),
    para(120, "climb"),
    "=== Fall ===",
    para(210, "fall"),
    "==== Detail ====",
    para(60, "detail"),
    "",
    "== Legacy ==",
    para(90, "legacy"),
    "",
    "== See also ==",
    "List of test things",
    "",
    "== References ==",
    "Smith, J. (2001). A book about the test empire. Test Press.",
])
SMALL_EXTRACT = "The Small War was a short war in the test lands. " + para(120, "small")

HTML = """
<div class="mw-parser-output">
<table class="infobox"><tbody><tr><td class="infobox-image">
<span typeof="mw:File"><a href="/wiki/File:Flag_of_Test.svg" class="mw-file-description"><img src="x"/></a></span>
</td></tr></tbody></table>
<figure typeof="mw:File/Thumb"><a href="/wiki/File:Good_painting.jpg" class="mw-file-description"><img src="x"/></a>
<figcaption>A painting of the first emperor in his robes.<sup class="reference">[2]</sup></figcaption></figure>
<p>Lead text.</p>
<div class="mw-heading mw-heading2"><h2 id="History">History</h2></div>
<div class="thumb tright"><div class="thumbinner"><a href="/wiki/File:Map_of_test.png" class="image"><img src="x"/></a>
<div class="thumbcaption">Map of the empire at its height.</div></div></div>
<figure><a href="/wiki/File:NC_photo.jpg" class="mw-file-description"><img/></a><figcaption>A soldier on a road.</figcaption></figure>
<figure><a href="/wiki/File:Local_only.jpg" class="mw-file-description"><img/></a><figcaption>A local file only.</figcaption></figure>
<figure><a href="/wiki/File:Tiny.jpg" class="mw-file-description"><img/></a><figcaption>A very small picture.</figcaption></figure>
<figure><a href="/wiki/File:No_author.jpg" class="mw-file-description"><img/></a><figcaption>A picture with no author.</figcaption></figure>
<figure><a href="/wiki/File:Battle_scene.jpg" class="mw-file-description"><img/></a><figcaption>A battle scene carved in stone.</figcaption></figure>
<div class="navbox"><a href="/wiki/File:Navbox_thing.jpg" class="mw-file-description"><img/></a></div>
<div class="mw-heading mw-heading2"><h2 id="Legacy">Legacy</h2></div>
<figure><a href="/wiki/File:Ruins_today.jpg" class="mw-file-description"><img/></a><figcaption>Ruins of the capital today.</figcaption></figure>
</div>
"""


def meta(license_code, short, artist="Jane Painter", url=None, **extra):
    m = {"License": {"value": license_code}, "LicenseShortName": {"value": short},
         "Artist": {"value": f'<a href="https://example.org/u">{artist}</a>' if artist else ""}}
    if url:
        m["LicenseUrl"] = {"value": url}
    for k, v in extra.items():
        m[k] = {"value": v}
    return m


COMMONS = {
    "Good painting.jpg": (meta("pd", "Public domain", "Old Master"), 3000, 2000, "image/jpeg"),
    "Map of test.png": (meta("cc-by-sa-4.0", "CC BY-SA 4.0", "Map Maker",
                             "https://creativecommons.org/licenses/by-sa/4.0"), 1200, 900, "image/png"),
    "NC photo.jpg": (meta("cc-by-nc-4.0", "CC BY-NC 4.0"), 2000, 1500, "image/jpeg"),
    "Tiny.jpg": (meta("cc0", "CC0"), 200, 150, "image/jpeg"),
    "No author.jpg": (meta("cc-by-2.0", "CC BY 2.0", artist=None), 2000, 1500, "image/jpeg"),
    "Battle scene.jpg": (meta("cc-by-3.0-de", "CC BY 3.0 de", "Stone Cutter"), 1400, 1000, "image/jpeg"),
    "Ruins today.jpg": (meta("cc0", "CC0", "Visitor"), 1800, 1200, "image/jpeg"),
    "Hero pic.jpg": (meta("pd", "Public domain", None, ImageDescription="A grand view of the capital city."),
                     4000, 3000, "image/jpeg"),
}

ENTITY = {"Q1": {"labels": {"en": {"value": "Test Empire"}}, "descriptions": {"en": {"value": "a test state"}},
                 "claims": {
                     "P580": [{"rank": "normal", "mainsnak": {"datavalue": {"type": "time", "value": {
                         "time": "-0027-01-16T00:00:00Z", "precision": 11}}}}],
                     "P582": [{"rank": "normal", "mainsnak": {"datavalue": {"type": "time", "value": {
                         "time": "+0476-00-00T00:00:00Z", "precision": 9}}}}],
                     "P18": [{"rank": "normal", "mainsnak": {"datavalue": {"type": "string",
                                                                          "value": "Hero pic.jpg"}}}]}}}

PAGES = {"Test Empire": (EXTRACT, HTML, "Q1"), "Small War": (SMALL_EXTRACT, "<div></div>", None)}


class FakeWiki:
    def __init__(self):
        self.requests: list[httpx.Request] = []

    def __call__(self, request: httpx.Request) -> httpx.Response:
        self.requests.append(request)
        p = dict(request.url.params)
        host = request.url.host
        if host == "upload.wikimedia.org":
            return httpx.Response(200, content=b"\xff\xd8\xff fake jpeg")
        if host == "en.wikipedia.org" and p.get("action") == "query":
            title = p["titles"]
            if title not in PAGES:
                return _json({"query": {"pages": [{"title": title, "missing": True}]}})
            extract, _, qid = PAGES[title]
            page = {"title": title, "extract": extract, "lastrevid": 123,
                    "canonicalurl": "https://en.wikipedia.org/wiki/" + title.replace(" ", "_"),
                    "pageprops": {"wikibase_item": qid} if qid else {}}
            return _json({"query": {"pages": [page]}})
        if host == "en.wikipedia.org" and p.get("action") == "parse":
            return _json({"parse": {"title": p["page"], "text": PAGES[p["page"]][1]}})
        if host == "commons.wikimedia.org":
            pages = []
            for t in p["titles"].split("|"):
                name = t.removeprefix("File:")
                if name not in COMMONS:
                    pages.append({"title": t, "missing": True})
                    continue
                m, w, h, mime = COMMONS[name]
                slug = name.replace(" ", "_")
                tw = min(w, 1600)
                pages.append({"title": t, "imagerepository": "shared", "imageinfo": [{
                    "url": f"https://upload.wikimedia.org/wikipedia/commons/a/ab/{slug}", "width": w, "height": h,
                    "mime": mime, "thumburl": f"https://upload.wikimedia.org/wikipedia/commons/thumb/a/ab/{slug}/"
                                             f"{tw}px-{slug}", "thumbwidth": tw, "thumbheight": round(h * tw / w),
                    "descriptionurl": f"https://commons.wikimedia.org/wiki/File:{slug}", "extmetadata": m}]})
            return _json({"query": {"pages": pages}})
        if host == "www.wikidata.org":
            return _json({"entities": {p["ids"]: ENTITY.get(p["ids"], {"missing": ""})}})
        return httpx.Response(404)


def _json(data) -> httpx.Response:
    return httpx.Response(200, content=json.dumps(data).encode(), headers={"content-type": "application/json"})


SEED = {
    "id": "test-empire", "kind": "topic", "name": "Test Empire", "poster_lines": ["TEST", "EMPIRE"],
    "group": "ancient-medieval", "era": "ancient", "region": "europe", "themes": ["empire", "war"],
    "bg": "#2B0E0C", "tint": "#E8553A", "lettering": "roman", "linked_title_ids": [], "rank": 5,
    "pages": [{"page": "Test Empire", "heading": "The empire in brief"},
              {"page": "Small War", "sections": ["lead"]}],
}


def fake_client(tmp_path, fake=None, **kw) -> tuple[WikiClient, FakeWiki]:
    fake = fake or FakeWiki()
    kw.setdefault("delay", 0)
    return WikiClient(transport=httpx.MockTransport(fake), cache_dir=tmp_path / "cache", **kw), fake
