"""Content CLI. Run from backend/:
    python -m ingest.cli wiki <id> [<id> ...] | --all   Wikipedia + Wikidata + Commons -> data/titles/<id>.json (draft)
    python -m ingest.cli check <id | file.json>          publish gate G1 to G10 (CONTRACTS 9.3); exit 1 if it fails
    python -m ingest.cli import <file.json>              load one title file (refused if invalid, or published
                                                         and failing the gate)
    python -m ingest.cli seed-samples                    load data/samples/*.json
`wiki` options: --no-download (skip copying images to backend/media), --refresh (ignore the HTTP cache),
--delay SECONDS between requests (default 1.0), --force (overwrite a title that is already reviewed/published).
"""
import argparse
import json
import sys
from pathlib import Path

from app.config import BACKEND_DIR, settings
from app.db import SessionLocal
from ingest import gate
from ingest.build import SeedError, build
from ingest.client import WikiClient
from ingest.import_title import ImportRefused, import_file

SEED = Path(__file__).resolve().parent / "seed.json"
TITLES_DIR = BACKEND_DIR / "data" / "titles"


def make_client(args) -> WikiClient:
    """Separate so tests can swap in a client with a mock transport. Never faster than 2 requests a second."""
    return WikiClient(delay=max(0.5, args.delay), refresh=args.refresh)


def write_json(path: Path, data: dict):
    path.parent.mkdir(parents=True, exist_ok=True)
    with open(path, "w", encoding="utf-8", newline="\n") as f:
        f.write(json.dumps(data, ensure_ascii=False, indent=2) + "\n")


def _resolve(target: str) -> Path:
    p = Path(target)
    return p if p.suffix == ".json" else TITLES_DIR / f"{target}.json"


def print_report(rep: dict, gate_rep: gate.Report, out: Path):
    print(f"== {rep['title_id']} -> {out}")
    for pg in rep["pages"]:
        print(f"   page  {pg['title']} (rev {pg['revid']}) {pg['url']}")
    wd = rep["wikidata"] or {}
    if wd.get("qid"):
        print(f"   wikidata {wd['qid']} {wd.get('label')!r}: start {wd['period_start']} ({wd['start_prop']}), "
              f"end {wd['period_end']} ({wd['end_prop']}), image {wd['image']!r}")
    for les in rep["lessons"]:
        print(f"   {les['id']}  {les['words']:>4} words  {les['images']} img  {les['heading']}")
    print(f"   images rejected: {len(rep['rejected'])}")
    for r in rep["rejected"]:
        print(f"      - {r['file']}: {r['reason']}")
    for w in rep["warnings"]:
        print(f"   WARNING {w}")
    print("   gate: " + ("PASS" if gate_rep.ok else "FAIL (draft written; fix before publishing)"))
    for line in gate_rep.lines():
        print("      " + line)


def cmd_wiki(args) -> int:
    seeds = {t["id"]: t for t in json.loads(Path(args.seed).read_text("utf-8"))["titles"]}
    ids = list(seeds) if args.all else args.ids
    unknown = [i for i in ids if i not in seeds]
    if unknown or not ids:
        print(f"unknown or missing title id(s): {unknown or '(none given)'}; seed has {sorted(seeds)}")
        return 2
    failed = 0
    with make_client(args) as client:
        for tid in ids:
            out = Path(args.out) / f"{tid}.json"
            existing = json.loads(out.read_text("utf-8")) if out.is_file() else None
            if existing and existing.get("status") in ("reviewed", "published") and not args.force:
                print(f"{tid}: {out} is {existing['status']}; re-ingesting could change published ids. "
                      f"Use --force to overwrite.")
                failed += 1
                continue
            try:
                draft, rep = build(seeds[tid], client, existing=existing, media_dir=Path(settings.media_dir),
                                   media_base_url=settings.media_base_url, download=not args.no_download)
            except (SeedError, LookupError) as e:
                print(f"{tid}: {e}")
                failed += 1
                continue
            g = gate.check(draft)
            if g.rules() & {"G1"}:
                failed += 1  # a draft that is not even valid import format is a bug: still written for inspection
            write_json(out, draft)
            print_report(rep, g, out)
        print(f"(network requests this run: {client.requests})")
    return 1 if failed else 0


def cmd_check(args) -> int:
    path = _resolve(args.target)
    if not path.is_file():
        print(f"no such title file: {path}")
        return 2
    rep = gate.check(json.loads(path.read_text("utf-8")))
    print(f"{rep.title_id}: {'PASS' if rep.ok else 'FAIL'} publish gate")
    for line in rep.lines():
        print("   " + line)
    return 0 if rep.ok else 1


def cmd_import(files: list[Path]) -> int:
    failed = 0
    with SessionLocal() as db:
        for f in files:
            try:
                print(f"{f.name}: {import_file(db, f)}")
            except ImportRefused as e:
                failed += 1
                print(f"{f.name}: REFUSED")
                for line in e.problems:
                    print("   " + line)
    return 1 if failed else 0


def main(argv=None) -> int:
    for stream in (sys.stdout, sys.stderr):
        if hasattr(stream, "reconfigure"):
            stream.reconfigure(encoding="utf-8")  # page titles and credits are not cp1252
    p = argparse.ArgumentParser(prog="ingest.cli")
    sub = p.add_subparsers(dest="cmd", required=True)
    sub.add_parser("seed-samples")
    sub.add_parser("import").add_argument("file", type=Path)
    sub.add_parser("check").add_argument("target")
    w = sub.add_parser("wiki")
    w.add_argument("ids", nargs="*")
    w.add_argument("--all", action="store_true")
    w.add_argument("--seed", default=str(SEED))
    w.add_argument("--out", default=str(TITLES_DIR))
    w.add_argument("--no-download", action="store_true")
    w.add_argument("--refresh", action="store_true")
    w.add_argument("--force", action="store_true")
    w.add_argument("--delay", type=float, default=1.0)
    args = p.parse_args(argv)
    if args.cmd == "wiki":
        return cmd_wiki(args)
    if args.cmd == "check":
        return cmd_check(args)
    files = sorted((BACKEND_DIR / "data" / "samples").glob("*.json")) if args.cmd == "seed-samples" else [args.file]
    return cmd_import(files)


if __name__ == "__main__":
    sys.exit(main())
