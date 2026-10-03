from __future__ import annotations

import argparse
import hashlib
import json
import re
from dataclasses import asdict, dataclass
from pathlib import Path

import fitz  # PyMuPDF

BOOKMARK_RE = re.compile(
    r"^(?P<frn>FRN)?(?P<code>[0-9]{2}-[0-9]{4}[a-zA-Z]?)\s*[_ ]\s*(?P<title>.*?)(?:\.pdf)?$",
    re.I,
)


@dataclass
class Edition:
    edition_id: str
    sermon_code: str
    title: str
    bookmark_title: str
    source_level: int
    source_page_start: int
    source_page_end: int
    is_frn: bool
    is_primary: bool
    year: int | None
    raw_file: str = ""
    sha256: str = ""
    chars: int = 0
    pages: int = 0


def find_section(toc: list[list], title: str) -> tuple[int, int]:
    normalized = title.strip().lower()
    start = next(
        i
        for i, item in enumerate(toc)
        if item[0] == 1 and item[1].strip().lower() == normalized
    )
    end = next(
        (i for i, item in enumerate(toc[start + 1 :], start + 1) if item[0] == 1),
        len(toc),
    )
    return start, end


def main() -> None:
    parser = argparse.ArgumentParser(
        description="Extrait les prédications du PDF source en conservant les pages et les éditions."
    )
    parser.add_argument("pdf", type=Path)
    parser.add_argument("output", type=Path, help="Répertoire de travail de sortie")
    args = parser.parse_args()

    out = args.output.resolve()
    raw_dir = out / "sermons_raw"
    reports = out / "reports"
    raw_dir.mkdir(parents=True, exist_ok=True)
    reports.mkdir(parents=True, exist_ok=True)

    doc = fitz.open(args.pdf)
    toc = doc.get_toc(simple=True)
    start, end = find_section(toc, "Sermons en ordre chronologique")

    year: int | None = None
    raw: list[dict] = []
    for level, title, page in toc[start + 1 : end]:
        if level == 2 and title.strip().isdigit():
            year = int(title.strip())
            continue
        if level < 3:
            continue
        match = BOOKMARK_RE.match(title.strip())
        if not match:
            continue
        raw.append(
            {
                "level": level,
                "bookmark_title": title.strip(),
                "page": page,
                "code": match.group("code").upper(),
                "title": match.group("title").strip(" _"),
                "is_frn": bool(match.group("frn")),
                "year": year,
            }
        )

    raw.sort(key=lambda row: row["page"])
    expose_start = next(
        item[2]
        for item in toc
        if item[0] == 1 and item[1].strip().lower().startswith("exposé du sept")
    )

    by_code: dict[str, list[dict]] = {}
    for row in raw:
        by_code.setdefault(row["code"], []).append(row)

    editions: list[Edition] = []
    for index, row in enumerate(raw):
        end_page = raw[index + 1]["page"] - 1 if index + 1 < len(raw) else expose_start - 1
        variants = by_code[row["code"]]
        primary = next((candidate for candidate in variants if not candidate["is_frn"]), variants[0])
        flavor = "frn" if row["is_frn"] else "std"
        edition_id = f"{row['code'].lower()}__{flavor}__p{row['page']:05d}"
        editions.append(
            Edition(
                edition_id=edition_id,
                sermon_code=row["code"],
                title=row["title"],
                bookmark_title=row["bookmark_title"],
                source_level=row["level"],
                source_page_start=row["page"],
                source_page_end=end_page,
                is_frn=row["is_frn"],
                is_primary=row is primary,
                year=row["year"],
                pages=end_page - row["page"] + 1,
            )
        )

    for index, edition in enumerate(editions, 1):
        target = raw_dir / f"{edition.edition_id}.txt"
        if target.exists() and target.stat().st_size > 20:
            text = target.read_text(encoding="utf-8", errors="replace")
        else:
            pages: list[str] = []
            for page_number in range(edition.source_page_start, edition.source_page_end + 1):
                page_text = doc.load_page(page_number - 1).get_text("text")
                # Glyph decorative known in one publisher edition. It is not sermon content.
                pages.append(page_text.replace("\uf6e1", "").rstrip())
            text = "\n\f\n".join(pages).strip() + "\n"
            target.write_text(text, encoding="utf-8")

        payload = text.encode("utf-8")
        edition.raw_file = target.name
        edition.sha256 = hashlib.sha256(payload).hexdigest()
        edition.chars = len(text)
        if index % 100 == 0 or index == len(editions):
            print(f"{index}/{len(editions)} éditions extraites", flush=True)

    sermons: list[dict] = []
    grouped: dict[str, list[Edition]] = {}
    for edition in editions:
        grouped.setdefault(edition.sermon_code, []).append(edition)

    for code, variants in sorted(grouped.items()):
        primary = next((edition for edition in variants if edition.is_primary), variants[0])
        sermons.append(
            {
                "sermon_code": code,
                "title": primary.title,
                "edition_ids": [edition.edition_id for edition in variants],
                "edition_count": len(variants),
                "primary_edition_id": primary.edition_id,
            }
        )

    inventory = {
        "pdf": args.pdf.name,
        "pdf_pages": doc.page_count,
        "toc_entries": len(toc),
        "expose_start_page": expose_start,
        "edition_count": len(editions),
        "unique_sermon_codes": len(grouped),
        "multi_edition_sermons": sum(1 for variants in grouped.values() if len(variants) > 1),
        "total_extracted_chars": sum(edition.chars for edition in editions),
        "total_sermon_pages": sum(edition.pages for edition in editions),
        "extractor": "PyMuPDF get_text(text), decorative U+F6E1 removed",
    }

    (reports / "inventory.json").write_text(
        json.dumps(inventory, ensure_ascii=False, indent=2), encoding="utf-8"
    )
    (reports / "editions.json").write_text(
        json.dumps([asdict(edition) for edition in editions], ensure_ascii=False, indent=2),
        encoding="utf-8",
    )
    (reports / "sermons.json").write_text(
        json.dumps(sermons, ensure_ascii=False, indent=2), encoding="utf-8"
    )
    print(json.dumps(inventory, ensure_ascii=False, indent=2))


if __name__ == "__main__":
    main()
