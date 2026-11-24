"""Turn picked article sections into lessons of about 400 words (CONTRACTS 9.2: target 400, range 200 to 600).

A *pick* is one seed entry resolved against its page: {'heading', 'items': [('p'|'sub', text)], 'source_id',
'images': [image ids]}. Long picks split on sub-heading boundaries first, then paragraph boundaries; short
neighbours merge (the later one's heading becomes a `## ` sub-heading). Text is never cut mid-sentence.
"""
import re

TARGET, MIN_WORDS, MAX_WORDS = 400, 200, 600
MAX_IMAGES_PER_LESSON = 3
SENTENCE = re.compile(r"(?<=[.!?])\s+(?=[\"'“‘(]?[A-Z0-9])")


def words(body: str) -> int:
    """CONTRACTS 2.2: image lines removed, `* # > -` treated as spaces."""
    lines = [l for l in body.splitlines() if not l.startswith("![](")]
    return len(re.sub(r"[*#>\-]", " ", "\n".join(lines)).split())


def item_words(items) -> int:
    return sum(words(t) for _, t in items)


def trim(items: list, max_words: int) -> list:
    """Shorten a pick to max_words: whole paragraphs, then whole sentences of the paragraph that would run
    over (when at least 40 words of budget are left). Never cuts mid-sentence; keeps at least one sentence."""
    out, w = [], 0
    for kind, text in items:
        n = words(text)
        if kind == "p" and w + n > max_words:
            budget, kept = max_words - w, []
            if budget >= 40 or not any(k == "p" for k, _ in out):
                for s in SENTENCE.split(text):
                    if kept and words(" ".join(kept + [s])) > budget:
                        break
                    kept.append(s)
                out.append(("p", " ".join(kept)))
            break
        out.append((kind, text))
        w += n
    while out and out[-1][0] == "sub":
        out.pop()
    return out


def _split_long_paragraph(text: str) -> list[str]:
    if words(text) <= MAX_WORDS:
        return [text]
    parts, cur = [], []
    for s in SENTENCE.split(text):
        if cur and words(" ".join(cur + [s])) > TARGET * 3 // 4:
            parts.append(" ".join(cur))
            cur = []
        cur.append(s)
    if cur:
        parts.append(" ".join(cur))
    return parts


def chunk(items: list) -> list[list]:
    items = [(k, p) for k, t in items for p in ([t] if k == "sub" else _split_long_paragraph(t))]
    if item_words(items) <= MAX_WORDS:
        return [items]
    chunks, cur, w = [], [], 0
    for n, (kind, text) in enumerate(items):
        iw = words(text)
        rest = item_words(items[n:])
        if cur and cur[-1][0] != "sub" and (
                w + iw > MAX_WORDS
                or (kind == "sub" and w >= TARGET * 3 // 4 and rest >= MIN_WORDS)
                or (kind == "p" and w >= TARGET and rest >= MIN_WORDS)):
            chunks.append(cur)
            cur, w = [], 0
        cur.append((kind, text))
        w += iw
    if cur:
        chunks.append(cur)
    if len(chunks) > 1 and item_words(chunks[-1]) < MIN_WORDS and \
            item_words(chunks[-2]) + item_words(chunks[-1]) <= MAX_WORDS + 100:
        tail = chunks.pop()  # pop first: `chunks[-2] += chunks.pop()` stores at the index after the list shrank
        chunks[-1] += tail
    return chunks


def _cap(h: str, n: int = 80) -> str:
    return h if len(h) <= n else h[: n - 1].rsplit(" ", 1)[0] + "…"


def plan_lessons(picks: list[dict]) -> list[dict]:
    """picks -> [{'heading', 'items', 'source_ids', 'image_ids'}] in order."""
    lessons = []
    for pk in picks:
        items = trim(pk["items"], pk["max_words"]) if pk.get("max_words") else pk["items"]
        if not any(k == "p" for k, _ in items):
            continue
        parts = chunk(items)
        imgs = list(pk.get("images") or [])
        for n, part in enumerate(parts):
            heading = pk["heading"]
            if n > 0:
                if part[0][0] == "sub":
                    heading, part = part[0][1], part[1:]
                else:
                    heading = f"{pk['heading']} (continued)"
            lessons.append({"heading": _cap(heading), "items": part, "source_ids": [pk["source_id"]],
                            "image_ids": imgs[n * MAX_IMAGES_PER_LESSON:(n + 1) * MAX_IMAGES_PER_LESSON]})
    # merge short neighbours
    out = []
    for les in lessons:
        prev = out[-1] if out else None
        if prev and (item_words(prev["items"]) < MIN_WORDS or item_words(les["items"]) < MIN_WORDS) and \
                item_words(prev["items"]) + item_words(les["items"]) <= MAX_WORDS:
            prev["items"] = prev["items"] + [("sub", les["heading"])] + les["items"]
            prev["source_ids"] += [s for s in les["source_ids"] if s not in prev["source_ids"]]
            prev["image_ids"] = (prev["image_ids"] + [i for i in les["image_ids"] if i not in prev["image_ids"]]
                                 )[:MAX_IMAGES_PER_LESSON]
        else:
            out.append({**les, "source_ids": list(les["source_ids"]), "image_ids": list(les["image_ids"])})
    return out


def body(items: list, inline_ids: list[str]) -> str:
    """Markdown subset body; inline images go between paragraphs, spread evenly, never right after a heading."""
    blocks = [f"## {t}" if k == "sub" else t for k, t in items]
    cands = [n for n, (k, _) in enumerate(items) if k == "p"][:-1]  # after a paragraph, never after the last
    slots, k = {}, len(inline_ids)
    for j, img in enumerate(inline_ids):
        free = [c for c in cands if c not in slots]
        if not free:
            break  # unplaced ids are shown after the last paragraph (CONTRACTS 2.2)
        want = round((j + 1) * len(cands) / (k + 1)) - 1
        slots[min(free, key=lambda c: abs(cands.index(c) - want))] = img
    out = []
    for n, b in enumerate(blocks):
        out.append(b)
        if n in slots:
            out.append(f"![]({slots[n]})")
    return "\n\n".join(out)


def placed_ids(text: str) -> list[str]:
    return re.findall(r"^!\[\]\((.+)\)$", text, re.M)
