from __future__ import annotations

import json
import re
from pathlib import Path

import yaml

ROOT = Path(__file__).resolve().parents[1]


def main() -> None:
    issues: list[str] = []
    pubspec = yaml.safe_load((ROOT / 'pubspec.yaml').read_text(encoding='utf-8'))
    dependencies = set((pubspec.get('dependencies') or {}).keys())
    forbidden_network = {'http', 'dio', 'chopper', 'retrofit', 'web_socket_channel'}
    present_network = sorted(dependencies & forbidden_network)
    if present_network:
        issues.append(f'Dépendances réseau détectées: {present_network}')

    assets = pubspec.get('flutter', {}).get('assets', [])
    for asset in assets:
        path = ROOT / asset
        if not path.exists():
            issues.append(f'Asset/dossier déclaré absent: {asset}')

    dart_files = sorted((ROOT / 'lib').rglob('*.dart')) + sorted((ROOT / 'test').rglob('*.dart'))
    network_patterns = [
        re.compile(r"package:http/"),
        re.compile(r"package:dio/"),
        re.compile(r"dart:html"),
        re.compile(r"HttpClient\s*\("),
        re.compile(r"WebSocket\s*\."),
    ]
    network_hits: list[str] = []
    for file in dart_files:
        text = file.read_text(encoding='utf-8')
        for pattern in network_patterns:
            if pattern.search(text):
                network_hits.append(f'{file.relative_to(ROOT)}: {pattern.pattern}')
    if network_hits:
        issues.extend(f'Accès réseau potentiel: {hit}' for hit in network_hits)

    manifest = json.loads((ROOT / 'assets/corpus/manifest.json').read_text(encoding='utf-8'))
    expected_parts = {part['name'] for part in manifest['parts']}
    actual_parts = {path.name for path in (ROOT / 'assets/corpus/db_parts').glob('corpus.db.part*')}
    if expected_parts != actual_parts:
        issues.append(
            f'Liste de morceaux DB incohérente: manquants={sorted(expected_parts-actual_parts)}, '
            f'en trop={sorted(actual_parts-expected_parts)}'
        )

    flutter_pin = (ROOT / '.flutter-version').read_text(encoding='utf-8').strip() if (ROOT / '.flutter-version').exists() else None
    platforms_present = {
        'android': (ROOT / 'android').is_dir(),
        'windows': (ROOT / 'windows').is_dir(),
    }
    installer_text = (ROOT / 'lib/src/services/corpus_installer.dart').read_text(encoding='utf-8')
    for required in ['corpus.db.tmp', 'corpus.db.bak', '_validateStagedDatabase', 'PRAGMA quick_check', '_sha256Of(temp)']:
        if required not in installer_text:
            issues.append(f'Installateur V3 incomplet: {required}')
    if not (ROOT / 'assets/corpus/packs_manifest.json').exists():
        issues.append('Manifest de packs V3 absent: assets/corpus/packs_manifest.json')
    app_text = (ROOT / 'lib/src/app.dart').read_text(encoding='utf-8')
    if 'semanticAvailable' not in app_text or 'Mode lexical' not in app_text:
        issues.append('Mode lexical dégradé non explicite dans le bootstrap')

    test_files = sorted((ROOT / 'test').glob('*_test.dart'))

    report = {
        'status': 'OK' if not issues else 'ERROR',
        'dart_files': len(dart_files),
        'test_files': len(test_files),
        'flutter_reference_version': flutter_pin,
        'platform_directories_present': platforms_present,
        'dependencies': sorted(dependencies),
        'network_dependencies': present_network,
        'network_code_hits': network_hits,
        'declared_assets': assets,
        'database_parts_expected': len(expected_parts),
        'database_parts_found': len(actual_parts),
        'issues': issues,
        'note': 'Les dossiers natifs sont générés par Flutter 3.35.4; ce contrôle statique ne remplace pas flutter analyze / flutter test.',
    }
    print(json.dumps(report, ensure_ascii=False, indent=2))
    if issues:
        raise SystemExit(1)


if __name__ == '__main__':
    main()
