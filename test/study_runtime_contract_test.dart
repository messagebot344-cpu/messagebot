import 'dart:convert';
import 'dart:io';

import 'package:crypto/crypto.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('runtime wires Study Pack installer and local repositories', () {
    final source = File('lib/src/app.dart').readAsStringSync();
    expect(source, contains('StudyPackInstaller'));
    expect(source, contains('StudyPackRepository.open'));
    expect(source, contains('StudyProgressRepository'));
    expect(source, contains('expectedCanonicalSha256'));
  });

  test('every sermon reader exposes the certifying study entry point', () {
    final source =
        File('lib/src/screens/reader_screen.dart').readAsStringSync();
    expect(
      source,
      contains('Étudier & obtenir la certification'),
    );
    expect(source, contains('StudyOverviewScreen'));
  });

  test('certifying reader tracks viewport activity instead of page opening', () {
    final source =
        File('lib/src/screens/study_reading_screen.dart').readAsStringSync();
    expect(source, contains('ItemPositionsListener'));
    expect(source, contains('visibleMilliseconds: 1000'));
    expect(source, contains('visibleRatio: ratio'));
    expect(source, contains('ratio < 0.60'));
    expect(source, contains('AppLifecycleState.resumed'));
  });

  test('packaged Study Pack foundation is hashed and bound to corpus V4', () {
    final manifestFile = File('assets/study/manifest.json');
    expect(manifestFile.existsSync(), isTrue);
    final manifest =
        jsonDecode(manifestFile.readAsStringSync()) as Map<String, dynamic>;
    final corpusManifest =
        jsonDecode(File('assets/corpus/manifest.json').readAsStringSync())
            as Map<String, dynamic>;

    expect(
      manifest['corpus_version'],
      corpusManifest['corpus_version'],
    );
    expect(
      manifest['corpus_canonical_sha256'],
      corpusManifest['canonical_text_sha256'],
    );

    final parts = (manifest['parts'] as List).cast<Map<String, dynamic>>();
    expect(parts, isNotEmpty);
    var totalBytes = 0;
    final combined = BytesBuilder(copy: false);
    for (final part in parts) {
      final file = File('assets/study/db_parts/${part['name']}');
      expect(file.existsSync(), isTrue);
      final bytes = file.readAsBytesSync();
      expect(bytes.length, part['bytes']);
      expect(sha256.convert(bytes).toString(), part['sha256']);
      totalBytes += bytes.length;
      combined.add(bytes);
    }
    expect(totalBytes, manifest['database_bytes']);
    expect(
      sha256.convert(combined.takeBytes()).toString(),
      manifest['database_sha256'],
    );
  });
}
