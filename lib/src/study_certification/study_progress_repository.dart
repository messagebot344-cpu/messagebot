import 'dart:convert';

import 'package:crypto/crypto.dart';

import '../personal/user_database.dart';
import 'study_exam_eligibility_engine.dart';
import 'study_exam_scoring_engine.dart';
import 'study_pack_models.dart';

class StudyProgressRepository {
  StudyProgressRepository(
    this.database, {
    int Function()? now,
  }) : _now = now ?? (() => DateTime.now().millisecondsSinceEpoch);

  final UserDatabase database;
  final int Function() _now;

  static const double minimumVisibleRatio = 0.60;

  int requiredVisibleMilliseconds(int characterCount) {
    final seconds = (characterCount / 35).ceil().clamp(2, 30).toInt();
    return seconds * 1000;
  }

  StudyProgressSnapshot ensureProgress({
    required int sermonId,
    required int packVersion,
  }) {
    final existing = progress(sermonId, packVersion);
    if (existing != null) return existing;
    final now = _now();
    database.db.execute(
      'INSERT INTO study_progress('
      'sermon_id,pack_version,status,reading_percent,active_study_seconds,'
      'started_at,last_studied_at,updated_at'
      ') VALUES(?,?,?,?,?,?,?,?)',
      [
        sermonId,
        packVersion,
        'in_progress',
        0.0,
        0,
        now,
        now,
        now,
      ],
    );
    return progress(sermonId, packVersion)!;
  }

  StudyProgressSnapshot? progress(int sermonId, int packVersion) {
    final rows = database.db.select(
      'SELECT sermon_id,pack_version,status,reading_percent,active_study_seconds,'
      'last_section_id,last_paragraph_key,last_passage_id,last_offset,'
      'started_at,last_studied_at,completed_at '
      'FROM study_progress WHERE sermon_id=? AND pack_version=? LIMIT 1',
      [sermonId, packVersion],
    );
    if (rows.isEmpty) return null;
    final row = rows.first;
    return StudyProgressSnapshot(
      sermonId: row['sermon_id'] as int,
      packVersion: row['pack_version'] as int,
      status: _statusFromName(row['status'] as String),
      readingPercent: (row['reading_percent'] as num).toDouble(),
      activeStudySeconds: row['active_study_seconds'] as int,
      lastSectionId: row['last_section_id'] as int?,
      lastParagraphKey: row['last_paragraph_key'] as String?,
      lastPassageId: row['last_passage_id'] as int?,
      lastOffset: row['last_offset'] as int?,
      startedAt: row['started_at'] as int,
      lastStudiedAt: row['last_studied_at'] as int,
      completedAt: row['completed_at'] as int?,
    );
  }

  double recordParagraphActivity({
    required int sermonId,
    required int packVersion,
    required StudyParagraph paragraph,
    required List<StudyParagraph> allParagraphs,
    required int visibleMilliseconds,
    required double visibleRatio,
    required bool appIsActive,
    required bool studyScreenIsActive,
  }) {
    final current = ensureProgress(
      sermonId: sermonId,
      packVersion: packVersion,
    );
    if (!appIsActive ||
        !studyScreenIsActive ||
        visibleMilliseconds <= 0 ||
        visibleRatio < minimumVisibleRatio) {
      return current.readingPercent;
    }

    final now = _now();
    final rows = database.db.select(
      'SELECT accumulated_visible_ms,state,first_seen_at '
      'FROM study_paragraph_progress '
      'WHERE sermon_id=? AND pack_version=? AND paragraph_key=? LIMIT 1',
      [sermonId, packVersion, paragraph.paragraphKey],
    );
    final previousMs =
        rows.isEmpty ? 0 : rows.first['accumulated_visible_ms'] as int;
    final nextMs = previousMs + visibleMilliseconds;
    final threshold = requiredVisibleMilliseconds(paragraph.characterCount);
    final nextState = nextMs >= threshold ? 'read' : 'seen';
    final firstSeen =
        rows.isEmpty ? now : rows.first['first_seen_at'] as int? ?? now;
    final wasRead = rows.isNotEmpty && rows.first['state'] == 'read';
    if (wasRead) {
      return current.readingPercent;
    }

    database.db.execute(
      'INSERT INTO study_paragraph_progress('
      'sermon_id,pack_version,paragraph_key,character_count,'
      'accumulated_visible_ms,state,first_seen_at,read_at,updated_at'
      ') VALUES(?,?,?,?,?,?,?,?,?) '
      'ON CONFLICT(sermon_id,pack_version,paragraph_key) DO UPDATE SET '
      'character_count=excluded.character_count,'
      'accumulated_visible_ms=excluded.accumulated_visible_ms,'
      'state=excluded.state,'
      'first_seen_at=COALESCE(study_paragraph_progress.first_seen_at,excluded.first_seen_at),'
      'read_at=COALESCE(study_paragraph_progress.read_at,excluded.read_at),'
      'updated_at=excluded.updated_at',
      [
        sermonId,
        packVersion,
        paragraph.paragraphKey,
        paragraph.characterCount,
        nextMs,
        nextState,
        firstSeen,
        nextState == 'read' && !wasRead ? now : null,
        now,
      ],
    );

    var nextReadingPercent = current.readingPercent;
    if (nextState == 'read') {
      final totalCharacters = allParagraphs.fold<int>(
        0,
        (sum, item) => sum + item.characterCount,
      );
      if (totalCharacters > 0) {
        nextReadingPercent = (
          current.readingPercent +
          paragraph.characterCount / totalCharacters
        ).clamp(0.0, 1.0).toDouble();
      }
    }

    database.db.execute(
      'UPDATE study_progress SET reading_percent=?,'
      'last_paragraph_key=?,last_passage_id=?,'
      'last_offset=?,last_studied_at=?,updated_at=? '
      'WHERE sermon_id=? AND pack_version=?',
      [
        nextReadingPercent,
        paragraph.paragraphKey,
        paragraph.passageId,
        paragraph.startOffset,
        now,
        now,
        sermonId,
        packVersion,
      ],
    );

    return nextReadingPercent;
  }

  double recalculateReadingPercent({
    required int sermonId,
    required int packVersion,
    required List<StudyParagraph> allParagraphs,
  }) {
    ensureProgress(sermonId: sermonId, packVersion: packVersion);
    if (allParagraphs.isEmpty) {
      database.db.execute(
        'UPDATE study_progress SET reading_percent=0,updated_at=? '
        'WHERE sermon_id=? AND pack_version=?',
        [_now(), sermonId, packVersion],
      );
      return 0;
    }

    final total = allParagraphs.fold<int>(
      0,
      (sum, paragraph) => sum + paragraph.characterCount,
    );
    if (total <= 0) return 0;

    final readKeys = database.db
        .select(
          "SELECT paragraph_key FROM study_paragraph_progress "
          "WHERE sermon_id=? AND pack_version=? AND state='read'",
          [sermonId, packVersion],
        )
        .map((row) => row['paragraph_key'] as String)
        .toSet();
    final readChars = allParagraphs
        .where((paragraph) => readKeys.contains(paragraph.paragraphKey))
        .fold<int>(
          0,
          (sum, paragraph) => sum + paragraph.characterCount,
        );
    final percent = (readChars / total).clamp(0.0, 1.0).toDouble();
    final now = _now();
    database.db.execute(
      'UPDATE study_progress SET reading_percent=?,last_studied_at=?,'
      'updated_at=? WHERE sermon_id=? AND pack_version=?',
      [percent, now, now, sermonId, packVersion],
    );
    return percent;
  }

  double readingPercentForParagraphs({
    required int sermonId,
    required int packVersion,
    required List<StudyParagraph> paragraphs,
  }) {
    if (paragraphs.isEmpty) return 0;
    final total = paragraphs.fold<int>(
      0,
      (sum, paragraph) => sum + paragraph.characterCount,
    );
    if (total <= 0) return 0;
    final keys = paragraphs.map((paragraph) => paragraph.paragraphKey).toList();
    final marks = List.filled(keys.length, '?').join(',');
    final rows = database.db.select(
      "SELECT paragraph_key FROM study_paragraph_progress "
      "WHERE sermon_id=? AND pack_version=? AND state='read' "
      "AND paragraph_key IN ($marks)",
      [sermonId, packVersion, ...keys],
    );
    final readKeys =
        rows.map((row) => row['paragraph_key'] as String).toSet();
    final readChars = paragraphs
        .where((paragraph) => readKeys.contains(paragraph.paragraphKey))
        .fold<int>(
          0,
          (sum, paragraph) => sum + paragraph.characterCount,
        );
    return (readChars / total).clamp(0.0, 1.0).toDouble();
  }


  void setResumePosition({
    required int sermonId,
    required int packVersion,
    int? sectionId,
    String? paragraphKey,
    int? passageId,
    int? offset,
  }) {
    ensureProgress(sermonId: sermonId, packVersion: packVersion);
    final now = _now();
    database.db.execute(
      'UPDATE study_progress SET last_section_id=?,last_paragraph_key=?,'
      'last_passage_id=?,last_offset=?,last_studied_at=?,updated_at=? '
      'WHERE sermon_id=? AND pack_version=?',
      [
        sectionId,
        paragraphKey,
        passageId,
        offset,
        now,
        now,
        sermonId,
        packVersion,
      ],
    );
  }

  void addActiveStudySeconds({
    required int sermonId,
    required int packVersion,
    required int seconds,
    required bool appIsActive,
    required bool studyScreenIsActive,
  }) {
    if (seconds <= 0 || !appIsActive || !studyScreenIsActive) return;
    ensureProgress(sermonId: sermonId, packVersion: packVersion);
    final now = _now();
    database.db.execute(
      'UPDATE study_progress SET '
      'active_study_seconds=active_study_seconds+?,'
      'last_studied_at=?,updated_at=? '
      'WHERE sermon_id=? AND pack_version=?',
      [seconds, now, now, sermonId, packVersion],
    );
  }

  void updateSectionProgress({
    required int sermonId,
    required int packVersion,
    required int sectionId,
    required StudySectionState state,
    required double readingPercent,
    double? checkpointScore,
  }) {
    ensureProgress(sermonId: sermonId, packVersion: packVersion);
    final now = _now();
    database.db.execute(
      'INSERT INTO study_section_progress('
      'sermon_id,pack_version,section_id,state,reading_percent,'
      'checkpoint_score,completed_at,updated_at'
      ') VALUES(?,?,?,?,?,?,?,?) '
      'ON CONFLICT(sermon_id,pack_version,section_id) DO UPDATE SET '
      'state=excluded.state,reading_percent=excluded.reading_percent,'
      'checkpoint_score=excluded.checkpoint_score,'
      'completed_at=COALESCE(study_section_progress.completed_at,excluded.completed_at),'
      'updated_at=excluded.updated_at',
      [
        sermonId,
        packVersion,
        sectionId,
        _sectionStateName(state),
        readingPercent.clamp(0.0, 1.0),
        checkpointScore,
        state == StudySectionState.completed ? now : null,
        now,
      ],
    );
  }

  int completedSectionCount(int sermonId, int packVersion) => database.db
      .select(
        "SELECT COUNT(*) AS n FROM study_section_progress "
        "WHERE sermon_id=? AND pack_version=? AND state='completed'",
        [sermonId, packVersion],
      )
      .first['n'] as int;

  Set<int> completedSectionIds(int sermonId, int packVersion) => database.db
      .select(
        "SELECT section_id FROM study_section_progress "
        "WHERE sermon_id=? AND pack_version=? AND state='completed'",
        [sermonId, packVersion],
      )
      .map((row) => row['section_id'] as int)
      .toSet();


  void setStatus({
    required int sermonId,
    required int packVersion,
    required StudyProgressStatus status,
  }) {
    ensureProgress(sermonId: sermonId, packVersion: packVersion);
    final now = _now();
    final marksCompletion =
        status == StudyProgressStatus.readingCompleted ||
        status == StudyProgressStatus.certified;
    database.db.execute(
      'UPDATE study_progress SET status=?,'
      'completed_at=CASE WHEN ?=1 THEN COALESCE(completed_at,?) '
      'ELSE completed_at END,updated_at=? '
      'WHERE sermon_id=? AND pack_version=?',
      [
        _statusName(status),
        marksCompletion ? 1 : 0,
        now,
        now,
        sermonId,
        packVersion,
      ],
    );
  }

  int recordQuestionAttempt({
    required int questionId,
    required int sermonId,
    required int packVersion,
    required String context,
    required Object answerPayload,
    required double score,
    int? attemptId,
  }) {
    final now = _now();
    database.db.execute(
      'INSERT INTO study_question_attempts('
      'question_id,sermon_id,pack_version,context,attempt_id,'
      'answer_payload,score,answered_at'
      ') VALUES(?,?,?,?,?,?,?,?)',
      [
        questionId,
        sermonId,
        packVersion,
        context,
        attemptId,
        jsonEncode(answerPayload),
        score.clamp(0.0, 1.0),
        now,
      ],
    );
    return database.db.lastInsertRowId;
  }

  int startExamAttempt({
    required SermonStudyPackSummary pack,
    required StudyExamRules rules,
    required List<StudySection> sections,
    required List<StudyQuestion> questionPool,
    required String seed,
    required List<int> questionIds,
    required Map<int, List<int>> optionOrderByQuestion,
  }) {
    if (pack.sermonId != rules.sermonId ||
        pack.packVersion != rules.packVersion) {
      throw StateError(
        'Le parcours et les règles d’examen ne correspondent pas.',
      );
    }
    final progressSnapshot = ensureProgress(
      sermonId: pack.sermonId,
      packVersion: pack.packVersion,
    );
    final eligibility = const StudyExamEligibilityEngine().evaluate(
      pack: pack,
      progress: progressSnapshot,
      rules: rules,
      sections: sections,
      completedSectionIds: completedSectionIds(
        pack.sermonId,
        pack.packVersion,
      ),
      questionPool: questionPool,
    );
    if (!eligibility.eligible) {
      throw StateError(
        'Examen non autorisé: ${eligibility.reasons.join(' ')}',
      );
    }
    if (questionIds.length != rules.examSize ||
        questionIds.toSet().length != questionIds.length) {
      throw StateError(
        'La sélection de questions ne correspond pas aux règles d’examen.',
      );
    }
    final eligibleIds = questionPool
        .where(
          (question) =>
              question.validationStatus == StudyQuestionStatus.validated &&
              question.certificationEligible,
        )
        .map((question) => question.id)
        .toSet();
    if (questionIds.any((id) => !eligibleIds.contains(id))) {
      throw StateError(
        'La tentative contient une question non validée pour la certification.',
      );
    }

    final selectedQuestions = <StudyQuestion>[];
    for (final id in questionIds) {
      final matches = questionPool.where((question) => question.id == id);
      if (matches.length != 1) {
        throw StateError('Question d’examen introuvable ou dupliquée: $id.');
      }
      selectedQuestions.add(matches.single);
    }

    for (final categoryRule in rules.categories) {
      final count = selectedQuestions
          .where((question) => question.category == categoryRule.category)
          .length;
      if (count != categoryRule.questionCount) {
        throw StateError(
          'La sélection ne respecte pas le quota '
          '${categoryRule.category.name}.',
        );
      }
    }

    for (final question in selectedQuestions) {
      final suppliedOrder =
          optionOrderByQuestion[question.id] ?? const <int>[];
      final optionIds = question.options.map((option) => option.id).toSet();
      if (suppliedOrder.length != optionIds.length ||
          suppliedOrder.toSet().length != suppliedOrder.length ||
          !suppliedOrder.toSet().containsAll(optionIds)) {
        throw StateError(
          'Ordre d’options invalide pour la question ${question.id}.',
        );
      }
    }

    final previous = database.db.select(
      'SELECT COALESCE(MAX(attempt_number),0) AS n '
      'FROM study_exam_attempts WHERE sermon_id=? AND pack_version=?',
      [pack.sermonId, pack.packVersion],
    ).first['n'] as int;
    final now = _now();

    database.db.execute('BEGIN IMMEDIATE');
    try {
      database.db.execute(
        'INSERT INTO study_exam_attempts('
        'sermon_id,pack_version,seed,started_at,attempt_number'
        ') VALUES(?,?,?,?,?)',
        [
          pack.sermonId,
          pack.packVersion,
          seed,
          now,
          previous + 1,
        ],
      );
      final attemptId = database.db.lastInsertRowId;
      for (var index = 0; index < questionIds.length; index++) {
        final questionId = questionIds[index];
        database.db.execute(
          'INSERT INTO study_exam_items('
          'attempt_id,question_id,display_order,option_order_json'
          ') VALUES(?,?,?,?)',
          [
            attemptId,
            questionId,
            index,
            jsonEncode(optionOrderByQuestion[questionId] ?? const <int>[]),
          ],
        );
      }
      database.db.execute('COMMIT');
      return attemptId;
    } catch (_) {
      database.db.execute('ROLLBACK');
      rethrow;
    }
  }

  StudyExamEvaluation submitExamAttempt({
    required int attemptId,
    required StudyExamRules rules,
    required List<StudyQuestion> questions,
    required Map<int, double> scoresByQuestion,
  }) {
    final attemptRows = database.db.select(
      'SELECT sermon_id,pack_version,submitted_at FROM study_exam_attempts '
      'WHERE attempt_id=? LIMIT 1',
      [attemptId],
    );
    if (attemptRows.isEmpty) {
      throw StateError('Tentative d’examen introuvable.');
    }
    final attempt = attemptRows.first;
    if (attempt['submitted_at'] != null) {
      throw StateError('Cette tentative d’examen a déjà été soumise.');
    }
    if (attempt['sermon_id'] != rules.sermonId ||
        attempt['pack_version'] != rules.packVersion) {
      throw StateError(
        'Les règles d’examen ne correspondent pas à la tentative.',
      );
    }

    final expectedIds = database.db
        .select(
          'SELECT question_id FROM study_exam_items '
          'WHERE attempt_id=? ORDER BY display_order',
          [attemptId],
        )
        .map((row) => row['question_id'] as int)
        .toList(growable: false);
    final suppliedIds = questions.map((question) => question.id).toSet();
    if (expectedIds.length != suppliedIds.length ||
        expectedIds.any((id) => !suppliedIds.contains(id)) ||
        expectedIds.any((id) => !scoresByQuestion.containsKey(id))) {
      throw StateError(
        'Les réponses notées ne correspondent pas aux questions de la tentative.',
      );
    }

    final evaluation = const StudyExamScoringEngine().evaluate(
      rules: rules,
      questions: questions,
      scoresByQuestion: scoresByQuestion,
    );
    database.db.execute(
      'UPDATE study_exam_attempts SET submitted_at=?,overall_score=?,'
      'category_scores_json=?,passed=? WHERE attempt_id=?',
      [
        _now(),
        evaluation.overallScore,
        jsonEncode(evaluation.categoryScores),
        evaluation.passed ? 1 : 0,
        attemptId,
      ],
    );
    setStatus(
      sermonId: rules.sermonId,
      packVersion: rules.packVersion,
      status: evaluation.passed
          ? StudyProgressStatus.examAvailable
          : StudyProgressStatus.examFailed,
    );
    return evaluation;
  }

  int examAttemptCount({
    required int sermonId,
    required int packVersion,
  }) =>
      database.db
          .select(
            'SELECT COUNT(*) AS n FROM study_exam_attempts '
            'WHERE sermon_id=? AND pack_version=? AND submitted_at IS NOT NULL',
            [sermonId, packVersion],
          )
          .first['n'] as int;

  List<int> recentExamQuestionIds({
    required int sermonId,
    required int packVersion,
    int attemptLimit = 2,
  }) {
    if (attemptLimit <= 0) return const [];
    final rows = database.db.select(
      'SELECT attempt_id FROM study_exam_attempts '
      'WHERE sermon_id=? AND pack_version=? AND submitted_at IS NOT NULL '
      'ORDER BY attempt_number DESC LIMIT ?',
      [sermonId, packVersion, attemptLimit],
    );
    final attemptIds =
        rows.map((row) => row['attempt_id'] as int).toList(growable: false);
    if (attemptIds.isEmpty) return const [];
    final marks = List.filled(attemptIds.length, '?').join(',');
    return database.db
        .select(
          'SELECT DISTINCT question_id FROM study_exam_items '
          'WHERE attempt_id IN ($marks) ORDER BY question_id',
          attemptIds,
        )
        .map((row) => row['question_id'] as int)
        .toList(growable: false);
  }

  StudyCertification createCertification({
    required int attemptId,
    required SermonStudyPackSummary pack,
    required String level,
    required StudyExamRules rules,
    required List<StudySection> sections,
    required List<StudyQuestion> questionPool,
  }) {
    if (rules.sermonId != pack.sermonId ||
        rules.packVersion != pack.packVersion) {
      throw StateError(
        'Les règles d’examen ne correspondent pas au parcours certifié.',
      );
    }

    final progressSnapshot = ensureProgress(
      sermonId: pack.sermonId,
      packVersion: pack.packVersion,
    );
    final eligibility = const StudyExamEligibilityEngine().evaluate(
      pack: pack,
      progress: progressSnapshot,
      rules: rules,
      sections: sections,
      completedSectionIds: completedSectionIds(
        pack.sermonId,
        pack.packVersion,
      ),
      questionPool: questionPool,
    );
    if (!eligibility.eligible) {
      throw StateError(
        'Certification non autorisée: ${eligibility.reasons.join(' ')}',
      );
    }

    final attemptRows = database.db.select(
      'SELECT overall_score,category_scores_json,passed '
      'FROM study_exam_attempts WHERE attempt_id=? AND sermon_id=? '
      'AND pack_version=? AND submitted_at IS NOT NULL LIMIT 1',
      [attemptId, pack.sermonId, pack.packVersion],
    );
    if (attemptRows.isEmpty || attemptRows.first['passed'] != 1) {
      throw StateError(
        'Une certification exige une tentative d’examen réussie.',
      );
    }

    final score = (attemptRows.first['overall_score'] as num).toDouble();
    final categoryScoresJson =
        attemptRows.first['category_scores_json'] as String? ?? '{}';
    final decoded = jsonDecode(categoryScoresJson);
    if (decoded is! Map<String, dynamic>) {
      throw StateError('Scores de catégories invalides.');
    }
    final categoryScores = <String, double>{
      for (final entry in decoded.entries)
        entry.key: (entry.value as num).toDouble(),
    };

    if (score < rules.passThreshold) {
      throw StateError(
        'Le score global est inférieur au seuil de certification.',
      );
    }
    for (final rule in rules.categories) {
      final minimum = rule.minimumScore;
      if (minimum == null) continue;
      final actual = categoryScores[_categoryName(rule.category)];
      if (actual == null || actual < minimum) {
        throw StateError(
          'Une catégorie obligatoire est sous son seuil de certification.',
        );
      }
    }

    final certifiedAt = _now();
    final integritySource = [
      pack.sermonId,
      pack.packVersion,
      pack.corpusVersion,
      pack.corpusCanonicalSha256,
      score.toStringAsFixed(6),
      categoryScoresJson,
      progressSnapshot.readingPercent.toStringAsFixed(6),
      progressSnapshot.activeStudySeconds,
      attemptId,
      certifiedAt,
      level,
    ].join('|');
    final integrityHash =
        sha256.convert(utf8.encode(integritySource)).toString();
    final certificationId =
        'GRN-${pack.sermonId}-${pack.packVersion}-${integrityHash.substring(0, 12).toUpperCase()}';

    database.db.execute(
      'INSERT INTO study_certifications('
      'certification_id,sermon_id,pack_version,corpus_version,score,'
      'category_scores_json,study_seconds,attempt_id,certified_at,level,'
      'integrity_hash'
      ') VALUES(?,?,?,?,?,?,?,?,?,?,?)',
      [
        certificationId,
        pack.sermonId,
        pack.packVersion,
        pack.corpusVersion,
        score,
        categoryScoresJson,
        progressSnapshot.activeStudySeconds,
        attemptId,
        certifiedAt,
        level,
        integrityHash,
      ],
    );
    setStatus(
      sermonId: pack.sermonId,
      packVersion: pack.packVersion,
      status: StudyProgressStatus.certified,
    );
    return certificationById(certificationId)!;
  }


  StudyCertification? certificationById(String certificationId) {
    final rows = database.db.select(
      'SELECT certification_id,sermon_id,pack_version,corpus_version,'
      'score,category_scores_json,study_seconds,attempt_id,certified_at,level,integrity_hash '
      'FROM study_certifications WHERE certification_id=? LIMIT 1',
      [certificationId],
    );
    if (rows.isEmpty) return null;
    final row = rows.first;
    return StudyCertification(
      certificationId: row['certification_id'] as String,
      sermonId: row['sermon_id'] as int,
      packVersion: row['pack_version'] as int,
      corpusVersion: row['corpus_version'] as String,
      score: (row['score'] as num).toDouble(),
      categoryScores: _decodeCategoryScores(
        row['category_scores_json'] as String,
      ),
      studySeconds: row['study_seconds'] as int,
      attemptId: row['attempt_id'] as int,
      certifiedAt: row['certified_at'] as int,
      level: row['level'] as String,
      integrityHash: row['integrity_hash'] as String,
    );
  }

  List<StudyCertification> certifications() => database.db
      .select(
        'SELECT certification_id,sermon_id,pack_version,corpus_version,'
        'score,category_scores_json,study_seconds,attempt_id,certified_at,level,integrity_hash '
        'FROM study_certifications ORDER BY certified_at DESC',
      )
      .map(
        (row) => StudyCertification(
          certificationId: row['certification_id'] as String,
          sermonId: row['sermon_id'] as int,
          packVersion: row['pack_version'] as int,
          corpusVersion: row['corpus_version'] as String,
          score: (row['score'] as num).toDouble(),
          categoryScores: _decodeCategoryScores(
            row['category_scores_json'] as String,
          ),
          studySeconds: row['study_seconds'] as int,
          attemptId: row['attempt_id'] as int,
          certifiedAt: row['certified_at'] as int,
          level: row['level'] as String,
          integrityHash: row['integrity_hash'] as String,
        ),
      )
      .toList(growable: false);

  Map<String, double> _decodeCategoryScores(String value) {
    final decoded = jsonDecode(value);
    if (decoded is! Map<String, dynamic>) {
      throw const FormatException('Scores de catégories invalides.');
    }
    return Map.unmodifiable({
      for (final entry in decoded.entries)
        entry.key: (entry.value as num).toDouble(),
    });
  }

  String _categoryName(StudyQuestionCategory value) => switch (value) {
        StudyQuestionCategory.comprehension => 'comprehension',
        StudyQuestionCategory.context => 'context',
        StudyQuestionCategory.reasoning => 'reasoning',
        StudyQuestionCategory.bible => 'bible',
        StudyQuestionCategory.doctrine => 'doctrine',
        StudyQuestionCategory.comparison => 'comparison',
        StudyQuestionCategory.caseAnalysis => 'case_analysis',
      };

  StudyProgressStatus _statusFromName(String value) => switch (value) {
        'not_started' => StudyProgressStatus.notStarted,
        'in_progress' => StudyProgressStatus.inProgress,
        'reading_completed' => StudyProgressStatus.readingCompleted,
        'review_required' => StudyProgressStatus.reviewRequired,
        'exam_available' => StudyProgressStatus.examAvailable,
        'exam_failed' => StudyProgressStatus.examFailed,
        'certified' => StudyProgressStatus.certified,
        _ => throw FormatException('Statut d’étude inconnu: $value'),
      };

  String _statusName(StudyProgressStatus value) => switch (value) {
        StudyProgressStatus.notStarted => 'not_started',
        StudyProgressStatus.inProgress => 'in_progress',
        StudyProgressStatus.readingCompleted => 'reading_completed',
        StudyProgressStatus.reviewRequired => 'review_required',
        StudyProgressStatus.examAvailable => 'exam_available',
        StudyProgressStatus.examFailed => 'exam_failed',
        StudyProgressStatus.certified => 'certified',
      };

  String _sectionStateName(StudySectionState value) => switch (value) {
        StudySectionState.locked => 'locked',
        StudySectionState.available => 'available',
        StudySectionState.inProgress => 'in_progress',
        StudySectionState.completed => 'completed',
        StudySectionState.needsReview => 'needs_review',
      };
}
