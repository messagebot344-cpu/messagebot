from __future__ import annotations

import hashlib
import json
import re
import sqlite3
import tempfile
from pathlib import Path

import yaml

ROOT = Path(__file__).resolve().parents[1]
CORPUS = ROOT / 'assets' / 'corpus'
REPORT = ROOT / 'reports' / 'v3_release_validation.json'


def sha256(path: Path) -> str:
    digest = hashlib.sha256()
    with path.open('rb') as handle:
        for chunk in iter(lambda: handle.read(1024 * 1024), b''):
            digest.update(chunk)
    return digest.hexdigest()


def check(condition: bool, message: str, issues: list[str]) -> None:
    if not condition:
        issues.append(message)


def main() -> None:
    issues: list[str] = []
    manifest = json.loads((CORPUS / 'manifest.json').read_text(encoding='utf-8'))
    packs = json.loads((CORPUS / 'packs_manifest.json').read_text(encoding='utf-8'))
    semantic_manifest = json.loads((CORPUS / 'semantic_manifest.json').read_text(encoding='utf-8'))

    check(manifest.get('schema_version') == 3, 'schema_version doit être 3', issues)
    check(manifest.get('stats', {}).get('sermons') == 1211, '1211 prédications attendues', issues)
    check(manifest.get('stats', {}).get('book_sources', 0) >= 1, 'au moins un livre doit être intégré', issues)
    check(manifest.get('stats', {}).get('book_passages', 0) >= 50, 'le livre doit avoir des passages indexés', issues)
    check(manifest.get('stats', {}).get('sentences', 0) > 100_000, 'index de phrases V3 absent/incomplet', issues)
    check(packs.get('offline_only') is True, 'packs_manifest doit déclarer offline_only=true', issues)
    check(any(p.get('kind') == 'semantic' and not p.get('required', True) for p in packs.get('packs', [])),
          'pack sémantique optionnel avec mode dégradé attendu', issues)

    expected_parts = manifest['parts']
    with tempfile.TemporaryDirectory(prefix='grenier_v3_validate_') as tmp:
        assembled = Path(tmp) / 'corpus.db'
        with assembled.open('wb') as target:
            for part in expected_parts:
                path = CORPUS / 'db_parts' / part['name']
                check(path.exists(), f"morceau absent: {part['name']}", issues)
                if not path.exists():
                    continue
                check(path.stat().st_size == part['bytes'], f"taille invalide: {part['name']}", issues)
                check(sha256(path) == part['sha256'], f"SHA invalide: {part['name']}", issues)
                target.write(path.read_bytes())
        check(assembled.stat().st_size == manifest['database_bytes'], 'taille assemblée incorrecte', issues)
        check(sha256(assembled) == manifest['database_sha256'], 'SHA global corpus.db incorrect', issues)
        con = sqlite3.connect(assembled)
        integrity = con.execute('PRAGMA integrity_check').fetchone()[0]
        quick = con.execute('PRAGMA quick_check').fetchone()[0]
        meta = dict(con.execute('SELECT key,value FROM corpus_meta'))
        counts = {
            'sermons': con.execute('SELECT count(*) FROM sermons').fetchone()[0],
            'editions': con.execute('SELECT count(*) FROM editions').fetchone()[0],
            'passages': con.execute('SELECT count(*) FROM passages').fetchone()[0],
            'books': con.execute("SELECT count(*) FROM sources WHERE source_type='book'").fetchone()[0],
            'book_passages': con.execute("SELECT count(*) FROM passages WHERE source_type='book'").fetchone()[0],
            'sentences': con.execute('SELECT count(*) FROM sentences').fetchone()[0],
            'neighbors': con.execute('SELECT count(*) FROM passage_neighbors').fetchone()[0],
            'terms': con.execute('SELECT count(*) FROM term_stats').fetchone()[0],
            'fts': con.execute('SELECT count(*) FROM passages_fts').fetchone()[0],
        }
        con.close()
        check(integrity == 'ok' and quick == 'ok', f'SQLite integrity={integrity}, quick={quick}', issues)
        check(meta.get('schema_version') == '3', 'corpus_meta.schema_version doit être 3', issues)
        check(counts['sermons'] == 1211, 'compte SQLite sermons incohérent', issues)
        check(counts['books'] >= 1 and counts['book_passages'] >= 50, 'données livre V3 absentes', issues)
        check(counts['sentences'] > 100_000 and counts['neighbors'] > 100_000 and counts['terms'] > 1000,
              'index d’étude V3 incomplets', issues)
        check(counts['fts'] == counts['passages'], 'FTS doit couvrir tous les passages', issues)

    for filename, info in semantic_manifest['files'].items():
        path = CORPUS / filename
        check(path.exists(), f'asset sémantique absent: {filename}', issues)
        if path.exists():
            check(path.stat().st_size == info['bytes'], f'taille sémantique invalide: {filename}', issues)
            check(sha256(path) == info['sha256'], f'SHA sémantique invalide: {filename}', issues)

    pubspec = yaml.safe_load((ROOT / 'pubspec.yaml').read_text(encoding='utf-8'))
    dependencies = set((pubspec.get('dependencies') or {}).keys())
    network_dependencies = sorted(dependencies & {'http', 'dio', 'chopper', 'retrofit', 'web_socket_channel'})
    check(not network_dependencies, f'dépendances réseau: {network_dependencies}', issues)

    free_text_answer_hits: list[str] = []
    for folder in ['lib/src/search', 'lib/src/study', 'lib/src/services']:
        for path in (ROOT / folder).glob('*.dart'):
            text = path.read_text(encoding='utf-8')
            if re.search(r'\b(?:Future<\s*String\s*>\s+)?answer\s*\(', text):
                free_text_answer_hits.append(str(path.relative_to(ROOT)))
    check(not free_text_answer_hits, f'API de réponse libre détectée: {free_text_answer_hits}', issues)

    installer = (ROOT / 'lib/src/services/corpus_installer.dart').read_text(encoding='utf-8')
    repository = (ROOT / 'lib/src/services/corpus_repository.dart').read_text(encoding='utf-8')
    check('user.db' not in installer, 'CorpusInstaller ne doit jamais manipuler user.db', issues)
    check('OpenMode.readOnly' in repository, 'corpus.db doit être ouvert en lecture seule', issues)
    check('corpus.db.tmp' in installer and 'corpus.db.bak' in installer and 'PRAGMA quick_check' in installer,
          'installation atomique V3 incomplète', issues)

    missing_relative_imports: list[str] = []
    for dart_file in (ROOT / 'lib').rglob('*.dart'):
        text = dart_file.read_text(encoding='utf-8')
        for match in re.finditer(r"^import\s+['\"]([^'\"]+)['\"]", text, flags=re.MULTILINE):
            target = match.group(1)
            if target.startswith('.'):
                resolved = (dart_file.parent / target).resolve()
                if not resolved.exists():
                    missing_relative_imports.append(f'{dart_file.relative_to(ROOT)} -> {target}')
    check(not missing_relative_imports, f'imports Dart relatifs absents: {missing_relative_imports}', issues)

    required_tests = [
        'query_analyzer_test.dart', 'hybrid_ranker_test.dart', 'sentence_locator_test.dart',
        'personal_library_test.dart', 'study_engine_test.dart', 'v3_navigation_contract_test.dart',
        'corpus_installer_contract_test.dart',
    ]
    for name in required_tests:
        check((ROOT / 'test' / name).exists(), f'test V3 absent: {name}', issues)

    flutter_version = (ROOT / '.flutter-version').read_text(encoding='utf-8').strip()
    workflow = (ROOT / '.github/workflows/flutter_ci.yml').read_text(encoding='utf-8')
    check(flutter_version == '3.35.4', 'Flutter doit être figé à 3.35.4', issues)
    check("flutter-version: '3.35.4'" in workflow, 'CI non figée à Flutter 3.35.4', issues)
    check('flutter analyze' in workflow and 'flutter test' in workflow, 'CI doit analyser et tester', issues)
    check('flutter build apk --release' in workflow, 'CI doit produire un APK release', issues)
    check('flutter build windows --release' in workflow, 'CI doit produire Windows release', issues)

    readme = (ROOT / 'README.md').read_text(encoding='utf-8')
    status_doc = (ROOT / 'docs/IMPLEMENTATION_STATUS.md').read_text(encoding='utf-8')
    validation_doc = ROOT / 'docs/V3_VALIDATION.md'
    check('État du corpus V3' in readme, 'README doit documenter la V3', issues)
    check('V3' in status_doc and 'Exposé des Sept Âges' in status_doc, 'IMPLEMENTATION_STATUS doit documenter la V3 et le livre', issues)
    check(validation_doc.exists(), 'docs/V3_VALIDATION.md absent', issues)

    report = {
        'status': 'OK' if not issues else 'ERROR',
        'corpus_version': manifest['corpus_version'],
        'schema_version': manifest['schema_version'],
        'database_bytes': manifest['database_bytes'],
        'database_sha256': manifest['database_sha256'],
        'database_parts': len(expected_parts),
        'counts': counts,
        'semantic_documents': semantic_manifest.get('documents'),
        'semantic_dimensions': semantic_manifest.get('dimensions'),
        'flutter_reference_version': flutter_version,
        'network_dependencies': network_dependencies,
        'free_text_answer_api_hits': free_text_answer_hits,
        'missing_relative_imports': missing_relative_imports,
        'issues': issues,
        'flutter_sdk_executed_locally': False,
    }
    REPORT.parent.mkdir(parents=True, exist_ok=True)
    REPORT.write_text(json.dumps(report, ensure_ascii=False, indent=2) + '\n', encoding='utf-8')
    print(json.dumps(report, ensure_ascii=False, indent=2))
    if issues:
        raise SystemExit(1)


if __name__ == '__main__':
    main()
