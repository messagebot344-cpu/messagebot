import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:le_grenier_du_message/src/personal/personal_library.dart';
import 'package:le_grenier_du_message/src/personal/user_database.dart';

void main() {

  test('user.db crée automatiquement son dossier parent avant ouverture', () {
    final root = Directory.systemTemp.createTempSync('grenier-user-db-parent-');
    final nested = Directory('${root.path}/deep/app/support');
    final path = '${nested.path}/user.db';

    expect(nested.existsSync(), isFalse);

    final db = UserDatabase.openPath(path);
    expect(nested.existsSync(), isTrue);
    expect(File(path).existsSync(), isTrue);
    expect(db.meta('schema_version'), '6');

    db.close();
    root.deleteSync(recursive: true);
  });

  test('user.db conserve collections, signets et notes séparément du corpus', () {
    final dir = Directory.systemTemp.createTempSync('grenier-user-db-');
    final path = '${dir.path}/user.db';
    final db = UserDatabase.openPath(path);
    final library = PersonalLibrary(db);
    final collection = library.createCollection('Foi');
    library.addPassageBookmark(42, label: 'promesse');
    library.addToCollection(collection, 42);
    library.addNote(42, 'Note personnelle de test');
    db.close();

    final reopened = UserDatabase.openPath(path);
    final again = PersonalLibrary(reopened);
    expect(again.passageBookmarks, contains(42));
    expect(again.collections().single.name, 'Foi');
    expect(again.collectionPassageIds(collection), [42]);
    expect(again.notesForPassage(42).single.note, 'Note personnelle de test');
    reopened.close();
    dir.deleteSync(recursive: true);
  });

  test('user.db conserve les surlignages exacts après réouverture', () {
    final dir = Directory.systemTemp.createTempSync('grenier-user-highlight-');
    final path = '${dir.path}/user.db';
    final db = UserDatabase.openPath(path);
    final library = PersonalLibrary(db);
    final id = library.addHighlight(
      passageId: 42,
      startOffset: 3,
      endOffset: 12,
      highlightedText: 'foi ferme',
    );
    expect(id, greaterThan(0));
    db.close();

    final reopened = UserDatabase.openPath(path);
    final again = PersonalLibrary(reopened);
    final highlight = again.highlightsForPassage(42).single;
    expect(highlight.startOffset, 3);
    expect(highlight.endOffset, 12);
    expect(highlight.highlightedText, 'foi ferme');

    again.removeHighlight(highlight.id);
    expect(again.highlightsForPassage(42), isEmpty);
    reopened.close();
    dir.deleteSync(recursive: true);
  });

  test('migration V4 vers V6 conserve les données personnelles existantes', () {
    final dir = Directory.systemTemp.createTempSync('grenier-user-v4-v5-');
    final path = '${dir.path}/user.db';
    final db = UserDatabase.openPath(path);
    final library = PersonalLibrary(db);
    library.addNote(99, 'Note existante');
    library.addPassageBookmark(99);
    db.db.execute('DROP TABLE IF EXISTS passage_highlights');
    db.setMeta('schema_version', '4');
    db.close();

    final reopened = UserDatabase.openPath(path);
    final again = PersonalLibrary(reopened);
    expect(reopened.meta('schema_version'), '6');
    expect(again.notesForPassage(99).single.note, 'Note existante');
    expect(again.passageBookmarks, contains(99));

    again.addHighlight(
      passageId: 99,
      startOffset: 0,
      endOffset: 4,
      highlightedText: 'Test',
    );
    expect(again.highlightsForPassage(99), hasLength(1));
    reopened.close();
    dir.deleteSync(recursive: true);
  });

  test('migration V5 vers V6 conserve surlignages, notes et signets', () {
    final dir = Directory.systemTemp.createTempSync('grenier-user-v5-v6-');
    final path = '${dir.path}/user.db';
    final db = UserDatabase.openPath(path);
    final library = PersonalLibrary(db);
    library.addNote(77, 'Note à conserver');
    library.addPassageBookmark(77);
    library.addHighlight(
      passageId: 77,
      startOffset: 2,
      endOffset: 8,
      highlightedText: 'source',
    );

    for (final table in [
      'study_progress',
      'study_paragraph_progress',
      'study_section_progress',
      'study_question_attempts',
      'study_exam_attempts',
      'study_exam_items',
      'study_certifications',
    ]) {
      db.db.execute('DROP TABLE IF EXISTS $table');
    }
    db.setMeta('schema_version', '5');
    db.close();

    final reopened = UserDatabase.openPath(path);
    final again = PersonalLibrary(reopened);
    expect(reopened.meta('schema_version'), '6');
    expect(again.notesForPassage(77).single.note, 'Note à conserver');
    expect(again.passageBookmarks, contains(77));
    expect(again.highlightsForPassage(77).single.highlightedText, 'source');
    expect(
      reopened.db.select(
        "SELECT 1 FROM sqlite_master WHERE type='table' AND name='study_progress'",
      ),
      isNotEmpty,
    );

    reopened.close();
    dir.deleteSync(recursive: true);
  });

  test('le marqueur de migration existe dans user.db', () {
    final dir = Directory.systemTemp.createTempSync('grenier-user-db-migration-');
    final db = UserDatabase.openPath('${dir.path}/user.db');
    db.setMeta('legacy_v2_migrated', '1');
    expect(db.meta('legacy_v2_migrated'), '1');
    db.close();
    dir.deleteSync(recursive: true);
  });
}
