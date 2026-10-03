from __future__ import annotations

import argparse
import hashlib
import json
import math
import re
import shutil
import sqlite3
import subprocess
import tempfile
from collections import Counter
from pathlib import Path

import numpy as np
from sklearn.cluster import MiniBatchKMeans

from corpus_pipeline.search_text import prepare_search_text

BOOK_SOURCE_ID = 'book:seven_church_ages'
BOOK_EDITION_ID = 'book:seven_church_ages'
BOOK_TITLE = 'Exposé des Sept Âges de l’Église'
BOOK_START_PAGE = 49668
BOOK_END_PAGE = 50044


def sha256_file(path: Path) -> str:
    h = hashlib.sha256()
    with path.open('rb') as f:
        for chunk in iter(lambda: f.read(1024 * 1024), b''):
            h.update(chunk)
    return h.hexdigest()


def add_column(con: sqlite3.Connection, table: str, declaration: str) -> None:
    name = declaration.split()[0]
    cols = {row[1] for row in con.execute(f'pragma table_info({table})')}
    if name not in cols:
        con.execute(f'alter table {table} add column {declaration}')


def extract_book_pages(pdf: Path) -> list[str]:
    with tempfile.NamedTemporaryFile(suffix='.txt', delete=False) as tmp:
        out = Path(tmp.name)
    try:
        subprocess.run([
            'pdftotext', '-f', str(BOOK_START_PAGE), '-l', str(BOOK_END_PAGE),
            '-raw', str(pdf), str(out)
        ], check=True)
        text = out.read_text(encoding='utf-8', errors='replace')
        pages = text.split('\f')
        if pages and not pages[-1].strip():
            pages.pop()
        expected = BOOK_END_PAGE - BOOK_START_PAGE + 1
        if len(pages) != expected:
            raise RuntimeError(f'book page extraction mismatch: {len(pages)} != {expected}')
        return [p.replace('\x00', '').strip() for p in pages]
    finally:
        out.unlink(missing_ok=True)


def book_chapters() -> list[tuple[str, int, int]]:
    starts = [
        ('Pages liminaires', 49668),
        ('La Révélation de Jésus-Christ', 49676),
        ('La Vision de Patmos', 49706),
        ('L’Âge de l’Église d’Éphèse', 49728),
        ('L’Âge de l’Église de Smyrne', 49769),
        ('L’Âge de l’Église de Pergame', 49815),
        ('L’Âge de l’Église de Thyatire', 49868),
        ('L’Âge de l’Église de Sardes', 49897),
        ('L’Âge de l’Église de Philadelphie', 49940),
        ('L’Âge de l’Église de Laodicée', 49971),
        ('Résumé des Âges', 50017),
    ]
    result = []
    for i, (title, start) in enumerate(starts):
        end = starts[i + 1][1] - 1 if i + 1 < len(starts) else BOOK_END_PAGE
        result.append((title, start, end))
    return result


def sentence_spans(text: str):
    start = 0
    ordinal = 0
    for match in re.finditer(r'[.!?…]+(?:[”»"\']*)|\n{2,}', text):
        end = match.end()
        s = start
        while s < end and text[s].isspace():
            s += 1
        e = end
        while e > s and text[e - 1].isspace():
            e -= 1
        if e - s >= 12:
            yield ordinal, s, e
            ordinal += 1
        start = match.end()
    s = start
    e = len(text)
    while s < e and text[s].isspace():
        s += 1
    while e > s and text[e - 1].isspace():
        e -= 1
    if e - s >= 2:
        yield ordinal, s, e


def encode_documents(texts: list[str], vocab_path: Path, components_path: Path) -> np.ndarray:
    vocab = json.loads(vocab_path.read_text(encoding='utf-8'))
    terms: list[str] = vocab['terms']
    idf = np.asarray(vocab['idf'], dtype=np.float32)
    dimensions = int(vocab['dimensions'])
    term_to_index = {term: i for i, term in enumerate(terms)}
    components = np.fromfile(components_path, dtype='<f4').reshape(dimensions, len(terms))
    vectors = np.zeros((len(texts), dimensions), dtype=np.float32)
    token_re = re.compile(r'\b[a-z0-9\']{2,}\b')
    for row, text in enumerate(texts):
        counts: Counter[int] = Counter()
        for token in token_re.findall(prepare_search_text(text)):
            idx = term_to_index.get(token)
            if idx is not None:
                counts[idx] += 1
        if not counts:
            continue
        idxs = np.fromiter(counts.keys(), dtype=np.int32)
        vals = np.array([(1.0 + math.log(counts[i])) * float(idf[i]) for i in idxs], dtype=np.float32)
        norm = float(np.linalg.norm(vals))
        if norm == 0:
            continue
        vals /= norm
        vec = components[:, idxs] @ vals
        vnorm = float(np.linalg.norm(vec))
        if vnorm:
            vec /= vnorm
        vectors[row] = vec.astype(np.float32)
    return vectors


def build(source_db: Path, target_db: Path, pdf: Path, semantic_source: Path, semantic_output: Path) -> dict:
    target_db.parent.mkdir(parents=True, exist_ok=True)
    shutil.copy2(source_db, target_db)
    con = sqlite3.connect(target_db)
    con.execute('pragma journal_mode=DELETE')
    con.execute('pragma synchronous=NORMAL')
    con.execute('pragma temp_store=MEMORY')

    add_column(con, 'passages', "source_id TEXT NOT NULL DEFAULT ''")
    add_column(con, 'passages', "source_type TEXT NOT NULL DEFAULT 'sermon'")
    add_column(con, 'passages', 'book_chapter_id INTEGER')
    con.execute("update passages set source_id='sermon:'||sermon_id where source_id='' or source_id is null")

    con.executescript('''
    CREATE TABLE IF NOT EXISTS sources(
      id TEXT PRIMARY KEY, source_type TEXT NOT NULL, title TEXT NOT NULL,
      code TEXT, year INTEGER, primary_edition_id TEXT, sort_key TEXT NOT NULL
    );
    CREATE TABLE IF NOT EXISTS book_chapters(
      id INTEGER PRIMARY KEY, source_id TEXT NOT NULL, title TEXT NOT NULL,
      ordinal INTEGER NOT NULL, source_page_start INTEGER NOT NULL, source_page_end INTEGER NOT NULL
    );
    CREATE TABLE IF NOT EXISTS sentences(
      sentence_id INTEGER PRIMARY KEY, passage_id INTEGER NOT NULL, ordinal INTEGER NOT NULL,
      start_offset INTEGER NOT NULL, end_offset INTEGER NOT NULL
    );
    CREATE INDEX IF NOT EXISTS idx_sentences_passage ON sentences(passage_id, ordinal);
    CREATE TABLE IF NOT EXISTS passage_neighbors(
      source_passage_id INTEGER NOT NULL, neighbor_passage_id INTEGER NOT NULL,
      similarity_score REAL NOT NULL, relation_scope TEXT NOT NULL, model_version TEXT NOT NULL,
      PRIMARY KEY(source_passage_id, neighbor_passage_id)
    );
    CREATE INDEX IF NOT EXISTS idx_neighbors_source ON passage_neighbors(source_passage_id, similarity_score DESC);
    CREATE TABLE IF NOT EXISTS term_stats(
      term TEXT PRIMARY KEY, document_count INTEGER NOT NULL, total_occurrences INTEGER NOT NULL
    );
    CREATE TABLE IF NOT EXISTS expression_stats(
      expression TEXT PRIMARY KEY, document_count INTEGER NOT NULL, total_occurrences INTEGER NOT NULL
    );
    CREATE TABLE IF NOT EXISTS semantic_clusters(
      passage_id INTEGER PRIMARY KEY, cluster_id INTEGER NOT NULL, model_version TEXT NOT NULL
    );
    CREATE TABLE IF NOT EXISTS source_metadata(
      source_id TEXT NOT NULL, key TEXT NOT NULL, value TEXT NOT NULL,
      PRIMARY KEY(source_id,key)
    );
    ''')

    con.execute('delete from sources')
    con.execute('''
      insert into sources(id,source_type,title,code,year,primary_edition_id,sort_key)
      select 'sermon:'||id,'sermon',title,code,year,primary_edition_id,code from sermons
    ''')
    con.execute('delete from book_chapters')
    con.execute('delete from passages where source_type="book"')
    con.execute('''insert into sources(id,source_type,title,code,year,primary_edition_id,sort_key)
                   values(?,?,?,?,?,?,?)''',
                (BOOK_SOURCE_ID, 'book', BOOK_TITLE, 'BOOK-SEVEN-AGES', None, BOOK_EDITION_ID, 'ZZZ-BOOK-SEVEN-AGES'))
    chapters = book_chapters()
    for idx, (title, start, end) in enumerate(chapters, start=1):
        con.execute('insert into book_chapters(id,source_id,title,ordinal,source_page_start,source_page_end) values(?,?,?,?,?,?)',
                    (idx, BOOK_SOURCE_ID, title, idx-1, start, end))

    pages = extract_book_pages(pdf)
    next_id = con.execute('select coalesce(max(id),0)+1 from passages').fetchone()[0]
    page_to_chapter = {}
    for idx, (_, start, end) in enumerate(chapters, start=1):
        for p in range(start, end+1):
            page_to_chapter[p] = idx
    book_rows = []
    for offset, text in enumerate(pages):
        page = BOOK_START_PAGE + offset
        clean = text.strip()
        if not clean:
            continue
        chapter_id = page_to_chapter[page]
        book_rows.append((next_id, BOOK_EDITION_ID, 0, offset, page, page, clean, BOOK_SOURCE_ID, 'book', chapter_id))
        next_id += 1
    con.executemany('''
      insert into passages(id,edition_id,sermon_id,ordinal,source_page_start,source_page_end,text_display,source_id,source_type,book_chapter_id)
      values(?,?,?,?,?,?,?,?,?,?)
    ''', book_rows)

    # Preserve the validated V2 FTS index for all sermon passages. Only the
    # newly added book passages are appended. Rebuilding 130M+ canonical
    # characters row-by-row in Python is both unnecessary and slow.
    con.executemany(
        'insert into passages_fts(rowid,text_search) values(?,?)',
        [(row[0], prepare_search_text(row[6])) for row in book_rows],
    )
    con.commit()

    # Sentences only for primary sermon editions plus books; text is reconstructed from canonical offsets.
    con.execute('delete from sentences')
    rows = con.execute('''
      select p.id,p.text_display from passages p
      left join editions e on e.id=p.edition_id
      where p.source_type='book' or e.is_primary=1
      order by p.id
    ''')
    sentence_batch = []
    sid = 1
    for pid, text in rows:
        for ordinal, start, end in sentence_spans(text):
            sentence_batch.append((sid, pid, ordinal, start, end))
            sid += 1
            if len(sentence_batch) >= 10000:
                con.executemany('insert into sentences(sentence_id,passage_id,ordinal,start_offset,end_offset) values(?,?,?,?,?)', sentence_batch)
                sentence_batch.clear()
    if sentence_batch:
        con.executemany('insert into sentences(sentence_id,passage_id,ordinal,start_offset,end_offset) values(?,?,?,?,?)', sentence_batch)

    # Compact concordance statistics directly from FTS5 vocabulary.
    con.execute('delete from term_stats')
    con.execute('drop table if exists _v3_vocab')
    con.execute("create virtual table _v3_vocab using fts5vocab(passages_fts, 'row')")
    con.execute('insert into term_stats(term,document_count,total_occurrences) select term,doc,cnt from _v3_vocab where length(term)>=2')
    con.execute('drop table _v3_vocab')
    con.execute('delete from expression_stats')

    # Extend the V2 semantic baseline to the book without retraining: book vectors use the same TF-IDF/LSA transform.
    semantic_output.mkdir(parents=True, exist_ok=True)
    for name in ['semantic_vocab.json', 'semantic_components.f32']:
        shutil.copy2(semantic_source / name, semantic_output / name)
    old_ids = np.fromfile(semantic_source / 'semantic_passage_ids.i32', dtype='<i4')
    vocab = json.loads((semantic_source / 'semantic_vocab.json').read_text(encoding='utf-8'))
    dims = int(vocab['dimensions'])
    old_vectors = np.fromfile(semantic_source / 'semantic_vectors.f32', dtype='<f4').reshape(-1, dims)
    book_ids = np.array([row[0] for row in book_rows], dtype=np.int32)
    book_texts = [row[6] for row in book_rows]
    book_vectors = encode_documents(book_texts, semantic_source / 'semantic_vocab.json', semantic_source / 'semantic_components.f32')
    ids = np.concatenate([old_ids, book_ids]).astype('<i4')
    vectors = np.vstack([old_vectors, book_vectors]).astype('<f4')
    ids.tofile(semantic_output / 'semantic_passage_ids.i32')
    vectors.tofile(semantic_output / 'semantic_vectors.f32')
    original_manifest = json.loads((semantic_source / 'semantic_manifest.json').read_text(encoding='utf-8'))
    semantic_manifest = dict(original_manifest)
    semantic_manifest['method'] = original_manifest['method'] + ' + V3 book projection using the unchanged LSA transform'
    semantic_manifest['documents'] = int(ids.shape[0])
    semantic_manifest['model_version'] = 'lsa64-v3-baseline'
    semantic_manifest['book_documents'] = int(book_ids.shape[0])
    semantic_manifest['files'] = {}
    for name in ['semantic_vocab.json', 'semantic_components.f32', 'semantic_vectors.f32', 'semantic_passage_ids.i32']:
        p = semantic_output / name
        semantic_manifest['files'][name] = {'bytes': p.stat().st_size, 'sha256': sha256_file(p)}
    (semantic_output / 'semantic_manifest.json').write_text(json.dumps(semantic_manifest, ensure_ascii=False, indent=2), encoding='utf-8')

    # Numeric clusters + precomputed local neighbors. These are retrieval aids only.
    cluster_count = 128
    kmeans = MiniBatchKMeans(n_clusters=cluster_count, random_state=42, batch_size=2048, n_init=3, max_iter=100)
    labels = kmeans.fit_predict(vectors)
    con.execute('delete from semantic_clusters')
    con.executemany('insert into semantic_clusters(passage_id,cluster_id,model_version) values(?,?,?)',
                    [(int(pid), int(label), 'lsa64-v3-baseline') for pid, label in zip(ids, labels)])
    con.execute('delete from passage_neighbors')
    source_by_id = dict(con.execute('select id,source_id from passages where id in (%s)' % ','.join('?'*len(ids)), [int(x) for x in ids]))
    neighbor_rows = []
    for cluster in range(cluster_count):
        positions = np.where(labels == cluster)[0]
        if len(positions) <= 1:
            continue
        matrix = vectors[positions]
        sims = matrix @ matrix.T
        np.fill_diagonal(sims, -2.0)
        take = min(8, len(positions)-1)
        top = np.argpartition(-sims, kth=take-1, axis=1)[:, :take]
        for local_i, choices in enumerate(top):
            ordered = choices[np.argsort(-sims[local_i, choices])]
            src_pid = int(ids[positions[local_i]])
            for local_j in ordered:
                dst_pid = int(ids[positions[int(local_j)]])
                score = float(sims[local_i, int(local_j)])
                scope = 'same_source' if source_by_id.get(src_pid) == source_by_id.get(dst_pid) else 'other_source'
                neighbor_rows.append((src_pid, dst_pid, score, scope, 'lsa64-v3-baseline'))
        if len(neighbor_rows) >= 20000:
            con.executemany('insert or ignore into passage_neighbors(source_passage_id,neighbor_passage_id,similarity_score,relation_scope,model_version) values(?,?,?,?,?)', neighbor_rows)
            neighbor_rows.clear()
    if neighbor_rows:
        con.executemany('insert or ignore into passage_neighbors(source_passage_id,neighbor_passage_id,similarity_score,relation_scope,model_version) values(?,?,?,?,?)', neighbor_rows)

    con.execute('delete from source_metadata')
    con.execute('insert into source_metadata(source_id,key,value) values(?,?,?)', (BOOK_SOURCE_ID, 'source_page_start', str(BOOK_START_PAGE)))
    con.execute('insert into source_metadata(source_id,key,value) values(?,?,?)', (BOOK_SOURCE_ID, 'source_page_end', str(BOOK_END_PAGE)))
    con.execute('insert into source_metadata(source_id,key,value) values(?,?,?)', (BOOK_SOURCE_ID, 'chapter_count', str(len(chapters))))

    passage_count = con.execute('select count(*) from passages').fetchone()[0]
    sermon_count = con.execute('select count(*) from sermons').fetchone()[0]
    edition_count = con.execute('select count(*) from editions').fetchone()[0]
    primary_count = con.execute("select count(*) from passages p join editions e on e.id=p.edition_id where e.is_primary=1").fetchone()[0]
    meta = {
        'schema_version': '3',
        'corpus_version': '2019.06-source / app-build-2026.09.20-v3',
        'sermon_count': str(sermon_count),
        'edition_count': str(edition_count),
        'passage_count': str(passage_count),
        'primary_passage_count': str(primary_count),
        'book_source_count': '1',
        'book_passage_count': str(len(book_rows)),
        'sentence_count': str(sid-1),
        'semantic_model_version': 'lsa64-v3-baseline',
    }
    for k, v in meta.items():
        con.execute("insert into corpus_meta(key,value) values(?,?) on conflict(key) do update set value=excluded.value", (k, v))
    con.commit()
    integrity = con.execute('pragma integrity_check').fetchone()[0]
    counts = {
        'sermons': sermon_count,
        'editions': edition_count,
        'passages': passage_count,
        'book_passages': len(book_rows),
        'sentences': sid-1,
        'neighbors': con.execute('select count(*) from passage_neighbors').fetchone()[0],
        'terms': con.execute('select count(*) from term_stats').fetchone()[0],
        'semantic_documents': int(ids.shape[0]),
        'sqlite_integrity': integrity,
    }
    con.close()
    return counts


def main() -> None:
    parser = argparse.ArgumentParser()
    parser.add_argument('source_db', type=Path)
    parser.add_argument('target_db', type=Path)
    parser.add_argument('pdf', type=Path)
    parser.add_argument('semantic_source', type=Path)
    parser.add_argument('semantic_output', type=Path)
    parser.add_argument('--report', type=Path)
    args = parser.parse_args()
    result = build(args.source_db, args.target_db, args.pdf, args.semantic_source, args.semantic_output)
    if args.report:
        args.report.parent.mkdir(parents=True, exist_ok=True)
        args.report.write_text(json.dumps(result, ensure_ascii=False, indent=2), encoding='utf-8')
    print(json.dumps(result, ensure_ascii=False, indent=2))


if __name__ == '__main__':
    main()
