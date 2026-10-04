import 'dart:convert';
import 'dart:io';

import 'package:crypto/crypto.dart';
import 'package:flutter/services.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:sqlite3/sqlite3.dart';

class StudyPackInstallResult {
  const StudyPackInstallResult({
    required this.databasePath,
    required this.manifest,
  });

  final String databasePath;
  final Map<String, dynamic> manifest;
}

class StudyPackInstaller {
  static const manifestAsset = 'assets/study/manifest.json';

  Future<StudyPackInstallResult> ensureInstalled({
    required String expectedCorpusVersion,
    required String expectedCanonicalSha256,
    void Function(double progress, String message)? onProgress,
  }) async {
    final manifest = jsonDecode(
      await rootBundle.loadString(manifestAsset),
    ) as Map<String, dynamic>;
    final schemaVersion = manifest['schema_version'] as int;
    final packsetVersion = manifest['packset_version'] as String;
    final expectedBytes = manifest['database_bytes'] as int;
    final expectedSha = manifest['database_sha256'] as String;
    final manifestCorpusVersion = manifest['corpus_version'] as String;
    final manifestCanonicalSha =
        manifest['corpus_canonical_sha256'] as String;
    if (manifestCorpusVersion != expectedCorpusVersion) {
      throw StateError(
        'Le paquet d’étude exige un autre corpus: '
        '$manifestCorpusVersion != $expectedCorpusVersion.',
      );
    }
    if (manifestCanonicalSha != expectedCanonicalSha256) {
      throw StateError(
        'Le paquet d’étude ne correspond pas au texte canonique installé.',
      );
    }
    final parts = (manifest['parts'] as List).cast<Map<String, dynamic>>();

    final support = await getApplicationSupportDirectory();
    final dir = Directory(
      p.join(support.path, 'le_grenier_du_message'),
    );
    await dir.create(recursive: true);
    final database = File(p.join(dir.path, 'study_packs.db'));
    final temp = File(p.join(dir.path, 'study_packs.db.tmp'));
    final backup = File(p.join(dir.path, 'study_packs.db.bak'));
    final marker = File(p.join(dir.path, 'study_packs.install.json'));

    if (await _isCurrent(
      database: database,
      marker: marker,
      schemaVersion: schemaVersion,
      packsetVersion: packsetVersion,
      expectedBytes: expectedBytes,
      expectedSha: expectedSha,
    )) {
      onProgress?.call(1, 'Parcours d’étude prêts');
      return StudyPackInstallResult(
        databasePath: database.path,
        manifest: manifest,
      );
    }

    if (await temp.exists()) await temp.delete();
    final raf = await temp.open(mode: FileMode.write);
    try {
      for (var index = 0; index < parts.length; index++) {
        final part = parts[index];
        final name = part['name'] as String;
        final data = await rootBundle.load(
          'assets/study/db_parts/$name',
        );
        final bytes = data.buffer.asUint8List(
          data.offsetInBytes,
          data.lengthInBytes,
        );
        if (bytes.length != part['bytes']) {
          throw StateError('Taille invalide pour $name.');
        }
        if (sha256.convert(bytes).toString() != part['sha256']) {
          throw StateError('Empreinte invalide pour $name.');
        }
        await raf.writeFrom(bytes);
        onProgress?.call(
          (index + 1) / parts.length * 0.80,
          'Installation des parcours ${index + 1}/${parts.length}',
        );
      }
      await raf.flush();
    } finally {
      await raf.close();
    }

    try {
      if (await temp.length() != expectedBytes) {
        throw StateError(
          'Taille globale du paquet d’étude invalide.',
        );
      }
      onProgress?.call(0.86, 'Vérification des parcours…');
      if (await _sha256Of(temp) != expectedSha) {
        throw StateError(
          'Empreinte globale du paquet d’étude invalide.',
        );
      }
      _validateDatabase(
        temp,
        schemaVersion,
        expectedCorpusVersion: expectedCorpusVersion,
        expectedCanonicalSha256: expectedCanonicalSha256,
      );

      if (await backup.exists()) await backup.delete();
      var oldMoved = false;
      try {
        if (await database.exists()) {
          await database.rename(backup.path);
          oldMoved = true;
        }
        await temp.rename(database.path);
        await _writeMarker(
          marker: marker,
          database: database,
          schemaVersion: schemaVersion,
          packsetVersion: packsetVersion,
          expectedBytes: expectedBytes,
          expectedSha: expectedSha,
        );
        if (await backup.exists()) await backup.delete();
      } catch (_) {
        if (await database.exists()) await database.delete();
        if (oldMoved && await backup.exists()) {
          await backup.rename(database.path);
        }
        rethrow;
      }
    } catch (_) {
      if (await temp.exists()) await temp.delete();
      rethrow;
    }

    onProgress?.call(1, 'Parcours d’étude prêts');
    return StudyPackInstallResult(
      databasePath: database.path,
      manifest: manifest,
    );
  }

  Future<bool> _isCurrent({
    required File database,
    required File marker,
    required int schemaVersion,
    required String packsetVersion,
    required int expectedBytes,
    required String expectedSha,
  }) async {
    if (!await database.exists() || !await marker.exists()) {
      return false;
    }
    if (await database.length() != expectedBytes) return false;

    try {
      final saved =
          jsonDecode(await marker.readAsString()) as Map<String, dynamic>;
      final modified =
          (await database.stat()).modified.millisecondsSinceEpoch;
      return saved['schema_version'] == schemaVersion &&
          saved['packset_version'] == packsetVersion &&
          saved['database_bytes'] == expectedBytes &&
          saved['database_sha256'] == expectedSha &&
          saved['modified_ms'] == modified;
    } catch (_) {
      return false;
    }
  }

  void _validateDatabase(
    File file,
    int expectedSchemaVersion, {
    required String expectedCorpusVersion,
    required String expectedCanonicalSha256,
  }) {
    final db = sqlite3.open(file.path, mode: OpenMode.readOnly);
    try {
      final quick = db.select('PRAGMA quick_check');
      if (quick.isEmpty ||
          quick.first.values.first.toString().toLowerCase() != 'ok') {
        throw StateError('Study Pack SQLite invalide.');
      }
      final rows = db.select(
        "SELECT value FROM study_pack_meta "
        "WHERE key='schema_version' LIMIT 1",
      );
      if (rows.isEmpty ||
          int.tryParse(rows.first['value'] as String) !=
              expectedSchemaVersion) {
        throw StateError(
          'Version du schéma Study Pack incompatible.',
        );
      }
      final corpusRows = db.select(
        "SELECT key,value FROM study_pack_meta "
        "WHERE key IN ('corpus_version','corpus_canonical_sha256')",
      );
      final values = <String, String>{
        for (final row in corpusRows)
          row['key'] as String: row['value'] as String,
      };
      if (values['corpus_version'] != expectedCorpusVersion) {
        throw StateError(
          'Version du corpus Study Pack incompatible.',
        );
      }
      if (values['corpus_canonical_sha256'] !=
          expectedCanonicalSha256) {
        throw StateError(
          'Empreinte canonique Study Pack incompatible.',
        );
      }
    } finally {
      db.dispose();
    }
  }

  Future<void> _writeMarker({
    required File marker,
    required File database,
    required int schemaVersion,
    required String packsetVersion,
    required int expectedBytes,
    required String expectedSha,
  }) async {
    final modified =
        (await database.stat()).modified.millisecondsSinceEpoch;
    final temp = File('${marker.path}.tmp');
    await temp.writeAsString(
      jsonEncode({
        'schema_version': schemaVersion,
        'packset_version': packsetVersion,
        'database_bytes': expectedBytes,
        'database_sha256': expectedSha,
        'modified_ms': modified,
      }),
      flush: true,
    );
    if (await marker.exists()) await marker.delete();
    await temp.rename(marker.path);
  }

  Future<String> _sha256Of(File file) async =>
      (await sha256.bind(file.openRead()).first).toString();
}
