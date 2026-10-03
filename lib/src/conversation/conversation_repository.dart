import '../personal/user_database.dart';
import 'conversation_models.dart';

class ConversationRepository {
  ConversationRepository(this.database);

  final UserDatabase database;
  int get _now => DateTime.now().millisecondsSinceEpoch;

  int createConversation(String firstQuery) {
    final title = _titleFrom(firstQuery);
    final now = _now;
    database.db.execute(
      'INSERT INTO conversations(title,created_at,updated_at,pinned) VALUES(?,?,?,0)',
      [title, now, now],
    );
    final id = database.db.lastInsertRowId;
    _reindexConversation(id);
    return id;
  }

  void renameConversation(int id, String title) {
    final clean = title.trim();
    if (clean.isEmpty) return;
    database.db.execute('UPDATE conversations SET title=?,updated_at=? WHERE id=?', [clean, _now, id]);
    _reindexConversation(id);
  }

  void pinConversation(int id, bool pinned) {
    database.db.execute('UPDATE conversations SET pinned=?,updated_at=? WHERE id=?', [pinned ? 1 : 0, _now, id]);
  }

  void deleteConversation(int id) {
    database.db.execute('DELETE FROM conversations WHERE id=?', [id]);
    database.db.execute('DELETE FROM conversation_search_fts WHERE rowid=?', [id]);
  }

  List<ConversationSummary> listConversations({String search = ''}) {
    final q = search.trim();
    if (q.isEmpty) {
      return database.db.select(
        'SELECT id,title,created_at,updated_at,pinned FROM conversations ORDER BY pinned DESC,updated_at DESC',
      ).map(_summary).toList(growable: false);
    }
    final ids = database.db.select(
      'SELECT rowid FROM conversation_search_fts WHERE conversation_search_fts MATCH ? ORDER BY rank',
      [_ftsQuery(q)],
    ).map((r) => r['rowid'] as int).toList(growable: false);
    if (ids.isEmpty) return const [];
    final marks = List.filled(ids.length, '?').join(',');
    final rows = database.db.select(
      'SELECT id,title,created_at,updated_at,pinned FROM conversations WHERE id IN ($marks)',
      ids,
    );
    final byId = {for (final r in rows) r['id'] as int: _summary(r)};
    return ids.where(byId.containsKey).map((id) => byId[id]!).toList(growable: false);
  }

  int appendTurn({
    required int conversationId,
    required String query,
    required ConversationFilterSet filters,
    required List<PersistedHitRef> hits,
  }) {
    final now = _now;
    database.db.execute('BEGIN IMMEDIATE');
    try {
      database.db.execute('''
        INSERT INTO conversation_turns(
          conversation_id,query,subject_terms,year_min,year_max,source_type,source_id,result_count,created_at
        ) VALUES(?,?,?,?,?,?,?,?,?)
      ''', [
        conversationId,
        query,
        filters.subjectTerms.join('\u001f'),
        filters.yearMin,
        filters.yearMax,
        filters.sourceType,
        filters.sourceId,
        hits.length,
        now,
      ]);
      final turnId = database.db.lastInsertRowId;
      final stmt = database.db.prepare(
        'INSERT INTO conversation_hits(turn_id,passage_id,rank,score,expanded) VALUES(?,?,?,?,?)',
      );
      try {
        for (final hit in hits) {
          stmt.execute([turnId, hit.passageId, hit.rank, hit.score, hit.expanded ? 1 : 0]);
        }
      } finally {
        stmt.dispose();
      }
      database.db.execute('UPDATE conversations SET updated_at=? WHERE id=?', [now, conversationId]);
      database.db.execute('COMMIT');
      _reindexConversation(conversationId);
      return turnId;
    } catch (_) {
      database.db.execute('ROLLBACK');
      rethrow;
    }
  }

  List<ConversationTurnRecord> loadConversation(int conversationId) {
    final rows = database.db.select('''
      SELECT id,conversation_id,query,subject_terms,year_min,year_max,source_type,source_id,created_at
      FROM conversation_turns WHERE conversation_id=? ORDER BY id
    ''', [conversationId]);
    final result = <ConversationTurnRecord>[];
    for (final row in rows) {
      final turnId = row['id'] as int;
      final hitRows = database.db.select(
        'SELECT passage_id,rank,score,expanded FROM conversation_hits WHERE turn_id=? ORDER BY rank',
        [turnId],
      );
      result.add(ConversationTurnRecord(
        id: turnId,
        conversationId: conversationId,
        query: row['query'] as String,
        filters: ConversationFilterSet(
          subjectTerms: ((row['subject_terms'] as String?) ?? '').split('\u001f').where((e) => e.isNotEmpty).toList(growable: false),
          yearMin: row['year_min'] as int?,
          yearMax: row['year_max'] as int?,
          sourceType: row['source_type'] as String?,
          sourceId: row['source_id'] as String?,
        ),
        createdAt: row['created_at'] as int,
        hits: hitRows.map((h) => PersistedHitRef(
          passageId: h['passage_id'] as int,
          rank: h['rank'] as int,
          score: (h['score'] as num).toDouble(),
          expanded: (h['expanded'] as int) == 1,
        )).toList(growable: false),
      ));
    }
    return result;
  }

  void setHitExpanded(int turnId, int passageId, bool expanded) {
    database.db.execute(
      'UPDATE conversation_hits SET expanded=? WHERE turn_id=? AND passage_id=?',
      [expanded ? 1 : 0, turnId, passageId],
    );
  }

  void saveScrollOffset(int conversationId, double offset) {
    database.db.execute('''
      INSERT INTO conversation_ui_state(conversation_id,scroll_offset,updated_at) VALUES(?,?,?)
      ON CONFLICT(conversation_id) DO UPDATE SET scroll_offset=excluded.scroll_offset,updated_at=excluded.updated_at
    ''', [conversationId, offset, _now]);
  }

  double loadScrollOffset(int conversationId) {
    final rows = database.db.select('SELECT scroll_offset FROM conversation_ui_state WHERE conversation_id=?', [conversationId]);
    return rows.isEmpty ? 0 : (rows.first['scroll_offset'] as num).toDouble();
  }

  ConversationSummary _summary(dynamic row) => ConversationSummary(
        id: row['id'] as int,
        title: row['title'] as String,
        createdAt: row['created_at'] as int,
        updatedAt: row['updated_at'] as int,
        pinned: (row['pinned'] as int) == 1,
      );

  String _titleFrom(String query) {
    final clean = query.trim().replaceAll(RegExp(r'\s+'), ' ');
    if (clean.length <= 58) return clean;
    return '${clean.substring(0, 58)}…';
  }

  String _ftsQuery(String input) {
    return input
        .split(RegExp(r'\s+'))
        .where((e) => e.trim().isNotEmpty)
        .take(10)
        .map((e) => '"${e.replaceAll('"', '""')}"*')
        .join(' OR ');
  }

  void _reindexConversation(int id) {
    final convo = database.db.select('SELECT title FROM conversations WHERE id=?', [id]);
    if (convo.isEmpty) return;
    final queries = database.db.select(
      'SELECT query FROM conversation_turns WHERE conversation_id=? ORDER BY id DESC LIMIT 30',
      [id],
    ).map((r) => r['query'] as String).join(' ');
    database.db.execute('DELETE FROM conversation_search_fts WHERE rowid=?', [id]);
    database.db.execute(
      'INSERT INTO conversation_search_fts(rowid,title,query) VALUES(?,?,?)',
      [id, convo.first['title'] as String, queries],
    );
  }
}
