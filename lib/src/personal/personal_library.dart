import '../services/preferences_service.dart';
import 'user_database.dart';

class PersonalCollection {
  const PersonalCollection({required this.id, required this.name, required this.itemCount});
  final int id;
  final String name;
  final int itemCount;
}

class UserNote {
  const UserNote({required this.id, required this.passageId, required this.note});
  final int id;
  final int passageId;
  final String note;
}

class PersonalLibrary {
  PersonalLibrary(this.database);

  final UserDatabase database;

  int get _now => DateTime.now().millisecondsSinceEpoch;

  Future<void> migrateFromLegacy(PreferencesService preferences) async {
    if (database.meta('legacy_v2_migrated') == '1') return;
    database.db.execute('BEGIN IMMEDIATE');
    try {
      for (final code in preferences.favoriteCodes) {
        database.db.execute(
          'INSERT OR IGNORE INTO favorites(source_key,created_at) VALUES(?,?)',
          [code, _now],
        );
      }
      for (final query in preferences.history.reversed) {
        addSearchHistory(query);
      }
      for (final entry in preferences.readingPositionsSnapshot.entries) {
        setReadingPosition(entry.key, entry.value);
      }
      database.setMeta('legacy_v2_migrated', '1');
      database.db.execute('COMMIT');
    } catch (_) {
      database.db.execute('ROLLBACK');
      rethrow;
    }
  }

  Set<String> get favoriteCodes => database.db
      .select('SELECT source_key FROM favorites ORDER BY source_key')
      .map((row) => row['source_key'] as String)
      .toSet();

  bool isFavorite(String sourceKey) => database.db.select(
        'SELECT 1 FROM favorites WHERE source_key=? LIMIT 1',
        [sourceKey],
      ).isNotEmpty;

  void toggleFavorite(String sourceKey) {
    if (isFavorite(sourceKey)) {
      database.db.execute('DELETE FROM favorites WHERE source_key=?', [sourceKey]);
    } else {
      database.db.execute(
        'INSERT INTO favorites(source_key,created_at) VALUES(?,?)',
        [sourceKey, _now],
      );
    }
  }

  void addPassageBookmark(int passageId, {String? label}) {
    database.db.execute(
      'INSERT INTO passage_bookmarks(passage_id,label,created_at) VALUES(?,?,?) '
      'ON CONFLICT(passage_id) DO UPDATE SET label=excluded.label',
      [passageId, label, _now],
    );
  }

  void removePassageBookmark(int passageId) {
    database.db.execute('DELETE FROM passage_bookmarks WHERE passage_id=?', [passageId]);
  }

  Set<int> get passageBookmarks => database.db
      .select('SELECT passage_id FROM passage_bookmarks ORDER BY created_at DESC')
      .map((row) => row['passage_id'] as int)
      .toSet();

  int createCollection(String name) {
    final clean = name.trim();
    if (clean.isEmpty) throw ArgumentError.value(name, 'name', 'Le nom ne peut pas être vide.');
    final now = _now;
    database.db.execute(
      'INSERT INTO collections(name,created_at,updated_at) VALUES(?,?,?)',
      [clean, now, now],
    );
    return database.db.lastInsertRowId;
  }

  List<PersonalCollection> collections() => database.db.select('''
      SELECT c.id,c.name,COUNT(ci.id) AS item_count
      FROM collections c LEFT JOIN collection_items ci ON ci.collection_id=c.id
      GROUP BY c.id,c.name ORDER BY c.updated_at DESC,c.name
    ''').map((row) => PersonalCollection(
          id: row['id'] as int,
          name: row['name'] as String,
          itemCount: row['item_count'] as int,
        )).toList(growable: false);

  void addToCollection(int collectionId, int passageId) {
    final next = database.db.select(
      'SELECT COALESCE(MAX(position),-1)+1 AS p FROM collection_items WHERE collection_id=?',
      [collectionId],
    ).first['p'] as int;
    database.db.execute(
      'INSERT OR IGNORE INTO collection_items(collection_id,passage_id,position,created_at) VALUES(?,?,?,?)',
      [collectionId, passageId, next, _now],
    );
    database.db.execute('UPDATE collections SET updated_at=? WHERE id=?', [_now, collectionId]);
  }

  List<int> collectionPassageIds(int collectionId) => database.db
      .select('SELECT passage_id FROM collection_items WHERE collection_id=? ORDER BY position,id', [collectionId])
      .map((row) => row['passage_id'] as int)
      .toList(growable: false);

  int addNote(int passageId, String note) {
    final clean = note.trim();
    if (clean.isEmpty) throw ArgumentError.value(note, 'note', 'La note ne peut pas être vide.');
    final now = _now;
    database.db.execute(
      'INSERT INTO user_notes(passage_id,note,created_at,updated_at) VALUES(?,?,?,?)',
      [passageId, clean, now, now],
    );
    return database.db.lastInsertRowId;
  }

  List<UserNote> notesForPassage(int passageId) => database.db
      .select('SELECT id,passage_id,note FROM user_notes WHERE passage_id=? ORDER BY created_at', [passageId])
      .map((row) => UserNote(
            id: row['id'] as int,
            passageId: row['passage_id'] as int,
            note: row['note'] as String,
          ))
      .toList(growable: false);

  List<UserNote> searchNotes(String query, {int limit = 200}) {
    final clean = query.trim();
    final rows = clean.isEmpty
        ? database.db.select('SELECT id,passage_id,note FROM user_notes ORDER BY updated_at DESC LIMIT ?', [limit])
        : database.db.select(
            'SELECT n.id,n.passage_id,n.note FROM user_notes_fts f '
            'JOIN user_notes n ON n.id=f.rowid WHERE user_notes_fts MATCH ? '
            'ORDER BY bm25(user_notes_fts),n.updated_at DESC LIMIT ?',
            [_noteFtsQuery(clean), limit],
          );
    return rows.map((row) => UserNote(
      id: row['id'] as int,
      passageId: row['passage_id'] as int,
      note: row['note'] as String,
    )).toList(growable: false);
  }

  String _noteFtsQuery(String input) => input
      .split(RegExp(r'\s+'))
      .where((e) => e.trim().isNotEmpty)
      .take(12)
      .map((e) => '"${e.replaceAll('"', '""')}"*')
      .join(' AND ');

  void setReadingPosition(String editionId, int ordinal) {
    database.db.execute(
      'INSERT INTO reading_positions(edition_id,ordinal,updated_at) VALUES(?,?,?) '
      'ON CONFLICT(edition_id) DO UPDATE SET ordinal=excluded.ordinal,updated_at=excluded.updated_at',
      [editionId, ordinal, _now],
    );
  }

  int readingPosition(String editionId) {
    final rows = database.db.select('SELECT ordinal FROM reading_positions WHERE edition_id=? LIMIT 1', [editionId]);
    return rows.isEmpty ? 0 : rows.first['ordinal'] as int;
  }

  void addSearchHistory(String query) {
    final clean = query.trim();
    if (clean.isEmpty) return;
    database.db.execute(
      'INSERT INTO search_history(query,searched_at) VALUES(?,?) '
      'ON CONFLICT(query) DO UPDATE SET searched_at=excluded.searched_at',
      [clean, _now],
    );
    database.db.execute('''
      DELETE FROM search_history WHERE id IN (
        SELECT id FROM search_history ORDER BY searched_at DESC LIMIT -1 OFFSET 50
      )
    ''');
  }

  List<String> get searchHistory => database.db
      .select('SELECT query FROM search_history ORDER BY searched_at DESC LIMIT 50')
      .map((row) => row['query'] as String)
      .toList(growable: false);

  void clearSearchHistory() => database.db.execute('DELETE FROM search_history');
}
