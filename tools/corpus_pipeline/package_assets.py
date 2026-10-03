from __future__ import annotations

import argparse
import hashlib
import json
import shutil
from pathlib import Path

PART_SIZE = 8 * 1024 * 1024


def sha(path: Path) -> str:
    return hashlib.sha256(path.read_bytes()).hexdigest()


def main() -> None:
    parser = argparse.ArgumentParser(description="Prépare les assets corpus pour Flutter.")
    parser.add_argument("database", type=Path)
    parser.add_argument("semantic_dir", type=Path)
    parser.add_argument("output", type=Path)
    parser.add_argument("--corpus-version", default="2019.06-source__app-2026.09.20-v2")
    args = parser.parse_args()

    output = args.output.resolve()
    parts_dir = output / "db_parts"
    if output.exists():
        shutil.rmtree(output)
    parts_dir.mkdir(parents=True, exist_ok=True)

    parts: list[dict] = []
    with args.database.open("rb") as source:
        index = 0
        while True:
            payload = source.read(PART_SIZE)
            if not payload:
                break
            name = f"corpus.db.part{index:03d}"
            path = parts_dir / name
            path.write_bytes(payload)
            parts.append({"name": name, "bytes": len(payload), "sha256": sha(path)})
            index += 1

    for filename in [
        "semantic_vocab.json",
        "semantic_components.f32",
        "semantic_vectors.f32",
        "semantic_passage_ids.i32",
        "semantic_manifest.json",
    ]:
        shutil.copy2(args.semantic_dir / filename, output / filename)

    semantic_manifest = json.loads((output / "semantic_manifest.json").read_text(encoding="utf-8"))
    import sqlite3

    connection = sqlite3.connect(args.database)
    meta = dict(connection.execute("SELECT key,value FROM corpus_meta"))
    connection.close()

    manifest = {
        "corpus_version": args.corpus_version,
        "schema_version": int(meta.get("schema_version", "1")),
        "database_file": "corpus.db",
        "database_bytes": args.database.stat().st_size,
        "database_sha256": sha(args.database),
        "parts": parts,
        "stats": {
            "sermons": int(meta["sermon_count"]),
            "editions": int(meta["edition_count"]),
            "passages": int(meta["passage_count"]),
            "primary_passages": int(meta["primary_passage_count"]),
            "source_pdf_pages": int(meta["source_pdf_pages"]),
            "book_sources": int(meta.get("book_source_count", "0")),
            "book_passages": int(meta.get("book_passage_count", "0")),
            "sentences": int(meta.get("sentence_count", "0")),
        },
        "search_filter": {
            "version": meta.get("search_filter_version", "none"),
            "filtered_passages": int(meta.get("search_filtered_passages", "0")),
            "empty_passages": int(meta.get("search_empty_passages", "0")),
            "removed_characters": int(meta.get("search_removed_chars", "0")),
        },
        "semantic": {
            "method": semantic_manifest["method"],
            "features": semantic_manifest["features"],
            "dimensions": semantic_manifest["dimensions"],
            "documents": semantic_manifest["documents"],
            "search_filter_version": semantic_manifest.get("search_filter_version", "none"),
        },
    }
    (output / "manifest.json").write_text(
        json.dumps(manifest, ensure_ascii=False, indent=2), encoding="utf-8"
    )
    print(json.dumps(manifest, ensure_ascii=False, indent=2))


if __name__ == "__main__":
    main()
