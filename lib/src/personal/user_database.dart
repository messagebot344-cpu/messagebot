import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:sqlite3/sqlite3.dart';

class UserDatabase {
  UserDatabase._(this.db, this.path);

  final Database db;
  final String path;

  static Future<UserDatabase> createInAppSupport() async {
    final support = await getApplicationSupportDirectory();
    return openPath(p.join(support.path, 'le_grenier_du_message', 'user.db'));
  }

  static UserDatabase openPath(String path) {
    final database = sqlite3.open(path);
    final result = UserDatabase._(database, path);
    result._ensureBaseSchema();
    result.ensureV4Schema();
    return result;
  }

  void _ensureBaseSchema() {
    db.execute('PRAGMA foreign_keys=ON');
    db.execute('CREATE TABLE IF NOT EXISTS user_meta(key TEXT PRIMARY KEY,value TEXT NOT NULL)');
    db.execute('CREATE TABLE IF NOT EXISTS favorites(source_key TEXT PRIMARY KEY,created_at INTEGER NOT NULL)');
    db.execute('CREATE TABLE IF NOT EXISTS passage_bookmarks(passage_id INTEGER PRIMARY KEY,label TEXT,created_at INTEGER NOT NULL)');
    db.execute('''
      CREATE TABLE IF NOT EXISTS collections(
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        name TEXT NOT NULL UNIQUE,
        created_at INTEGER NOT NULL,
        updated_at INTEGER NOT NULL
      )
    ''');
    db.execute('''
      CREATE TABLE IF NOT EXISTS collection_items(
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        collection_id INTEGER NOT NULL,
        passage_id INTEGER NOT NULL,
        position INTEGER NOT NULL DEFAULT 0,
        created_at INTEGER NOT NULL,
        UNIQUE(collection_id, passage_id),
        FOREIGN KEY(collection_id) REFERENCES collections(id) ON DELETE CASCADE
      )
    ''');
    db.execute('''
      CREATE TABLE IF NOT EXISTS user_notes(
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        passage_id INTEGER NOT NULL,
        note TEXT NOT NULL,
        created_at INTEGER NOT NULL,
        updated_at INTEGER NOT NULL
      )
    ''');
    db.execute('CREATE TABLE IF NOT EXISTS reading_positions(edition_id TEXT PRIMARY KEY,ordinal INTEGER NOT NULL,updated_at INTEGER NOT NULL)');
    db.execute('CREATE TABLE IF NOT EXISTS search_history(id INTEGER PRIMARY KEY AUTOINCREMENT,query TEXT NOT NULL UNIQUE,searched_at INTEGER NOT NULL)');
    db.execute('CREATE TABLE IF NOT EXISTS study_history(id INTEGER PRIMARY KEY AUTOINCREMENT,action_type TEXT NOT NULL,reference_id TEXT NOT NULL,visited_at INTEGER NOT NULL)');
    db.execute('CREATE TABLE IF NOT EXISTS comparison_history(id INTEGER PRIMARY KEY AUTOINCREMENT,passage_a INTEGER NOT NULL,passage_b INTEGER NOT NULL,compared_at INTEGER NOT NULL)');
    db.execute("INSERT OR IGNORE INTO user_meta(key,value) VALUES('schema_version','1')");
  }

  void ensureV4Schema() {
    final current = int.tryParse(meta('schema_version') ?? '1') ?? 1;
    if (current >= 4 && _hasTable('conversations') && _hasTable('user_notes_fts')) return;
    db.execute('BEGIN IMMEDIATE');
    try {
      db.execute('''
        CREATE TABLE IF NOT EXISTS conversations(
          id INTEGER PRIMARY KEY AUTOINCREMENT,
          title TEXT NOT NULL,
          created_at INTEGER NOT NULL,
          updated_at INTEGER NOT NULL,
          pinned INTEGER NOT NULL DEFAULT 0
        )
      ''');
      db.execute('''
        CREATE TABLE IF NOT EXISTS conversation_turns(
          id INTEGER PRIMARY KEY AUTOINCREMENT,
          conversation_id INTEGER NOT NULL,
          query TEXT NOT NULL,
          subject_terms TEXT NOT NULL DEFAULT '',
          year_min INTEGER,
          year_max INTEGER,
          source_type TEXT,
          source_id TEXT,
          result_count INTEGER NOT NULL DEFAULT 0,
          created_at INTEGER NOT NULL,
          FOREIGN KEY(conversation_id) REFERENCES conversations(id) ON DELETE CASCADE
        )
      ''');
      db.execute('''
        CREATE TABLE IF NOT EXISTS conversation_hits(
          turn_id INTEGER NOT NULL,
          passage_id INTEGER NOT NULL,
          rank INTEGER NOT NULL,
          score REAL NOT NULL,
          expanded INTEGER NOT NULL DEFAULT 0,
          PRIMARY KEY(turn_id, passage_id),
          FOREIGN KEY(turn_id) REFERENCES conversation_turns(id) ON DELETE CASCADE
        )
      ''');
      db.execute('''
        CREATE TABLE IF NOT EXISTS conversation_ui_state(
          conversation_id INTEGER PRIMARY KEY,
          scroll_offset REAL NOT NULL DEFAULT 0,
          updated_at INTEGER NOT NULL,
          FOREIGN KEY(conversation_id) REFERENCES conversations(id) ON DELETE CASCADE
        )
      ''');
      db.execute('CREATE INDEX IF NOT EXISTS idx_conversation_turns_conversation ON conversation_turns(conversation_id,id)');
      db.execute('CREATE INDEX IF NOT EXISTS idx_conversation_hits_turn_rank ON conversation_hits(turn_id,rank)');
      db.execute("CREATE VIRTUAL TABLE IF NOT EXISTS conversation_search_fts USING fts5(title,query,tokenize='unicode61 remove_diacritics 2')");
      db.execute("CREATE VIRTUAL TABLE IF NOT EXISTS user_notes_fts USING fts5(note,content='user_notes',content_rowid='id',tokenize='unicode61 remove_diacritics 2')");
      db.execute('''
        CREATE TRIGGER IF NOT EXISTS user_notes_ai AFTER INSERT ON user_notes BEGIN
          INSERT INTO user_notes_fts(rowid,note) VALUES(new.id,new.note);
        END
      ''');
      db.execute('''
        CREATE TRIGGER IF NOT EXISTS user_notes_ad AFTER DELETE ON user_notes BEGIN
          INSERT INTO user_notes_fts(user_notes_fts,rowid,note) VALUES('delete',old.id,old.note);
        END
      ''');
      db.execute('''
        CREATE TRIGGER IF NOT EXISTS user_notes_au AFTER UPDATE ON user_notes BEGIN
          INSERT INTO user_notes_fts(user_notes_fts,rowid,note) VALUES('delete',old.id,old.note);
          INSERT INTO user_notes_fts(rowid,note) VALUES(new.id,new.note);
        END
      ''');
      db.execute("INSERT INTO user_notes_fts(user_notes_fts) VALUES('rebuild')");
      setMeta('schema_version', '4');
      db.execute('COMMIT');
    } catch (_) {
      db.execute('ROLLBACK');
      rethrow;
    }
  }

  bool _hasTable(String name) => db.select(
        "SELECT 1 FROM sqlite_master WHERE type='table' AND name=? LIMIT 1",
        [name],
      ).isNotEmpty;

  String? meta(String key) {
    final rows = db.select('SELECT value FROM user_meta WHERE key=? LIMIT 1', [key]);
    return rows.isEmpty ? null : rows.first['value'] as String;
  }

  void setMeta(String key, String value) {
    db.execute(
      'INSERT INTO user_meta(key,value) VALUES(?,?) ON CONFLICT(key) DO UPDATE SET value=excluded.value',
      [key, value],
    );
  }

  void close() => db.dispose();
}
