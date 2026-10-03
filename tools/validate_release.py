from __future__ import annotations

import argparse
import hashlib
import json
import sqlite3
import tempfile
from pathlib import Path


def sha256(path: Path) -> str:
    digest = hashlib.sha256()
    with path.open('rb') as handle:
        for chunk in iter(lambda: handle.read(1024 * 1024), b''):
            digest.update(chunk)
    return digest.hexdigest()


def fail(message: str) -> None:
    raise SystemExit(f'ERREUR: {message}')


def main() -> None:
    parser = argparse.ArgumentParser(description='Valide les assets du livrable Le Grenier du Message.')
    parser.add_argument('project', nargs='?', type=Path, default=Path(__file__).resolve().parents[1])
    args = parser.parse_args()
    project = args.project.resolve()
    corpus = project / 'assets' / 'corpus'
    manifest_path = corpus / 'manifest.json'
    if not manifest_path.exists():
        fail(f'manifest absent: {manifest_path}')
    manifest = json.loads(manifest_path.read_text(encoding='utf-8'))

    expected_total = manifest['database_bytes']
    parts = manifest['parts']
    total = 0
    with tempfile.TemporaryDirectory(prefix='grenier_validate_') as tmp:
        assembled = Path(tmp) / 'corpus.db'
        with assembled.open('wb') as target:
            for part in parts:
                path = corpus / 'db_parts' / part['name']
                if not path.exists():
                    fail(f"morceau absent: {part['name']}")
                if path.stat().st_size != part['bytes']:
                    fail(f"taille incorrecte: {part['name']}")
                if sha256(path) != part['sha256']:
                    fail(f"SHA-256 incorrect: {part['name']}")
                payload = path.read_bytes()
                target.write(payload)
                total += len(payload)

        if total != expected_total:
            fail(f'taille assemblée {total}, attendue {expected_total}')
        actual_db_sha = sha256(assembled)
        if actual_db_sha != manifest['database_sha256']:
            fail('SHA-256 de corpus.db assemblé incorrect')

        connection = sqlite3.connect(assembled)
        integrity = connection.execute('PRAGMA integrity_check').fetchone()[0]
        meta = dict(connection.execute('SELECT key,value FROM corpus_meta'))
        counts = {
            'sermons': connection.execute('SELECT count(*) FROM sermons').fetchone()[0],
            'editions': connection.execute('SELECT count(*) FROM editions').fetchone()[0],
            'passages': connection.execute('SELECT count(*) FROM passages').fetchone()[0],
            'fts_rows': connection.execute('SELECT count(*) FROM passages_fts').fetchone()[0],
        }
        primary_passages = connection.execute(
            'SELECT count(*) FROM passages p JOIN editions e ON e.id=p.edition_id WHERE e.is_primary=1'
        ).fetchone()[0]
        lexical_smoke = {
            'foi': connection.execute(
                "SELECT count(*) FROM passages_fts WHERE passages_fts MATCH 'foi'"
            ).fetchone()[0],
            'bapteme': connection.execute(
                "SELECT count(*) FROM passages_fts WHERE passages_fts MATCH 'bapteme'"
            ).fetchone()[0],
            'ordinateur_quantique': connection.execute(
                "SELECT count(*) FROM passages_fts WHERE passages_fts MATCH 'ordinateur AND quantique'"
            ).fetchone()[0],
            'publisher_unique_token': connection.execute(
                "SELECT count(*) FROM passages_fts WHERE passages_fts MATCH 'shekinahgospelmissions'"
            ).fetchone()[0],
        }
        bad_controls = 0
        replacement_chars = 0
        for (text,) in connection.execute('SELECT text_display FROM passages'):
            bad_controls += sum(ord(ch) < 32 and ch not in '\n\r\t' for ch in text)
            replacement_chars += text.count('\ufffd')
        connection.close()

        if integrity != 'ok':
            fail(f'intégrité SQLite: {integrity}')
        expected_stats = manifest['stats']
        for key in ('sermons', 'editions', 'passages'):
            if counts[key] != expected_stats[key]:
                fail(f"compte {key}: {counts[key]} != {expected_stats[key]}")
        if counts['fts_rows'] != counts['passages']:
            fail('le nombre de lignes FTS ne correspond pas aux passages')
        if primary_passages != expected_stats['primary_passages']:
            fail('compte primary_passages incohérent')
        if bad_controls:
            fail(f'{bad_controls} caractères de contrôle interdits dans text_display')
        if replacement_chars:
            fail(f'{replacement_chars} caractères U+FFFD dans text_display')
        if lexical_smoke['foi'] == 0 or lexical_smoke['bapteme'] == 0:
            fail('smoke test lexical: termes attendus absents')
        if lexical_smoke['publisher_unique_token'] != 0:
            fail('bruit éditorial encore indexé: shekinahgospelmissions')

    semantic_manifest = json.loads((corpus / 'semantic_manifest.json').read_text(encoding='utf-8'))
    for filename, info in semantic_manifest['files'].items():
        path = corpus / filename
        if not path.exists():
            fail(f'asset sémantique absent: {filename}')
        if path.stat().st_size != info['bytes']:
            fail(f'taille asset sémantique incorrecte: {filename}')
        if sha256(path) != info['sha256']:
            fail(f'SHA-256 asset sémantique incorrect: {filename}')

    result = {
        'status': 'OK',
        'corpus_version': manifest['corpus_version'],
        'database_bytes': manifest['database_bytes'],
        'database_sha256': manifest['database_sha256'],
        'parts': len(parts),
        'sqlite_integrity': 'ok',
        'counts': counts,
        'primary_passages': primary_passages,
        'semantic_documents': semantic_manifest['documents'],
        'semantic_dimensions': semantic_manifest['dimensions'],
        'search_filter': manifest.get('search_filter', {}),
        'lexical_smoke': lexical_smoke,
        'bad_control_characters': 0,
        'replacement_characters': 0,
    }
    print(json.dumps(result, ensure_ascii=False, indent=2))


if __name__ == '__main__':
    main()
