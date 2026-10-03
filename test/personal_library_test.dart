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
    expect(db.meta('schema_version'), '4');

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

  test('le marqueur de migration existe dans user.db', () {
    final dir = Directory.systemTemp.createTempSync('grenier-user-db-migration-');
    final db = UserDatabase.openPath('${dir.path}/user.db');
    db.setMeta('legacy_v2_migrated', '1');
    expect(db.meta('legacy_v2_migrated'), '1');
    db.close();
    dir.deleteSync(recursive: true);
  });
}
