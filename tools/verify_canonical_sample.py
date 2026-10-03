from __future__ import annotations

import argparse
import hashlib
import json
import random
import re
import sqlite3
from pathlib import Path

import fitz

SPACE = re.compile(r"\s+")


def norm(value: str) -> str:
    value = value.replace("\uf6e1", "")
    value = "".join(ch for ch in value if ch in "\n\r\t\f" or ord(ch) >= 32)
    return SPACE.sub(" ", value).strip()


def sha256(path: Path) -> str:
    h = hashlib.sha256()
    with path.open("rb") as f:
        for chunk in iter(lambda: f.read(1024 * 1024), b""):
            h.update(chunk)
    return h.hexdigest()


def main() -> None:
    parser = argparse.ArgumentParser(description="Vérifie un échantillon du texte canonique contre le PDF source.")
    parser.add_argument("database", type=Path)
    parser.add_argument("pdf", type=Path)
    parser.add_argument("output", type=Path)
    parser.add_argument("--samples", type=int, default=100)
    parser.add_argument("--seed", type=int, default=20260920)
    args = parser.parse_args()

    con = sqlite3.connect(args.database)
    ids = [row[0] for row in con.execute("SELECT id FROM passages ORDER BY id")]
    rng = random.Random(args.seed)
    selected = {ids[0], ids[-1]}
    if args.samples > 2:
        selected.update(rng.sample(ids[1:-1], min(args.samples - 2, len(ids) - 2)))
    selected = sorted(selected)

    doc = fitz.open(args.pdf)
    checked: list[dict] = []
    failures: list[dict] = []
    for passage_id in selected:
        row = con.execute(
            "SELECT edition_id,source_page_start,source_page_end,text_display FROM passages WHERE id=?",
            (passage_id,),
        ).fetchone()
        edition_id, start, end, display = row
        source = "\n".join(
            doc.load_page(page - 1).get_text("text").replace("\uf6e1", "")
            for page in range(start, end + 1)
        )
        display_n = norm(display)
        source_n = norm(source)
        ok = bool(display_n) and display_n in source_n
        item = {
            "passage_id": passage_id,
            "edition_id": edition_id,
            "page_start": start,
            "page_end": end,
            "display_chars": len(display),
            "match": ok,
        }
        checked.append(item)
        if not ok:
            failures.append(item)

    con.close()
    doc.close()
    report = {
        "status": "OK" if not failures else "ERROR",
        "method": "deterministic whitespace-normalized substring comparison of text_display against PyMuPDF get_text(text) on the recorded source pages; decorative U+F6E1 ignored",
        "seed": args.seed,
        "samples_requested": args.samples,
        "samples_checked": len(checked),
        "matches": len(checked) - len(failures),
        "failures": failures,
        "source_pdf": args.pdf.name,
        "source_pdf_sha256": sha256(args.pdf),
        "sample_passages": checked,
    }
    args.output.parent.mkdir(parents=True, exist_ok=True)
    args.output.write_text(json.dumps(report, ensure_ascii=False, indent=2), encoding="utf-8")
    print(json.dumps({k: report[k] for k in report if k != "sample_passages"}, ensure_ascii=False, indent=2))
    if failures:
        raise SystemExit(1)


if __name__ == "__main__":
    main()
