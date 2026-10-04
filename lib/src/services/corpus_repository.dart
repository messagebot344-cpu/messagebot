import 'package:sqlite3/sqlite3.dart';

import '../models/models.dart';

class RankedPassage {
  const RankedPassage(this.passageId, this.rankValue);
  final int passageId;
  final double rankValue;
}

class CorpusRepository {
  Database? _db;
  List<SermonSummary>? _sermonCache;

  Database get db {
    final value = _db;
    if (value == null) throw StateError('Corpus non ouvert.');
    return value;
  }

  void open(String path) {
    _db?.dispose();
    _sermonCache = null;
    _db = sqlite3.open(path, mode: OpenMode.readOnly);
  }

  void close() {
    _db?.dispose();
    _db = null;
    _sermonCache = null;
  }

  CorpusStats getStats() {
    final rows = db.select('SELECT key, value FROM corpus_meta');
    final values = <String, String>{
      for (final row in rows) row['key'] as String: row['value'] as String,
    };
    return CorpusStats(
      sermons: int.parse(values['sermon_count'] ?? '0'),
      editions: int.parse(values['edition_count'] ?? '0'),
      passages: int.parse(values['passage_count'] ?? '0'),
      sourcePdfPages: int.parse(values['source_pdf_pages'] ?? '0'),
    );
  }

  List<SermonSummary> listSermons({String filter = '', int limit = 2000}) {
    final all = _sermonCache ??= db
        .select(
          'SELECT id, code, title, year, edition_count, primary_edition_id '
          'FROM sermons ORDER BY code',
        )
        .map(_sermonFromRow)
        .toList(growable: false);

    final normalized = _normalizeLookup(filter);
    if (normalized.isEmpty) {
      return all.take(limit).toList(growable: false);
    }

    return all
        .where((sermon) {
          final haystack = _normalizeLookup('${sermon.code} ${sermon.title}');
          return haystack.contains(normalized);
        })
        .take(limit)
        .toList(growable: false);
  }

  List<SermonSummary> sermonsByCodes(Iterable<String> codes) {
    final list = codes.toList(growable: false);
    if (list.isEmpty) return const [];
    final marks = List.filled(list.length, '?').join(',');
    final rows = db.select(
      'SELECT id, code, title, year, edition_count, primary_edition_id '
      'FROM sermons WHERE code IN ($marks) ORDER BY code',
      list,
    );
    return rows.map(_sermonFromRow).toList(growable: false);
  }

  SermonSummary? sermonById(int id) {
    final rows = db.select(
      'SELECT id, code, title, year, edition_count, primary_edition_id '
      'FROM sermons WHERE id = ? LIMIT 1',
      [id],
    );
    return rows.isEmpty ? null : _sermonFromRow(rows.first);
  }

  List<EditionSummary> editionsForSermon(int sermonId) {
    final rows = db.select(
      'SELECT id, sermon_id, title, is_primary, is_frn, source_page_start, source_page_end '
      'FROM editions WHERE sermon_id = ? ORDER BY is_primary DESC, source_page_start',
      [sermonId],
    );
    return rows.map(_editionFromRow).toList(growable: false);
  }

  EditionSummary? editionById(String id) {
    final rows = db.select(
      'SELECT id, sermon_id, title, is_primary, is_frn, source_page_start, source_page_end '
      'FROM editions WHERE id = ? LIMIT 1',
      [id],
    );
    return rows.isEmpty ? null : _editionFromRow(rows.first);
  }

  List<Passage> passagesForEdition(String editionId) {
    final rows = db.select(
      'SELECT id, edition_id, sermon_id, ordinal, source_page_start, source_page_end, text_display '
      'FROM passages WHERE edition_id = ? ORDER BY ordinal',
      [editionId],
    );
    return rows.map(_passageFromRow).toList(growable: false);
  }

  List<RankedPassage> lexicalSearch(String ftsQuery, {int limit = 80}) {
    if (ftsQuery.trim().isEmpty) return const [];
    try {
      final rows = db.select(
        'SELECT passages_fts.rowid AS passage_id, bm25(passages_fts) AS rank_value '
        'FROM passages_fts '
        'JOIN passages p ON p.id = passages_fts.rowid '
        'JOIN editions e ON e.id = p.edition_id '
        'WHERE passages_fts MATCH ? AND e.is_primary = 1 '
        'ORDER BY rank_value LIMIT ?',
        [ftsQuery, limit],
      );
      return rows
          .map(
            (r) => RankedPassage(
              r['passage_id'] as int,
              (r['rank_value'] as num).toDouble(),
            ),
          )
          .toList(growable: false);
    } on SqliteException {
      return const [];
    }
  }

  List<RankedPassage> lexicalSearchSermons(
    String ftsQuery,
    Iterable<String> sermonCodes, {
    int limit = 80,
  }) {
    final codes = sermonCodes
        .map((value) => value.trim())
        .where((value) => value.isNotEmpty)
        .toSet()
        .toList(growable: false);
    if (ftsQuery.trim().isEmpty || codes.isEmpty) {
      return const [];
    }
    final marks = List.filled(codes.length, '?').join(',');
    try {
      final rows = db.select(
        'SELECT passages_fts.rowid AS passage_id, '
        'bm25(passages_fts) AS rank_value '
        'FROM passages_fts '
        'JOIN passages p ON p.id = passages_fts.rowid '
        'JOIN editions e ON e.id = p.edition_id '
        'JOIN sermons s ON s.id = p.sermon_id '
        'WHERE passages_fts MATCH ? '
        'AND s.code IN ($marks) '
        'ORDER BY e.is_primary DESC, rank_value LIMIT ?',
        <Object?>[ftsQuery, ...codes, limit],
      );
      return rows
          .map(
            (row) => RankedPassage(
              row['passage_id'] as int,
              (row['rank_value'] as num).toDouble(),
            ),
          )
          .toList(growable: false);
    } on SqliteException {
      return const [];
    }
  }

  List<RankedPassage> lexicalSearchAlternates(String ftsQuery, {int limit = 60}) {
    if (ftsQuery.trim().isEmpty) return const [];
    try {
      final rows = db.select(
        'SELECT passages_fts.rowid AS passage_id, bm25(passages_fts) AS rank_value '
        'FROM passages_fts '
        'JOIN passages p ON p.id = passages_fts.rowid '
        'JOIN editions e ON e.id = p.edition_id '
        'WHERE passages_fts MATCH ? AND e.is_primary = 0 '
        'ORDER BY rank_value LIMIT ?',
        [ftsQuery, limit],
      );
      return rows
          .map(
            (r) => RankedPassage(
              r['passage_id'] as int,
              (r['rank_value'] as num).toDouble(),
            ),
          )
          .toList(growable: false);
    } on SqliteException {
      return const [];
    }
  }

  List<int> titleOrCodeMatches(String query, {int limit = 20}) {
    final q = query.trim();
    if (q.isEmpty) return const [];
    final sermons = listSermons(filter: q, limit: limit);
    if (sermons.isEmpty) return const [];
    final editionIds = sermons.map((s) => s.primaryEditionId).toList(growable: false);
    final marks = List.filled(editionIds.length, '?').join(',');
    final rows = db.select(
      'SELECT edition_id, MIN(id) AS passage_id FROM passages '
      'WHERE edition_id IN ($marks) GROUP BY edition_id',
      editionIds,
    );
    final byEdition = <String, int>{
      for (final row in rows)
        if (row['passage_id'] != null)
          row['edition_id'] as String: row['passage_id'] as int,
    };
    return sermons
        .map((sermon) => byEdition[sermon.primaryEditionId])
        .whereType<int>()
        .toList(growable: false);
  }

  Map<int, ({Passage passage, SermonSummary sermon, EditionSummary edition})>
      detailsForPassageIds(Iterable<int> ids) {
    final list = ids.toList(growable: false);
    if (list.isEmpty) return const {};
    final marks = List.filled(list.length, '?').join(',');
    final rows = db.select(
      'SELECT p.id AS passage_id, p.edition_id, p.sermon_id, p.ordinal, '
      'p.source_page_start, p.source_page_end, p.text_display, '
      's.code, s.title AS sermon_title, s.year, s.edition_count, s.primary_edition_id, '
      'e.title AS edition_title, e.is_primary, e.is_frn, '
      'e.source_page_start AS edition_page_start, e.source_page_end AS edition_page_end '
      'FROM passages p JOIN sermons s ON s.id = p.sermon_id '
      'JOIN editions e ON e.id = p.edition_id '
      'WHERE p.id IN ($marks)',
      list,
    );
    final result = <int, ({Passage passage, SermonSummary sermon, EditionSummary edition})>{};
    for (final r in rows) {
      final passage = Passage(
        id: r['passage_id'] as int,
        editionId: r['edition_id'] as String,
        sermonId: r['sermon_id'] as int,
        ordinal: r['ordinal'] as int,
        sourcePageStart: r['source_page_start'] as int,
        sourcePageEnd: r['source_page_end'] as int,
        text: r['text_display'] as String,
      );
      final sermon = SermonSummary(
        id: r['sermon_id'] as int,
        code: r['code'] as String,
        title: r['sermon_title'] as String,
        year: r['year'] as int,
        editionCount: r['edition_count'] as int,
        primaryEditionId: r['primary_edition_id'] as String,
      );
      final edition = EditionSummary(
        id: r['edition_id'] as String,
        sermonId: r['sermon_id'] as int,
        title: r['edition_title'] as String,
        isPrimary: (r['is_primary'] as int) == 1,
        isFrn: (r['is_frn'] as int) == 1,
        sourcePageStart: r['edition_page_start'] as int,
        sourcePageEnd: r['edition_page_end'] as int,
      );
      result[passage.id] = (passage: passage, sermon: sermon, edition: edition);
    }
    return result;
  }


  Map<int, StudyPassage> studyDetailsForPassageIds(Iterable<int> ids) {
    final list = ids.toList(growable: false);
    if (list.isEmpty) return const {};
    final marks = List.filled(list.length, '?').join(',');
    final rows = db.select(
      'SELECT p.id AS passage_id,p.edition_id,p.sermon_id,p.ordinal,p.source_page_start,p.source_page_end,p.text_display, '
      'p.source_id,p.source_type,p.book_chapter_id, src.title AS source_title,src.code AS source_code,src.year AS source_year, '
      's.code AS sermon_code,s.title AS sermon_title,s.year AS sermon_year,s.edition_count,s.primary_edition_id, '
      'e.title AS edition_title,e.is_primary,e.is_frn,e.source_page_start AS edition_page_start,e.source_page_end AS edition_page_end, '
      'bc.title AS chapter_title '
      'FROM passages p JOIN sources src ON src.id=p.source_id '
      'LEFT JOIN sermons s ON s.id=p.sermon_id '
      'LEFT JOIN editions e ON e.id=p.edition_id '
      'LEFT JOIN book_chapters bc ON bc.id=p.book_chapter_id '
      'WHERE p.id IN ($marks)',
      list,
    );
    final result = <int, StudyPassage>{};
    for (final r in rows) {
      final passage = Passage(
        id: r['passage_id'] as int,
        editionId: r['edition_id'] as String,
        sermonId: r['sermon_id'] as int,
        ordinal: r['ordinal'] as int,
        sourcePageStart: r['source_page_start'] as int,
        sourcePageEnd: r['source_page_end'] as int,
        text: r['text_display'] as String,
      );
      final isBook = (r['source_type'] as String) == 'book';
      final source = CorpusSourceSummary(
        id: r['source_id'] as String,
        type: isBook ? CorpusSourceType.book : CorpusSourceType.sermon,
        title: r['source_title'] as String,
        code: r['source_code'] as String?,
        year: r['source_year'] as int?,
      );
      SermonSummary? sermon;
      EditionSummary? edition;
      if (!isBook && r['sermon_code'] != null) {
        sermon = SermonSummary(
          id: r['sermon_id'] as int,
          code: r['sermon_code'] as String,
          title: r['sermon_title'] as String,
          year: r['sermon_year'] as int,
          editionCount: r['edition_count'] as int,
          primaryEditionId: r['primary_edition_id'] as String,
        );
        if (r['edition_title'] != null) {
          edition = EditionSummary(
            id: r['edition_id'] as String,
            sermonId: r['sermon_id'] as int,
            title: r['edition_title'] as String,
            isPrimary: (r['is_primary'] as int) == 1,
            isFrn: (r['is_frn'] as int) == 1,
            sourcePageStart: r['edition_page_start'] as int,
            sourcePageEnd: r['edition_page_end'] as int,
          );
        }
      }
      result[passage.id] = StudyPassage(
        passage: passage,
        source: source,
        sermon: sermon,
        edition: edition,
        chapterTitle: r['chapter_title'] as String?,
      );
    }
    return result;
  }

  List<NeighborPassage> neighborPassages(
    int passageId, {
    int limit = 20,
    String? relationScope,
  }) {
    final filter = relationScope == null ? '' : ' AND relation_scope=?';
    final params = <Object?>[passageId];
    if (relationScope != null) params.add(relationScope);
    params.add(limit);
    final rows = db.select(
      'SELECT neighbor_passage_id,similarity_score,relation_scope FROM passage_neighbors '
      'WHERE source_passage_id=?$filter ORDER BY similarity_score DESC LIMIT ?',
      params,
    );
    return rows.map((r) => NeighborPassage(
      passageId: r['neighbor_passage_id'] as int,
      score: (r['similarity_score'] as num).toDouble(),
      relationScope: r['relation_scope'] as String,
    )).toList(growable: false);
  }

  List<TermStat> searchTermStats(String filter, {int limit = 100}) {
    final q = _normalizeLookup(filter);
    final rows = q.isEmpty
        ? db.select(
            'SELECT term,document_count,total_occurrences FROM term_stats '
            'ORDER BY total_occurrences DESC,term LIMIT ?',
            [limit],
          )
        : db.select(
            'SELECT term,document_count,total_occurrences FROM term_stats '
            'WHERE term LIKE ? ORDER BY CASE WHEN term=? THEN 0 ELSE 1 END,total_occurrences DESC,term LIMIT ?',
            ['%$q%', q, limit],
          );
    return rows.map((r) => TermStat(
      term: r['term'] as String,
      documentCount: r['document_count'] as int,
      totalOccurrences: r['total_occurrences'] as int,
    )).toList(growable: false);
  }

  List<TermStat> searchTermStatsByPrefix(
    String prefix, {
    int limit = 100,
  }) {
    final q = _normalizeLookup(prefix);
    if (q.isEmpty) return const [];
    final rows = db.select(
      'SELECT term,document_count,total_occurrences FROM term_stats '
      'WHERE term LIKE ? '
      'ORDER BY CASE WHEN term=? THEN 0 ELSE 1 END,'
      'total_occurrences DESC,term LIMIT ?',
      ['$q%', q, limit],
    );
    return rows
        .map(
          (r) => TermStat(
            term: r['term'] as String,
            documentCount: r['document_count'] as int,
            totalOccurrences: r['total_occurrences'] as int,
          ),
        )
        .toList(growable: false);
  }

  List<int> concordancePassageIds(
    String term, {
    int limit = 100,
    CorpusSourceType? sourceType,
  }) {
    final normalized = _normalizeLookup(term).replaceAll("'", "''");
    if (normalized.isEmpty) return const [];
    final sourceClause = sourceType == null
        ? ''
        : sourceType == CorpusSourceType.book
            ? " AND p.source_type='book'"
            : " AND p.source_type='sermon'";
    try {
      final rows = db.select(
        'SELECT passages_fts.rowid AS passage_id FROM passages_fts '
        'JOIN passages p ON p.id=passages_fts.rowid '
        'WHERE passages_fts MATCH ?$sourceClause ORDER BY passages_fts.rowid LIMIT ?',
        ['"$normalized"', limit],
      );
      return rows.map((r) => r['passage_id'] as int).toList(growable: false);
    } on SqliteException {
      return const [];
    }
  }


  List<CorpusSourceSummary> listBookSources({String filter = '', int limit = 100}) {
    final normalized = _normalizeLookup(filter);
    final rows = normalized.isEmpty
        ? db.select(
            "SELECT id,source_type,title,code,year FROM sources WHERE source_type='book' ORDER BY sort_key LIMIT ?",
            [limit],
          )
        : db.select(
            "SELECT id,source_type,title,code,year FROM sources WHERE source_type='book' AND lower(title) LIKE ? ORDER BY sort_key LIMIT ?",
            ['%${filter.toLowerCase()}%', limit],
          );
    return rows
        .map((r) => CorpusSourceSummary(
              id: r['id'] as String,
              type: CorpusSourceType.book,
              title: r['title'] as String,
              code: r['code'] as String?,
              year: r['year'] as int?,
            ))
        .toList(growable: false);
  }

  Map<String, int> bookChapterCounts(Iterable<String> sourceIds) {
    final ids = sourceIds.toSet().toList(growable: false);
    if (ids.isEmpty) return const <String, int>{};
    final marks = List.filled(ids.length, '?').join(',');
    final rows = db.select(
      'SELECT source_id,COUNT(*) AS n FROM book_chapters '
      'WHERE source_id IN ($marks) GROUP BY source_id',
      ids,
    );
    return <String, int>{
      for (final row in rows)
        row['source_id'] as String: row['n'] as int,
    };
  }

  CorpusSourceSummary? sourceById(String sourceId) {
    final rows = db.select(
      'SELECT id,source_type,title,code,year FROM sources WHERE id=? LIMIT 1',
      [sourceId],
    );
    if (rows.isEmpty) return null;
    final r = rows.first;
    return CorpusSourceSummary(
      id: r['id'] as String,
      type: (r['source_type'] as String) == 'book' ? CorpusSourceType.book : CorpusSourceType.sermon,
      title: r['title'] as String,
      code: r['code'] as String?,
      year: r['year'] as int?,
    );
  }

  List<BookChapterSummary> chaptersForBook(String sourceId) => db
      .select(
        'SELECT id,source_id,title,ordinal,source_page_start,source_page_end '
        'FROM book_chapters WHERE source_id=? ORDER BY ordinal',
        [sourceId],
      )
      .map((r) => BookChapterSummary(
            id: r['id'] as int,
            sourceId: r['source_id'] as String,
            title: r['title'] as String,
            ordinal: r['ordinal'] as int,
            sourcePageStart: r['source_page_start'] as int,
            sourcePageEnd: r['source_page_end'] as int,
          ))
      .toList(growable: false);

  List<Passage> passagesForBook(String sourceId, {int? chapterId}) {
    final rows = chapterId == null
        ? db.select(
            'SELECT id,edition_id,sermon_id,ordinal,source_page_start,source_page_end,text_display '
            "FROM passages WHERE source_type='book' AND source_id=? ORDER BY ordinal",
            [sourceId],
          )
        : db.select(
            'SELECT id,edition_id,sermon_id,ordinal,source_page_start,source_page_end,text_display '
            "FROM passages WHERE source_type='book' AND source_id=? AND book_chapter_id=? ORDER BY ordinal",
            [sourceId, chapterId],
          );
    return rows.map(_passageFromRow).toList(growable: false);
  }

  List<RankedPassage> lexicalSearchAll(String ftsQuery, {int limit = 120}) {
    if (ftsQuery.trim().isEmpty) return const [];
    try {
      final rows = db.select(
        'SELECT passages_fts.rowid AS passage_id,bm25(passages_fts) AS rank_value '
        'FROM passages_fts JOIN passages p ON p.id=passages_fts.rowid '
        'LEFT JOIN editions e ON e.id=p.edition_id '
        "WHERE passages_fts MATCH ? AND (p.source_type='book' OR e.is_primary=1) "
        'ORDER BY rank_value LIMIT ?',
        [ftsQuery, limit],
      );
      return rows
          .map((r) => RankedPassage(r['passage_id'] as int, (r['rank_value'] as num).toDouble()))
          .toList(growable: false);
    } on SqliteException {
      return const [];
    }
  }

  List<RankedPassage> lexicalSearchBooks(String ftsQuery, {int limit = 120}) {
    if (ftsQuery.trim().isEmpty) return const [];
    try {
      final rows = db.select(
        'SELECT passages_fts.rowid AS passage_id,bm25(passages_fts) AS rank_value '
        'FROM passages_fts JOIN passages p ON p.id=passages_fts.rowid '
        "WHERE passages_fts MATCH ? AND p.source_type='book' ORDER BY rank_value LIMIT ?",
        [ftsQuery, limit],
      );
      return rows
          .map((r) => RankedPassage(r['passage_id'] as int, (r['rank_value'] as num).toDouble()))
          .toList(growable: false);
    } on SqliteException {
      return const [];
    }
  }

  List<int> sourceTitleMatches(String query, {CorpusSourceType? sourceType, int limit = 30}) {
    final q = query.trim().toLowerCase();
    if (q.isEmpty) return const [];
    final clauses = <String>["lower(src.title) LIKE ?"];
    final params = <Object?>['%$q%'];
    if (sourceType == CorpusSourceType.book) clauses.add("src.source_type='book'");
    if (sourceType == CorpusSourceType.sermon) clauses.add("src.source_type='sermon'");
    params.add(limit);
    final rows = db.select(
      'SELECT src.id,src.source_type,MIN(p.id) AS passage_id FROM sources src '
      'JOIN passages p ON p.source_id=src.id '
      'LEFT JOIN editions e ON e.id=p.edition_id '
      'WHERE ${clauses.join(' AND ')} '
      "AND (src.source_type='book' OR e.is_primary=1) "
      'GROUP BY src.id,src.source_type ORDER BY src.sort_key LIMIT ?',
      params,
    );
    return rows.map((r) => r['passage_id'] as int).toList(growable: false);
  }

  String _normalizeLookup(String input) {
    var value = input.toLowerCase();
    const replacements = <String, String>{
      'à': 'a', 'á': 'a', 'â': 'a', 'ä': 'a', 'ã': 'a', 'å': 'a',
      'ç': 'c', 'è': 'e', 'é': 'e', 'ê': 'e', 'ë': 'e',
      'ì': 'i', 'í': 'i', 'î': 'i', 'ï': 'i',
      'ñ': 'n', 'ò': 'o', 'ó': 'o', 'ô': 'o', 'ö': 'o', 'õ': 'o',
      'ù': 'u', 'ú': 'u', 'û': 'u', 'ü': 'u', 'ý': 'y', 'ÿ': 'y',
      'œ': 'oe', 'æ': 'ae', '’': "'", '‘': "'",
    };
    replacements.forEach((from, to) => value = value.replaceAll(from, to));
    return value.replaceAll(RegExp(r'\s+'), ' ').trim();
  }

  SermonSummary _sermonFromRow(Row r) => SermonSummary(
        id: r['id'] as int,
        code: r['code'] as String,
        title: r['title'] as String,
        year: r['year'] as int,
        editionCount: r['edition_count'] as int,
        primaryEditionId: r['primary_edition_id'] as String,
      );

  EditionSummary _editionFromRow(Row r) => EditionSummary(
        id: r['id'] as String,
        sermonId: r['sermon_id'] as int,
        title: r['title'] as String,
        isPrimary: (r['is_primary'] as int) == 1,
        isFrn: (r['is_frn'] as int) == 1,
        sourcePageStart: r['source_page_start'] as int,
        sourcePageEnd: r['source_page_end'] as int,
      );

  Passage _passageFromRow(Row r) => Passage(
        id: r['id'] as int,
        editionId: r['edition_id'] as String,
        sermonId: r['sermon_id'] as int,
        ordinal: r['ordinal'] as int,
        sourcePageStart: r['source_page_start'] as int,
        sourcePageEnd: r['source_page_end'] as int,
        text: r['text_display'] as String,
      );
}
