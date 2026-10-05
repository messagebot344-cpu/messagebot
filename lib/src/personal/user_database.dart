import 'dart:io';

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
    final parent = File(path).parent;
    if (!parent.existsSync()) {
      parent.createSync(recursive: true);
    }
    final database = sqlite3.open(path);
    final result = UserDatabase._(database, path);
    result._ensureBaseSchema();
    result.ensureV4Schema();
    result.ensureV5Schema();
    result.ensureV6Schema();
    result.ensureV7Schema();
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

  void ensureV5Schema() {
    final current = int.tryParse(meta('schema_version') ?? '1') ?? 1;
    if (current >= 5 && _hasTable('passage_highlights')) return;
    db.execute('BEGIN IMMEDIATE');
    try {
      db.execute('''
        CREATE TABLE IF NOT EXISTS passage_highlights(
          id INTEGER PRIMARY KEY AUTOINCREMENT,
          passage_id INTEGER NOT NULL,
          start_offset INTEGER NOT NULL,
          end_offset INTEGER NOT NULL,
          highlighted_text TEXT NOT NULL,
          created_at INTEGER NOT NULL,
          updated_at INTEGER NOT NULL,
          CHECK(start_offset >= 0),
          CHECK(end_offset > start_offset),
          UNIQUE(passage_id,start_offset,end_offset)
        )
      ''');
      db.execute(
        'CREATE INDEX IF NOT EXISTS idx_passage_highlights_passage '
        'ON passage_highlights(passage_id,start_offset,end_offset)',
      );
      setMeta('schema_version', '5');
      db.execute('COMMIT');
    } catch (_) {
      db.execute('ROLLBACK');
      rethrow;
    }
  }

  void ensureV6Schema() {
    final current = int.tryParse(meta('schema_version') ?? '1') ?? 1;
    if (current >= 6 &&
        _hasTable('study_progress') &&
        _hasTable('study_certifications')) {
      return;
    }
    db.execute('BEGIN IMMEDIATE');
    try {
      db.execute('''
        CREATE TABLE IF NOT EXISTS study_progress(
          sermon_id INTEGER NOT NULL,
          pack_version INTEGER NOT NULL,
          status TEXT NOT NULL,
          reading_percent REAL NOT NULL DEFAULT 0,
          active_study_seconds INTEGER NOT NULL DEFAULT 0,
          last_section_id INTEGER,
          last_paragraph_key TEXT,
          last_passage_id INTEGER,
          last_offset INTEGER,
          started_at INTEGER NOT NULL,
          last_studied_at INTEGER NOT NULL,
          completed_at INTEGER,
          updated_at INTEGER NOT NULL,
          PRIMARY KEY(sermon_id,pack_version)
        )
      ''');
      db.execute(
        'CREATE INDEX IF NOT EXISTS idx_study_progress_status '
        'ON study_progress(status,last_studied_at DESC)',
      );

      db.execute('''
        CREATE TABLE IF NOT EXISTS study_paragraph_progress(
          sermon_id INTEGER NOT NULL,
          pack_version INTEGER NOT NULL,
          paragraph_key TEXT NOT NULL,
          character_count INTEGER NOT NULL,
          accumulated_visible_ms INTEGER NOT NULL DEFAULT 0,
          state TEXT NOT NULL DEFAULT 'unseen',
          first_seen_at INTEGER,
          read_at INTEGER,
          updated_at INTEGER NOT NULL,
          PRIMARY KEY(sermon_id,pack_version,paragraph_key)
        )
      ''');
      db.execute(
        'CREATE INDEX IF NOT EXISTS idx_study_paragraph_progress_state '
        'ON study_paragraph_progress(sermon_id,pack_version,state)',
      );

      db.execute('''
        CREATE TABLE IF NOT EXISTS study_section_progress(
          sermon_id INTEGER NOT NULL,
          pack_version INTEGER NOT NULL,
          section_id INTEGER NOT NULL,
          state TEXT NOT NULL,
          reading_percent REAL NOT NULL DEFAULT 0,
          checkpoint_score REAL,
          completed_at INTEGER,
          updated_at INTEGER NOT NULL,
          PRIMARY KEY(sermon_id,pack_version,section_id)
        )
      ''');

      db.execute('''
        CREATE TABLE IF NOT EXISTS study_question_attempts(
          id INTEGER PRIMARY KEY AUTOINCREMENT,
          question_id INTEGER NOT NULL,
          sermon_id INTEGER NOT NULL,
          pack_version INTEGER NOT NULL,
          context TEXT NOT NULL,
          attempt_id INTEGER,
          answer_payload TEXT NOT NULL,
          score REAL NOT NULL,
          answered_at INTEGER NOT NULL
        )
      ''');
      db.execute(
        'CREATE INDEX IF NOT EXISTS idx_study_question_attempts_question '
        'ON study_question_attempts(question_id,answered_at DESC)',
      );
      db.execute(
        'CREATE INDEX IF NOT EXISTS idx_study_question_attempts_sermon '
        'ON study_question_attempts(sermon_id,pack_version,context,answered_at DESC)',
      );

      db.execute('''
        CREATE TABLE IF NOT EXISTS study_exam_attempts(
          attempt_id INTEGER PRIMARY KEY AUTOINCREMENT,
          sermon_id INTEGER NOT NULL,
          pack_version INTEGER NOT NULL,
          seed TEXT NOT NULL,
          started_at INTEGER NOT NULL,
          submitted_at INTEGER,
          overall_score REAL,
          category_scores_json TEXT,
          passed INTEGER,
          attempt_number INTEGER NOT NULL
        )
      ''');
      db.execute(
        'CREATE INDEX IF NOT EXISTS idx_study_exam_attempts_sermon '
        'ON study_exam_attempts(sermon_id,pack_version,attempt_number DESC)',
      );

      db.execute('''
        CREATE TABLE IF NOT EXISTS study_exam_items(
          attempt_id INTEGER NOT NULL,
          question_id INTEGER NOT NULL,
          display_order INTEGER NOT NULL,
          option_order_json TEXT NOT NULL,
          PRIMARY KEY(attempt_id,question_id),
          FOREIGN KEY(attempt_id) REFERENCES study_exam_attempts(attempt_id)
            ON DELETE CASCADE
        )
      ''');
      db.execute(
        'CREATE INDEX IF NOT EXISTS idx_study_exam_items_order '
        'ON study_exam_items(attempt_id,display_order)',
      );

      db.execute('''
        CREATE TABLE IF NOT EXISTS study_certifications(
          certification_id TEXT PRIMARY KEY,
          sermon_id INTEGER NOT NULL,
          pack_version INTEGER NOT NULL,
          corpus_version TEXT NOT NULL,
          score REAL NOT NULL,
          category_scores_json TEXT NOT NULL,
          study_seconds INTEGER NOT NULL,
          attempt_id INTEGER NOT NULL,
          certified_at INTEGER NOT NULL,
          level TEXT NOT NULL,
          integrity_hash TEXT NOT NULL,
          UNIQUE(sermon_id,pack_version,attempt_id)
        )
      ''');
      db.execute(
        'CREATE INDEX IF NOT EXISTS idx_study_certifications_sermon '
        'ON study_certifications(sermon_id,certified_at DESC)',
      );

      setMeta('schema_version', '6');
      db.execute('COMMIT');
    } catch (_) {
      db.execute('ROLLBACK');
      rethrow;
    }
  }

  void ensureV7Schema() {
    final current = int.tryParse(meta('schema_version') ?? '1') ?? 1;
    if (current >= 7 && _hasTable('conversation_answer_spans')) return;
    db.execute('BEGIN IMMEDIATE');
    try {
      db.execute('''
        CREATE TABLE IF NOT EXISTS conversation_answer_spans(
          turn_id INTEGER NOT NULL,
          passage_id INTEGER NOT NULL,
          start_offset INTEGER NOT NULL,
          end_offset INTEGER NOT NULL,
          sentence_ordinal INTEGER NOT NULL DEFAULT 0,
          answer_confidence REAL,
          PRIMARY KEY(turn_id,passage_id),
          FOREIGN KEY(turn_id,passage_id)
            REFERENCES conversation_hits(turn_id,passage_id)
            ON DELETE CASCADE,
          CHECK(start_offset >= 0),
          CHECK(end_offset > start_offset)
        )
      ''');
      setMeta('schema_version', '7');
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
