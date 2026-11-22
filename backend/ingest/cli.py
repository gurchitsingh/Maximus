"""Small import command. Run from backend/:
    python -m ingest.cli seed-samples          load data/samples/*.json
    python -m ingest.cli import <file.json>    load one title file
(S11 adds the Wikipedia fetch and the publish gate to this CLI.)
"""
import argparse
import sys
from pathlib import Path

from app.config import BACKEND_DIR
from app.db import SessionLocal
from ingest.import_title import import_file


def main(argv=None) -> int:
    p = argparse.ArgumentParser(prog="ingest.cli")
    sub = p.add_subparsers(dest="cmd", required=True)
    sub.add_parser("seed-samples")
    sub.add_parser("import").add_argument("file", type=Path)
    args = p.parse_args(argv)
    files = sorted((BACKEND_DIR / "data" / "samples").glob("*.json")) if args.cmd == "seed-samples" else [args.file]
    with SessionLocal() as db:
        for f in files:
            print(f"{f.name}: {import_file(db, f)}")
    return 0


if __name__ == "__main__":
    sys.exit(main())
