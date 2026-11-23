"""Shared helpers for tools that edit data/titles/<id>.json in place (merge, review, publish, people)."""
import json
import os
import re
from pathlib import Path

from ingest import gate

SLUG = re.compile(r"^[a-z0-9]+(?:-[a-z0-9]+)*$")


class UsageError(ValueError):
    """The command cannot even start (bad id, missing file): CLI exit 2."""


def title_path(title_id: str, titles_dir: Path) -> Path:
    if not SLUG.match(title_id or ""):
        raise UsageError(f"{title_id!r} is not a title id (lower-case slug such as roman-history)")
    return Path(titles_dir) / f"{title_id}.json"


def load_title(title_id: str, titles_dir: Path) -> tuple[Path, dict]:
    path = title_path(title_id, titles_dir)
    if not path.is_file():
        raise UsageError(f"no title file for {title_id}: {path}")
    try:
        title = json.loads(path.read_text("utf-8-sig"))
    except json.JSONDecodeError as e:
        raise UsageError(f"{path.name} is not valid JSON: {e.msg} (line {e.lineno}, column {e.colno})")
    if not isinstance(title, dict) or title.get("id") != title_id:
        found = title.get("id") if isinstance(title, dict) else None
        raise UsageError(f"{path.name} has id {found!r}, expected {title_id!r}")
    return path, title


def write_json(path: Path, data) -> None:
    """Atomic: temp file in the same folder, then rename. Same format as ingest.cli (2 spaces, LF, UTF-8)."""
    path.parent.mkdir(parents=True, exist_ok=True)
    tmp = path.with_name(path.name + ".tmp")
    with open(tmp, "w", encoding="utf-8", newline="\n") as f:
        f.write(json.dumps(data, ensure_ascii=False, indent=2) + "\n")
    os.replace(tmp, path)


def valid_before(title: dict, path: Path) -> list[str]:
    return [f"{path.name} is not valid before the change (fix it first): {e}" for e in gate.g1_errors(title)]


def rejected_path(title_id: str, titles_dir: Path) -> Path:
    """Log of items the owner rejected in review (data/rejected/<id>.json): keeps ids from being reused and keeps
    a re-drafted copy of the same question from coming back."""
    return Path(titles_dir).parent / "rejected" / f"{title_id}.json"


def load_rejected(title_id: str, titles_dir: Path) -> list[dict]:
    p = rejected_path(title_id, titles_dir)
    return json.loads(p.read_text("utf-8")) if p.is_file() else []
