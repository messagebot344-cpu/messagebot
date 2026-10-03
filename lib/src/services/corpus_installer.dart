import 'dart:convert';
import 'dart:io';

import 'package:crypto/crypto.dart';
import 'package:flutter/services.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:sqlite3/sqlite3.dart';

class CorpusInstallResult {
  const CorpusInstallResult({required this.databasePath, required this.manifest});

  final String databasePath;
  final Map<String, dynamic> manifest;
}

class CorpusInstaller {
  static const _manifestAsset = 'assets/corpus/manifest.json';

  Future<CorpusInstallResult> ensureInstalled({
    void Function(double progress, String message)? onProgress,
  }) async {
    final manifest = jsonDecode(await rootBundle.loadString(_manifestAsset))
        as Map<String, dynamic>;
    final version = manifest['corpus_version'] as String;
    final schemaVersion = manifest['schema_version'] as int;
    final expectedBytes = manifest['database_bytes'] as int;
    final expectedSha = manifest['database_sha256'] as String;
    final parts = (manifest['parts'] as List).cast<Map<String, dynamic>>();

    final support = await getApplicationSupportDirectory();
    final dir = Directory(p.join(support.path, 'le_grenier_du_message'));
    await dir.create(recursive: true);
    final dbFile = File(p.join(dir.path, 'corpus.db'));
    final temp = File(p.join(dir.path, 'corpus.db.tmp'));
    final backup = File(p.join(dir.path, 'corpus.db.bak'));
    final marker = File(p.join(dir.path, 'corpus.install.json'));

    if (await _isCurrentInstallationValid(
      dbFile: dbFile,
      marker: marker,
      version: version,
      schemaVersion: schemaVersion,
      expectedBytes: expectedBytes,
      expectedSha: expectedSha,
      onProgress: onProgress,
    )) {
      onProgress?.call(1, 'Corpus prêt');
      return CorpusInstallResult(databasePath: dbFile.path, manifest: manifest);
    }

    onProgress?.call(0, 'Installation locale du corpus…');
    if (await temp.exists()) await temp.delete();
    final raf = await temp.open(mode: FileMode.write);
    try {
      for (var i = 0; i < parts.length; i++) {
        final name = parts[i]['name'] as String;
        final expectedPartBytes = parts[i]['bytes'] as int;
        final expectedPartSha = parts[i]['sha256'] as String;
        final data = await rootBundle.load('assets/corpus/db_parts/$name');
        final bytes = data.buffer.asUint8List(data.offsetInBytes, data.lengthInBytes);
        if (bytes.length != expectedPartBytes) {
          throw StateError('Taille invalide pour le morceau $name.');
        }
        if (sha256.convert(bytes).toString() != expectedPartSha) {
          throw StateError('Empreinte invalide pour le morceau $name.');
        }
        await raf.writeFrom(bytes);
        onProgress?.call(
          (i + 1) / parts.length * 0.82,
          'Installation du corpus ${i + 1}/${parts.length}',
        );
      }
      await raf.flush();
    } finally {
      await raf.close();
    }

    try {
      final actualBytes = await temp.length();
      if (actualBytes != expectedBytes) {
        throw StateError('Taille du corpus incorrecte: $actualBytes au lieu de $expectedBytes.');
      }

      // Streaming verification: the file is never loaded as one 320+ MB buffer.
      onProgress?.call(0.86, 'Vérification SHA-256 du corpus…');
      final actualSha = await _sha256Of(temp);
      if (actualSha != expectedSha) {
        throw StateError('Empreinte globale du corpus incorrecte.');
      }

      onProgress?.call(0.92, 'Vérification SQLite du corpus…');
      _validateStagedDatabase(temp, schemaVersion);

      // Last-known-good swap. The existing corpus remains untouched until the
      // staged copy has passed size, SHA-256, schema and PRAGMA quick_check.
      if (await backup.exists()) await backup.delete();
      var oldMoved = false;
      try {
        if (await dbFile.exists()) {
          await dbFile.rename(backup.path);
          oldMoved = true;
        }
        await temp.rename(dbFile.path);
        await _writeMarker(
          marker: marker,
          dbFile: dbFile,
          version: version,
          schemaVersion: schemaVersion,
          expectedBytes: expectedBytes,
          expectedSha: expectedSha,
        );
        if (await backup.exists()) await backup.delete();
      } catch (_) {
        if (await dbFile.exists()) await dbFile.delete();
        if (oldMoved && await backup.exists()) {
          await backup.rename(dbFile.path);
        }
        rethrow;
      }
    } catch (_) {
      if (await temp.exists()) await temp.delete();
      rethrow;
    }

    onProgress?.call(1, 'Corpus prêt');
    return CorpusInstallResult(databasePath: dbFile.path, manifest: manifest);
  }

  Future<bool> _isCurrentInstallationValid({
    required File dbFile,
    required File marker,
    required String version,
    required int schemaVersion,
    required int expectedBytes,
    required String expectedSha,
    required void Function(double progress, String message)? onProgress,
  }) async {
    if (!await dbFile.exists() || !await marker.exists()) return false;
    if (await dbFile.length() != expectedBytes) return false;

    Map<String, dynamic>? saved;
    try {
      saved = jsonDecode(await marker.readAsString()) as Map<String, dynamic>;
    } catch (_) {
      // Invalid/legacy marker: perform a full streaming verification below.
    }

    final stat = await dbFile.stat();
    final modifiedMs = stat.modified.millisecondsSinceEpoch;
    final sameMarker = saved != null &&
        saved['corpus_version'] == version &&
        saved['schema_version'] == schemaVersion &&
        saved['database_bytes'] == expectedBytes &&
        saved['database_sha256'] == expectedSha &&
        saved['modified_ms'] == modifiedMs;
    if (sameMarker) return true;

    onProgress?.call(0.2, 'Vérification du corpus local…');
    if (await _sha256Of(dbFile) != expectedSha) return false;
    try {
      _validateStagedDatabase(dbFile, schemaVersion);
    } catch (_) {
      return false;
    }
    await _writeMarker(
      marker: marker,
      dbFile: dbFile,
      version: version,
      schemaVersion: schemaVersion,
      expectedBytes: expectedBytes,
      expectedSha: expectedSha,
    );
    return true;
  }

  void _validateStagedDatabase(File file, int expectedSchemaVersion) {
    final database = sqlite3.open(file.path, mode: OpenMode.readOnly);
    try {
      final quick = database.select('PRAGMA quick_check');
      if (quick.isEmpty || quick.first.values.first.toString().toLowerCase() != 'ok') {
        throw StateError('PRAGMA quick_check a échoué pour le corpus préparé.');
      }
      final rows = database.select(
        "SELECT value FROM corpus_meta WHERE key='schema_version' LIMIT 1",
      );
      if (rows.isEmpty || int.tryParse(rows.first['value'] as String) != expectedSchemaVersion) {
        throw StateError('Version de schéma SQLite incompatible.');
      }
    } finally {
      database.dispose();
    }
  }

  Future<void> _writeMarker({
    required File marker,
    required File dbFile,
    required String version,
    required int schemaVersion,
    required int expectedBytes,
    required String expectedSha,
  }) async {
    final modifiedMs = (await dbFile.stat()).modified.millisecondsSinceEpoch;
    final tempMarker = File('${marker.path}.tmp');
    await tempMarker.writeAsString(
      jsonEncode({
        'corpus_version': version,
        'schema_version': schemaVersion,
        'database_bytes': expectedBytes,
        'database_sha256': expectedSha,
        'modified_ms': modifiedMs,
      }),
      flush: true,
    );
    if (await marker.exists()) await marker.delete();
    await tempMarker.rename(marker.path);
  }

  Future<String> _sha256Of(File file) async {
    final digest = await sha256.bind(file.openRead()).first;
    return digest.toString();
  }
}
