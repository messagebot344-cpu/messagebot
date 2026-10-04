import 'dart:convert';

import 'package:sqlite3/sqlite3.dart';

import 'study_pack_models.dart';

class StudyPackCompatibilityException implements Exception {
  const StudyPackCompatibilityException(this.message);
  final String message;

  @override
  String toString() => 'StudyPackCompatibilityException: $message';
}

class StudyPackRepository {
  StudyPackRepository._(this.db, this.path);

  final Database db;
  final String path;

  static StudyPackRepository open(
    String path, {
    required String expectedCorpusVersion,
    required String expectedCanonicalSha256,
  }) {
    final database = sqlite3.open(path, mode: OpenMode.readOnly);
    final repository = StudyPackRepository._(database, path);
    try {
      repository._validate(
        expectedCorpusVersion: expectedCorpusVersion,
        expectedCanonicalSha256: expectedCanonicalSha256,
      );
      return repository;
    } catch (_) {
      database.dispose();
      rethrow;
    }
  }

  void _validate({
    required String expectedCorpusVersion,
    required String expectedCanonicalSha256,
  }) {
    final quick = db.select('PRAGMA quick_check');
    if (quick.isEmpty ||
        quick.first.values.first.toString().toLowerCase() != 'ok') {
      throw const StudyPackCompatibilityException(
        'PRAGMA quick_check a échoué.',
      );
    }
    final schemaVersion = meta('schema_version');
    if (schemaVersion != '1') {
      throw StudyPackCompatibilityException(
        'Version de schéma Study Pack incompatible: $schemaVersion.',
      );
    }
    final corpusVersion = meta('corpus_version');
    if (corpusVersion != expectedCorpusVersion) {
      throw StudyPackCompatibilityException(
        'Version du corpus incompatible: $corpusVersion != $expectedCorpusVersion.',
      );
    }
    final canonicalSha = meta('corpus_canonical_sha256');
    if (canonicalSha != expectedCanonicalSha256) {
      throw const StudyPackCompatibilityException(
        'Le Study Pack ne correspond pas au texte canonique installé.',
      );
    }
  }

  String? meta(String key) {
    final rows = db.select(
      'SELECT value FROM study_pack_meta WHERE key=? LIMIT 1',
      [key],
    );
    return rows.isEmpty ? null : rows.first['value'] as String;
  }

  int get publishedPackCount => db
      .select("SELECT COUNT(*) AS n FROM study_packs WHERE status='published'")
      .first['n'] as int;

  bool hasPublishedPackForSermon(int sermonId) => db.select(
        "SELECT 1 FROM study_packs WHERE sermon_id=? AND status='published' "
        'ORDER BY pack_version DESC LIMIT 1',
        [sermonId],
      ).isNotEmpty;

  SermonStudyPackSummary? latestPublishedPack(int sermonId) {
    final rows = db.select(
      "SELECT sp.*, "
      '(SELECT COUNT(*) FROM study_sections s WHERE s.sermon_id=sp.sermon_id AND s.pack_version=sp.pack_version) AS section_count, '
      '(SELECT COUNT(*) FROM study_questions q WHERE q.sermon_id=sp.sermon_id AND q.pack_version=sp.pack_version) AS question_count, '
      "(SELECT COUNT(*) FROM study_questions q WHERE q.sermon_id=sp.sermon_id AND q.pack_version=sp.pack_version AND q.validation_status='validated') AS validated_question_count "
      "FROM study_packs sp WHERE sp.sermon_id=? AND sp.status='published' "
      'ORDER BY sp.pack_version DESC LIMIT 1',
      [sermonId],
    );
    return rows.isEmpty ? null : _packFromRow(rows.first);
  }

  List<SermonStudyPackSummary> publishedPacks({int limit = 2000}) => db
      .select(
        "SELECT sp.*, "
        '(SELECT COUNT(*) FROM study_sections s WHERE s.sermon_id=sp.sermon_id AND s.pack_version=sp.pack_version) AS section_count, '
        '(SELECT COUNT(*) FROM study_questions q WHERE q.sermon_id=sp.sermon_id AND q.pack_version=sp.pack_version) AS question_count, '
        "(SELECT COUNT(*) FROM study_questions q WHERE q.sermon_id=sp.sermon_id AND q.pack_version=sp.pack_version AND q.validation_status='validated') AS validated_question_count "
        "FROM study_packs sp WHERE sp.status='published' "
        'ORDER BY sp.sermon_code LIMIT ?',
        [limit],
      )
      .map(_packFromRow)
      .toList(growable: false);

  List<StudySection> sectionsFor(int sermonId, int packVersion) {
    final rows = db.select(
      'SELECT id,sermon_id,pack_version,ordinal,title,kind,required_for_exam,minimum_reading_percent '
      'FROM study_sections WHERE sermon_id=? AND pack_version=? ORDER BY ordinal',
      [sermonId, packVersion],
    );
    return rows.map((row) {
      final sectionId = row['id'] as int;
      final paragraphs = db
          .select(
            'SELECT paragraph_key FROM study_section_paragraphs '
            'WHERE section_id=? ORDER BY position',
            [sectionId],
          )
          .map((value) => value['paragraph_key'] as String)
          .toList(growable: false);
      return StudySection(
        id: sectionId,
        sermonId: row['sermon_id'] as int,
        packVersion: row['pack_version'] as int,
        ordinal: row['ordinal'] as int,
        title: row['title'] as String,
        kind: row['kind'] as String,
        requiredForExam: (row['required_for_exam'] as int) == 1,
        minimumReadingPercent:
            (row['minimum_reading_percent'] as num).toDouble(),
        paragraphKeys: paragraphs,
      );
    }).toList(growable: false);
  }

  List<StudyParagraph> paragraphsForSermon(int sermonId, int packVersion) => db
      .select(
        'SELECT paragraph_key,sermon_id,edition_id,passage_id,global_ordinal,start_offset,end_offset,'
        'source_page_start,source_page_end,text_sha256,character_count,printed_paragraph_number '
        'FROM study_paragraphs WHERE sermon_id=? AND pack_version=? ORDER BY global_ordinal',
        [sermonId, packVersion],
      )
      .map(_paragraphFromRow)
      .toList(growable: false);

  List<StudyParagraph> paragraphsForSection(int sectionId) => db
      .select(
        'SELECT p.paragraph_key,p.sermon_id,p.edition_id,p.passage_id,p.global_ordinal,p.start_offset,p.end_offset,'
        'p.source_page_start,p.source_page_end,p.text_sha256,p.character_count,p.printed_paragraph_number '
        'FROM study_section_paragraphs sp '
        'JOIN study_paragraphs p ON p.paragraph_key=sp.paragraph_key '
        'WHERE sp.section_id=? ORDER BY sp.position',
        [sectionId],
      )
      .map(_paragraphFromRow)
      .toList(growable: false);

  List<StudyQuestion> questionsForSection(
    int sermonId,
    int packVersion,
    int sectionId, {
    bool validatedOnly = true,
  }) {
    final statusClause =
        validatedOnly ? " AND q.validation_status='validated'" : '';
    final rows = db.select(
      'SELECT q.id,q.sermon_id,q.pack_version,q.section_id,q.type,q.category,q.difficulty,'
      'q.prompt,q.pedagogical_explanation,q.correct_answer_payload,q.scoring_payload,q.validation_status,q.certification_eligible '
      'FROM study_questions q WHERE q.sermon_id=? AND q.pack_version=? AND q.section_id=?'
      '$statusClause ORDER BY q.id',
      [sermonId, packVersion, sectionId],
    );
    return rows.map(_questionFromRow).toList(growable: false);
  }

  List<StudyQuestion> certificationQuestionPool(
    int sermonId,
    int packVersion, {
    StudyQuestionCategory? category,
  }) {
    final params = <Object?>[sermonId, packVersion];
    var categoryClause = '';
    if (category != null) {
      categoryClause = ' AND q.category=?';
      params.add(_categoryName(category));
    }
    final rows = db.select(
      "SELECT q.id,q.sermon_id,q.pack_version,q.section_id,q.type,q.category,q.difficulty,"
      "q.prompt,q.pedagogical_explanation,q.correct_answer_payload,q.scoring_payload,q.validation_status,q.certification_eligible "
      "FROM study_questions q WHERE q.sermon_id=? AND q.pack_version=? "
      "AND q.validation_status='validated' AND q.certification_eligible=1"
      '$categoryClause ORDER BY q.id',
      params,
    );
    return rows.map(_questionFromRow).toList(growable: false);
  }

  StudyExamRules? examRules(int sermonId, int packVersion) {
    final rows = db.select(
      'SELECT sermon_id,pack_version,exam_size,pass_threshold,recent_question_exclusion_count,'
      'minimum_reading_percent,minimum_bank_multiplier '
      'FROM study_exam_rules WHERE sermon_id=? AND pack_version=? LIMIT 1',
      [sermonId, packVersion],
    );
    if (rows.isEmpty) return null;
    final row = rows.first;
    final categoryRows = db.select(
      'SELECT category,weight,question_count,minimum_score '
      'FROM study_exam_category_rules WHERE sermon_id=? AND pack_version=? ORDER BY category',
      [sermonId, packVersion],
    );
    return StudyExamRules(
      sermonId: row['sermon_id'] as int,
      packVersion: row['pack_version'] as int,
      examSize: row['exam_size'] as int,
      passThreshold: (row['pass_threshold'] as num).toDouble(),
      recentQuestionExclusionCount:
          row['recent_question_exclusion_count'] as int,
      minimumReadingPercent:
          (row['minimum_reading_percent'] as num).toDouble(),
      minimumBankMultiplier:
          (row['minimum_bank_multiplier'] as num).toDouble(),
      categories: categoryRows
          .map(
            (item) => StudyExamCategoryRule(
              category: _categoryFromName(item['category'] as String),
              weight: (item['weight'] as num).toDouble(),
              questionCount: item['question_count'] as int,
              minimumScore: item['minimum_score'] == null
                  ? null
                  : (item['minimum_score'] as num).toDouble(),
            ),
          )
          .toList(growable: false),
    );
  }

  List<StudySourceEvidence> evidenceForQuestion(int questionId) => db
      .select(
        'SELECT e.* FROM study_question_evidence qe '
        'JOIN study_source_evidence e ON e.id=qe.evidence_id '
        'WHERE qe.question_id=? ORDER BY e.id',
        [questionId],
      )
      .map(_evidenceFromRow)
      .toList(growable: false);

  StudyQuestion _questionFromRow(Row row) {
    final questionId = row['id'] as int;
    final options = db
        .select(
          'SELECT id,question_id,ordinal,option_text,is_correct '
          'FROM study_question_options WHERE question_id=? ORDER BY ordinal',
          [questionId],
        )
        .map(
          (option) => StudyQuestionOption(
            id: option['id'] as int,
            questionId: option['question_id'] as int,
            ordinal: option['ordinal'] as int,
            text: option['option_text'] as String,
            isCorrect: (option['is_correct'] as int) == 1,
          ),
        )
        .toList(growable: false);
    final evidenceIds = db
        .select(
          'SELECT evidence_id FROM study_question_evidence '
          'WHERE question_id=? ORDER BY evidence_id',
          [questionId],
        )
        .map((value) => value['evidence_id'] as int)
        .toList(growable: false);
    return StudyQuestion(
      id: questionId,
      sermonId: row['sermon_id'] as int,
      packVersion: row['pack_version'] as int,
      sectionId: row['section_id'] as int?,
      type: _questionTypeFromName(row['type'] as String),
      category: _categoryFromName(row['category'] as String),
      difficulty: row['difficulty'] as int,
      prompt: row['prompt'] as String,
      pedagogicalExplanation:
          row['pedagogical_explanation'] as String,
      correctAnswerPayload: _decodeJsonPayload(
        row['correct_answer_payload'] as String?,
      ),
      scoringPayload: _decodeJsonPayload(
        row['scoring_payload'] as String?,
      ),
      validationStatus:
          _questionStatusFromName(row['validation_status'] as String),
      certificationEligible:
          (row['certification_eligible'] as int) == 1,
      options: options,
      evidenceIds: evidenceIds,
    );
  }

  SermonStudyPackSummary _packFromRow(Row row) => SermonStudyPackSummary(
        sermonId: row['sermon_id'] as int,
        sermonCode: row['sermon_code'] as String,
        title: row['title'] as String,
        packVersion: row['pack_version'] as int,
        packSchemaVersion: row['pack_schema_version'] as int,
        corpusVersion: row['corpus_version'] as String,
        corpusCanonicalSha256:
            row['corpus_canonical_sha256'] as String,
        primaryEditionId: row['primary_edition_id'] as String,
        biblePackVersion: row['bible_pack_version'] as String?,
        status: _packStatusFromName(row['status'] as String),
        sectionCount: row['section_count'] as int,
        questionCount: row['question_count'] as int,
        validatedQuestionCount: row['validated_question_count'] as int,
      );

  StudyParagraph _paragraphFromRow(Row row) => StudyParagraph(
        paragraphKey: row['paragraph_key'] as String,
        sermonId: row['sermon_id'] as int,
        editionId: row['edition_id'] as String,
        passageId: row['passage_id'] as int,
        globalOrdinal: row['global_ordinal'] as int,
        startOffset: row['start_offset'] as int,
        endOffset: row['end_offset'] as int,
        sourcePageStart: row['source_page_start'] as int,
        sourcePageEnd: row['source_page_end'] as int,
        textSha256: row['text_sha256'] as String,
        characterCount: row['character_count'] as int,
        printedParagraphNumber:
            row['printed_paragraph_number'] as String?,
      );

  StudySourceEvidence _evidenceFromRow(Row row) => StudySourceEvidence(
        id: row['id'] as int,
        sourceKind: row['source_kind'] as String,
        evidenceRole: row['evidence_role'] as String,
        sermonId: row['sermon_id'] as int?,
        editionId: row['edition_id'] as String?,
        passageId: row['passage_id'] as int?,
        paragraphKey: row['paragraph_key'] as String?,
        startOffset: row['start_offset'] as int?,
        endOffset: row['end_offset'] as int?,
        exactQuote: row['exact_quote'] as String?,
        quoteSha256: row['quote_sha256'] as String?,
        sourcePageStart: row['source_page_start'] as int?,
        sourcePageEnd: row['source_page_end'] as int?,
        translationId: row['translation_id'] as String?,
        normalizedReference: row['normalized_reference'] as String?,
        verseRange: row['verse_range'] as String?,
        exactBibleText: row['exact_bible_text'] as String?,
        bibleTextSha256: row['bible_text_sha256'] as String?,
      );

  StudyPackStatus _packStatusFromName(String value) => switch (value) {
        'draft' => StudyPackStatus.draft,
        'generated' => StudyPackStatus.generated,
        'needs_review' => StudyPackStatus.needsReview,
        'validated' => StudyPackStatus.validated,
        'published' => StudyPackStatus.published,
        'superseded' => StudyPackStatus.superseded,
        'rejected' => StudyPackStatus.rejected,
        _ => throw FormatException('Statut Study Pack inconnu: $value'),
      };

  Object? _decodeJsonPayload(String? raw) {
    if (raw == null || raw.trim().isEmpty) return null;
    try {
      return jsonDecode(raw);
    } on FormatException {
      throw FormatException('Payload JSON de question invalide.');
    }
  }

  StudyQuestionStatus _questionStatusFromName(String value) => switch (value) {
        'validated' => StudyQuestionStatus.validated,
        'needs_review' => StudyQuestionStatus.needsReview,
        'rejected' => StudyQuestionStatus.rejected,
        _ => throw FormatException('Statut question inconnu: $value'),
      };

  StudyQuestionType _questionTypeFromName(String value) => switch (value) {
        'single_choice' => StudyQuestionType.singleChoice,
        'multiple_choice' => StudyQuestionType.multipleChoice,
        'true_false_justified' =>
          StudyQuestionType.trueFalseJustified,
        'quote_to_context' => StudyQuestionType.quoteToContext,
        'quote_to_scripture' => StudyQuestionType.quoteToScripture,
        'reasoning_order' => StudyQuestionType.reasoningOrder,
        'fill_blank' => StudyQuestionType.fillBlank,
        'best_interpretation' => StudyQuestionType.bestInterpretation,
        'bad_interpretation' => StudyQuestionType.badInterpretation,
        'short_answer' => StudyQuestionType.shortAnswer,
        'case_study' => StudyQuestionType.caseStudy,
        'synthesis' => StudyQuestionType.synthesis,
        _ => throw FormatException('Type de question inconnu: $value'),
      };

  StudyQuestionCategory _categoryFromName(String value) => switch (value) {
        'comprehension' => StudyQuestionCategory.comprehension,
        'context' => StudyQuestionCategory.context,
        'reasoning' => StudyQuestionCategory.reasoning,
        'bible' => StudyQuestionCategory.bible,
        'doctrine' => StudyQuestionCategory.doctrine,
        'comparison' => StudyQuestionCategory.comparison,
        'case_analysis' => StudyQuestionCategory.caseAnalysis,
        _ => throw FormatException(
            'Catégorie de question inconnue: $value',
          ),
      };

  String _categoryName(StudyQuestionCategory value) => switch (value) {
        StudyQuestionCategory.comprehension => 'comprehension',
        StudyQuestionCategory.context => 'context',
        StudyQuestionCategory.reasoning => 'reasoning',
        StudyQuestionCategory.bible => 'bible',
        StudyQuestionCategory.doctrine => 'doctrine',
        StudyQuestionCategory.comparison => 'comparison',
        StudyQuestionCategory.caseAnalysis => 'case_analysis',
      };

  void close() => db.dispose();
}
