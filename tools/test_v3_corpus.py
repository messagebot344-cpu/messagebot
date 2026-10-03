from __future__ import annotations

import argparse
import hashlib
import json
import sqlite3
from pathlib import Path

REQUIRED_TABLES = {
    'sources', 'book_chapters', 'sentences', 'passage_neighbors',
    'term_stats', 'expression_stats', 'semantic_clusters', 'source_metadata',
}


def sha256(path: Path) -> str:
    h = hashlib.sha256()
    with path.open('rb') as f:
        for chunk in iter(lambda: f.read(1024 * 1024), b''):
            h.update(chunk)
    return h.hexdigest()


def validate(db_path: Path, manifest_path: Path | None = None) -> dict:
    con = sqlite3.connect(db_path)
    tables = {r[0] for r in con.execute("select name from sqlite_master where type in ('table','view')")}
    missing = sorted(REQUIRED_TABLES - tables)
    if missing:
        raise AssertionError(f'missing V3 tables: {missing}')
    integrity = con.execute('pragma integrity_check').fetchone()[0]
    assert integrity == 'ok', integrity
    sermons = con.execute('select count(*) from sermons').fetchone()[0]
    assert sermons == 1211, sermons
    books = con.execute("select count(*) from sources where source_type='book'").fetchone()[0]
    assert books >= 1, books
    exposed = con.execute("select count(*) from sources where source_type='book' and title like '%Sept%Âges%'").fetchone()[0]
    assert exposed == 1, exposed
    book_passages = con.execute("select count(*) from passages where source_type='book'").fetchone()[0]
    assert book_passages > 50, book_passages
    sentence_count = con.execute('select count(*) from sentences').fetchone()[0]
    assert sentence_count > 100000, sentence_count
    bad_offsets = con.execute('''
        select count(*) from sentences s join passages p on p.id=s.passage_id
        where s.start_offset < 0 or s.end_offset > length(p.text_display)
           or s.start_offset >= s.end_offset
    ''').fetchone()[0]
    assert bad_offsets == 0, bad_offsets
    bad_sentence_slices = con.execute('''
        select count(*) from sentences s join passages p on p.id=s.passage_id
        where length(substr(p.text_display, s.start_offset+1, s.end_offset-s.start_offset)) = 0
    ''').fetchone()[0]
    assert bad_sentence_slices == 0, bad_sentence_slices
    fts_rows = con.execute('select count(*) from passages_fts').fetchone()[0]
    passages = con.execute('select count(*) from passages').fetchone()[0]
    assert fts_rows == passages, (fts_rows, passages)
    neighbors = con.execute('select count(*) from passage_neighbors').fetchone()[0]
    assert neighbors > 100000, neighbors
    broken_neighbors = con.execute('''
        select count(*) from passage_neighbors n
        left join passages p1 on p1.id=n.source_passage_id
        left join passages p2 on p2.id=n.neighbor_passage_id
        where p1.id is null or p2.id is null or n.source_passage_id=n.neighbor_passage_id
    ''').fetchone()[0]
    assert broken_neighbors == 0, broken_neighbors
    terms = con.execute('select count(*) from term_stats').fetchone()[0]
    assert terms > 1000, terms
    meta = dict(con.execute('select key,value from corpus_meta'))
    assert meta.get('schema_version') == '3', meta.get('schema_version')
    assert meta.get('sermon_count') == '1211', meta.get('sermon_count')
    con.close()

    result = {
        'status': 'OK', 'sqlite_integrity': integrity, 'sermons': sermons,
        'books': books, 'book_passages': book_passages, 'passages': passages,
        'sentences': sentence_count, 'neighbors': neighbors, 'terms': terms,
    }
    if manifest_path:
        manifest = json.loads(manifest_path.read_text(encoding='utf-8'))
        assert manifest['database_bytes'] == db_path.stat().st_size
        assert manifest['database_sha256'] == sha256(db_path)
        result['manifest_sha256'] = 'OK'
    return result


def main() -> None:
    parser = argparse.ArgumentParser()
    parser.add_argument('database', type=Path)
    parser.add_argument('--manifest', type=Path)
    args = parser.parse_args()
    print(json.dumps(validate(args.database, args.manifest), ensure_ascii=False, indent=2))


if __name__ == '__main__':
    main()
