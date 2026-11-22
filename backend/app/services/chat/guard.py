"""Injection pre-filter (CONTRACTS 4.1 step 4) and the fail-closed output check (step 8, D20).

The pre-filter is cheap and not relied on: the system prompt and the output check do the real work.
The output check turns anything it cannot fully trust into the fixed, server-built refusal.
"""
import re
import unicodedata
from dataclasses import dataclass

MAX_TEXT = 1200
_ZERO_WIDTH = dict.fromkeys(map(ord, "​‌‍⁠﻿­"), None)

# Known injection phrasings, matched on normalised text (NFKC, lower case, zero-width removed, spaces collapsed).
INJECTION_PATTERNS = [re.compile(p) for p in (
    r"\b(ignore|disregard|forget|override|bypass)\b(\W+\w+){0,4}\W+(instructions?|rules|prompts?|directions|guidelines)\b",
    r"\bsystem\s*(prompt|message|instructions?)\b",
    r"\byou\s+are\s+now\b",
    r"\bdeveloper\s+mode\b",
    r"\bjail\s*break",
    r"\b(reveal|show|print|repeat|output|tell me|translate|summari[sz]e)\b(\W+\w+){0,4}\W+(your|the above|previous|prior|initial|hidden|secret)\W+(instructions?|rules|prompts?)\b",
    r"\bpretend\s+(to\s+be|you\s+are)\b",
    r"\b(new|updated)\s+instructions?\s*:",
    r"\bdo\s+anything\s+now\b",
)]


def normalise(text: str) -> str:
    t = unicodedata.normalize("NFKC", text).translate(_ZERO_WIDTH).lower()
    return re.sub(r"\s+", " ", t).strip()


def looks_like_injection(text: str) -> bool:
    t = normalise(text)
    return any(p.search(t) for p in INJECTION_PATTERNS)


# ---------- output check ----------

LESSONS_LINE = re.compile(r"^\s*\**\s*lessons?\s*\**\s*:\s*\**\s*(.*?)\s*\**\s*\.?\s*$", re.IGNORECASE)
_NUM_LIST = re.compile(r"^\d+(\s*(,|and)\s*\d+)*$", re.IGNORECASE)
_URL = re.compile(r"https?|www\.|://", re.IGNORECASE)
_SENTENCE_END = re.compile(r"[.!?](?=\s|$)")


@dataclass(frozen=True)
class Checked:
    ok: bool
    text: str = ""
    lesson_numbers: tuple[int, ...] = ()
    reason: str = ""  # short code for logs


def strip_markup(text: str) -> str:
    """Model text to plain text: no markdown, no HTML, single spaces."""
    t = re.sub(r"<[^>]{0,200}>", " ", text)                      # HTML tags
    t = re.sub(r"!?\[([^\]]*)\]\([^)]*\)", r"\1", t)              # [text](target), ![alt](src)
    t = re.sub(r"(?m)^\s{0,3}(#{1,6}\s+|>\s?|[-*+]\s+|\d+[.)]\s+)", "", t)  # headings, quotes, bullets, numbered
    t = re.sub(r"(\*\*|__|\*|`+|~~)", "", t)                     # emphasis, code, strike
    t = re.sub(r"(?<!\w)_(\S[^_]*\S|\S)_(?!\w)", r"\1", t)        # _italic_
    return re.sub(r"\s+", " ", t).strip()


def cut_to_limit(text: str, limit: int = MAX_TEXT) -> str | None:
    """Text within `limit`, cut at the last sentence end before it; None if there is no sentence end to cut at."""
    if len(text) <= limit:
        return text
    head = text[:limit]
    ends = [m.end() for m in _SENTENCE_END.finditer(head)]
    return head[:ends[-1]].rstrip() if ends else None


def check_output(raw: str, canary: str, allowed_lessons: set[int]) -> Checked:
    """CONTRACTS 4.1 step 8. Fails closed: any doubt -> ok=False (the caller sends the fixed refusal)."""
    if not raw or not raw.strip():
        return Checked(False, reason="empty")
    flat = normalise(raw)
    if "out_of_scope" in flat or "out of scope" in flat:
        return Checked(False, reason="model_out_of_scope")
    squashed = re.sub(r"[\s\W_]+", "", flat)
    if canary.lower() in squashed:
        return Checked(False, reason="canary")
    if "title text" in flat:  # names the prompt's context block: prompt talk, not an answer
        return Checked(False, reason="prompt_talk")

    lines = [l for l in raw.strip().splitlines() if l.strip()]
    m = LESSONS_LINE.match(lines[-1]) if lines else None
    if not m:
        return Checked(False, reason="no_lessons_line")
    nums_text = m.group(1).strip()
    if not _NUM_LIST.match(nums_text):
        return Checked(False, reason="bad_lessons_line")
    nums: list[int] = []
    for n in re.findall(r"\d+", nums_text):
        if int(n) not in nums:
            nums.append(int(n))
    if not 1 <= len(nums) <= 3 or any(n not in allowed_lessons for n in nums):
        return Checked(False, reason="bad_lesson_numbers")

    body = "\n".join(lines[:-1])
    if any(LESSONS_LINE.match(l) for l in lines[:-1]):
        return Checked(False, reason="extra_lessons_line")
    if _URL.search(body):
        return Checked(False, reason="url")
    text = strip_markup(body)
    if not text:
        return Checked(False, reason="empty_body")
    text = cut_to_limit(text)
    if not text:
        return Checked(False, reason="too_long")
    return Checked(True, text=text, lesson_numbers=tuple(nums))
