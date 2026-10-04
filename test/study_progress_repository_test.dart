import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:le_grenier_du_message/src/personal/user_database.dart';
import 'package:le_grenier_du_message/src/study_certification/study_pack_models.dart';
import 'package:le_grenier_du_message/src/study_certification/study_progress_repository.dart';

StudyParagraph paragraph(String key, int ordinal, int chars) => StudyParagraph(
      paragraphKey: key,
      sermonId: 1,
      editionId: 'e1',
      passageId: 100 + ordinal,
      globalOrdinal: ordinal,
      startOffset: 0,
      endOffset: chars,
      sourcePageStart: ordinal + 1,
      sourcePageEnd: ordinal + 1,
      textSha256: 'sha-$key',
      characterCount: chars,
    );

void main() {
  test('progression pondère les paragraphes par caractères réellement lus', () {
    var now = 1000000;
    final dir = Directory.systemTemp.createTempSync('grenier-study-progress-');
    final db = UserDatabase.openPath('${dir.path}/user.db');
    final repository = StudyProgressRepository(db, now: () => now);

    final p1 = paragraph('p1', 0, 100);
    final p2 = paragraph('p2', 1, 300);
    final all = [p1, p2];

    expect(
      repository.recordParagraphActivity(
        sermonId: 1,
        packVersion: 1,
        paragraph: p1,
        allParagraphs: all,
        visibleMilliseconds: 10000,
        visibleRatio: 0.40,
        appIsActive: true,
        studyScreenIsActive: true,
      ),
      0,
    );

    now += 1000;
    final p1Percent = repository.recordParagraphActivity(
      sermonId: 1,
      packVersion: 1,
      paragraph: p1,
      allParagraphs: all,
      visibleMilliseconds: repository.requiredVisibleMilliseconds(100),
      visibleRatio: 0.90,
      appIsActive: true,
      studyScreenIsActive: true,
    );
    expect(p1Percent, closeTo(0.25, 0.0001));

    now += 1000;
    final threshold = repository.requiredVisibleMilliseconds(300);
    repository.recordParagraphActivity(
      sermonId: 1,
      packVersion: 1,
      paragraph: p2,
      allParagraphs: all,
      visibleMilliseconds: threshold ~/ 2,
      visibleRatio: 0.80,
      appIsActive: true,
      studyScreenIsActive: true,
    );
    expect(repository.progress(1, 1)!.readingPercent, closeTo(0.25, 0.0001));

    now += 1000;
    final finalPercent = repository.recordParagraphActivity(
      sermonId: 1,
      packVersion: 1,
      paragraph: p2,
      allParagraphs: all,
      visibleMilliseconds: threshold,
      visibleRatio: 0.80,
      appIsActive: true,
      studyScreenIsActive: true,
    );
    expect(finalPercent, 1);

    db.close();
    dir.deleteSync(recursive: true);
  });

  test('un paragraphe déjà lu n est pas réécrit à chaque tick', () {
    var now = 3000000;
    final dir = Directory.systemTemp.createTempSync('grenier-study-stable-');
    final db = UserDatabase.openPath('${dir.path}/user.db');
    final repository = StudyProgressRepository(db, now: () => now);
    final p = paragraph('stable-p', 0, 120);

    repository.recordParagraphActivity(
      sermonId: 1,
      packVersion: 1,
      paragraph: p,
      allParagraphs: [p],
      visibleMilliseconds: repository.requiredVisibleMilliseconds(120),
      visibleRatio: 1,
      appIsActive: true,
      studyScreenIsActive: true,
    );
    final before = db.db
        .select(
          'SELECT accumulated_visible_ms,updated_at '
          'FROM study_paragraph_progress '
          'WHERE sermon_id=1 AND pack_version=1 AND paragraph_key=?',
          [p.paragraphKey],
        )
        .first;

    now += 5000;
    final percent = repository.recordParagraphActivity(
      sermonId: 1,
      packVersion: 1,
      paragraph: p,
      allParagraphs: [p],
      visibleMilliseconds: 5000,
      visibleRatio: 1,
      appIsActive: true,
      studyScreenIsActive: true,
    );
    final after = db.db
        .select(
          'SELECT accumulated_visible_ms,updated_at '
          'FROM study_paragraph_progress '
          'WHERE sermon_id=1 AND pack_version=1 AND paragraph_key=?',
          [p.paragraphKey],
        )
        .first;

    expect(percent, 1);
    expect(after['accumulated_visible_ms'], before['accumulated_visible_ms']);
    expect(after['updated_at'], before['updated_at']);

    db.close();
    dir.deleteSync(recursive: true);
  });

  test('heartbeat regroupe temps actif et position de reprise', () {
    var now = 4000000;
    final dir = Directory.systemTemp.createTempSync('grenier-study-heartbeat-');
    final db = UserDatabase.openPath('${dir.path}/user.db');
    final repository = StudyProgressRepository(db, now: () => now);

    repository.ensureProgress(sermonId: 9, packVersion: 3);
    now += 2000;
    repository.recordStudyHeartbeat(
      sermonId: 9,
      packVersion: 3,
      seconds: 2,
      paragraphKey: 'heartbeat-p',
      passageId: 909,
      offset: 44,
      appIsActive: true,
      studyScreenIsActive: true,
    );

    final snapshot = repository.progress(9, 3)!;
    expect(snapshot.activeStudySeconds, 2);
    expect(snapshot.lastParagraphKey, 'heartbeat-p');
    expect(snapshot.lastPassageId, 909);
    expect(snapshot.lastOffset, 44);

    db.close();
    dir.deleteSync(recursive: true);
  });

  test('reprise et temps actif persistent après fermeture', () {
    var now = 5000000;
    final dir = Directory.systemTemp.createTempSync('grenier-study-resume-');
    final path = '${dir.path}/user.db';
    final db = UserDatabase.openPath(path);
    final repository = StudyProgressRepository(db, now: () => now);

    repository.setResumePosition(
      sermonId: 7,
      packVersion: 2,
      sectionId: 33,
      paragraphKey: 'paragraph-x',
      passageId: 445,
      offset: 78,
    );
    repository.addActiveStudySeconds(
      sermonId: 7,
      packVersion: 2,
      seconds: 90,
      appIsActive: true,
      studyScreenIsActive: true,
    );
    repository.addActiveStudySeconds(
      sermonId: 7,
      packVersion: 2,
      seconds: 90,
      appIsActive: false,
      studyScreenIsActive: true,
    );
    db.close();

    final reopened = UserDatabase.openPath(path);
    final again = StudyProgressRepository(reopened, now: () => now);
    final snapshot = again.progress(7, 2)!;
    expect(snapshot.lastSectionId, 33);
    expect(snapshot.lastParagraphKey, 'paragraph-x');
    expect(snapshot.lastPassageId, 445);
    expect(snapshot.lastOffset, 78);
    expect(snapshot.activeStudySeconds, 90);

    reopened.close();
    dir.deleteSync(recursive: true);
  });

  test('examen et certification imposent étude réelle et notation liée à la tentative', () {
    var now = 9000000;
    final dir = Directory.systemTemp.createTempSync('grenier-certification-');
    final db = UserDatabase.openPath('${dir.path}/user.db');
    final repository = StudyProgressRepository(db, now: () => now);

    const pack = SermonStudyPackSummary(
      sermonId: 12,
      sermonCode: '65-0001',
      title: 'Prédication certifiante',
      packVersion: 1,
      packSchemaVersion: 1,
      corpusVersion: 'corpus-v4',
      corpusCanonicalSha256: 'canonical-sha',
      primaryEditionId: 'e1',
      status: StudyPackStatus.published,
      sectionCount: 1,
      questionCount: 6,
      validatedQuestionCount: 6,
    );
    const certificationRules = StudyExamRules(
      sermonId: 12,
      packVersion: 1,
      examSize: 2,
      passThreshold: 0.85,
      recentQuestionExclusionCount: 2,
      minimumReadingPercent: 0.95,
      minimumBankMultiplier: 2.4,
      categories: [
        StudyExamCategoryRule(
          category: StudyQuestionCategory.comprehension,
          weight: 0.5,
          questionCount: 1,
          minimumScore: 0.80,
        ),
        StudyExamCategoryRule(
          category: StudyQuestionCategory.context,
          weight: 0.5,
          questionCount: 1,
          minimumScore: 0.80,
        ),
      ],
    );
    const sections = [
      StudySection(
        id: 70,
        sermonId: 12,
        packVersion: 1,
        ordinal: 0,
        title: 'Étude intégrale',
        kind: 'theme',
        requiredForExam: true,
        minimumReadingPercent: 0.95,
        paragraphKeys: ['cert-p'],
      ),
    ];
    final pool = <StudyQuestion>[
      for (var id = 1; id <= 3; id++)
        StudyQuestion(
          id: id,
          sermonId: 12,
          packVersion: 1,
          type: StudyQuestionType.singleChoice,
          category: StudyQuestionCategory.comprehension,
          difficulty: 4,
          prompt: 'Compréhension $id',
          pedagogicalExplanation: '',
          validationStatus: StudyQuestionStatus.validated,
          certificationEligible: true,
          options: const [],
          evidenceIds: [id],
        ),
      for (var id = 4; id <= 6; id++)
        StudyQuestion(
          id: id,
          sermonId: 12,
          packVersion: 1,
          type: StudyQuestionType.singleChoice,
          category: StudyQuestionCategory.context,
          difficulty: 4,
          prompt: 'Contexte $id',
          pedagogicalExplanation: '',
          validationStatus: StudyQuestionStatus.validated,
          certificationEligible: true,
          options: const [],
          evidenceIds: [id],
        ),
    ];

    expect(
      () => repository.startExamAttempt(
        pack: pack,
        rules: certificationRules,
        sections: sections,
        questionPool: pool,
        seed: 'blocked-seed',
        questionIds: const [1, 4],
        optionOrderByQuestion: const {
          1: <int>[],
          4: <int>[],
        },
      ),
      throwsStateError,
    );

    final certParagraph = paragraph('cert-p', 0, 200);
    repository.recordParagraphActivity(
      sermonId: 12,
      packVersion: 1,
      paragraph: certParagraph,
      allParagraphs: [certParagraph],
      visibleMilliseconds:
          repository.requiredVisibleMilliseconds(certParagraph.characterCount),
      visibleRatio: 1,
      appIsActive: true,
      studyScreenIsActive: true,
    );
    repository.updateSectionProgress(
      sermonId: 12,
      packVersion: 1,
      sectionId: 70,
      state: StudySectionState.completed,
      readingPercent: 1,
      checkpointScore: 1,
    );
    repository.addActiveStudySeconds(
      sermonId: 12,
      packVersion: 1,
      seconds: 7200,
      appIsActive: true,
      studyScreenIsActive: true,
    );

    final failed = repository.startExamAttempt(
      pack: pack,
      rules: certificationRules,
      sections: sections,
      questionPool: pool,
      seed: 'failed-seed',
      questionIds: const [1, 4],
      optionOrderByQuestion: const {
        1: <int>[],
        4: <int>[],
      },
    );
    final failedEvaluation = repository.submitExamAttempt(
      attemptId: failed,
      rules: certificationRules,
      questions: [pool[0], pool[3]],
      scoresByQuestion: const {1: 0.70, 4: 0.70},
    );
    expect(failedEvaluation.passed, isFalse);
    expect(
      () => repository.createCertification(
        attemptId: failed,
        pack: pack,
        level: 'Certification',
        rules: certificationRules,
        sections: sections,
        questionPool: pool,
      ),
      throwsStateError,
    );

    final boundAttempt = repository.startExamAttempt(
      pack: pack,
      rules: certificationRules,
      sections: sections,
      questionPool: pool,
      seed: 'bound-seed',
      questionIds: const [2, 5],
      optionOrderByQuestion: const {
        2: <int>[],
        5: <int>[],
      },
    );
    expect(
      () => repository.submitExamAttempt(
        attemptId: boundAttempt,
        rules: certificationRules,
        questions: [pool[2], pool[5]],
        scoresByQuestion: const {3: 1.0, 6: 1.0},
      ),
      throwsStateError,
    );

    now += 1000;
    final passed = repository.startExamAttempt(
      pack: pack,
      rules: certificationRules,
      sections: sections,
      questionPool: pool,
      seed: 'passed-seed',
      questionIds: const [3, 6],
      optionOrderByQuestion: const {
        3: <int>[],
        6: <int>[],
      },
    );
    final evaluation = repository.submitExamAttempt(
      attemptId: passed,
      rules: certificationRules,
      questions: [pool[2], pool[5]],
      scoresByQuestion: const {3: 0.90, 6: 0.94},
    );
    expect(evaluation.passed, isTrue);
    expect(evaluation.overallScore, closeTo(0.92, 0.0001));

    final certification = repository.createCertification(
      attemptId: passed,
      pack: pack,
      level: 'Certification',
      rules: certificationRules,
      sections: sections,
      questionPool: pool,
    );
    expect(certification.certificationId, startsWith('GRN-12-1-'));
    expect(certification.score, closeTo(0.92, 0.0001));
    expect(certification.categoryScores['context'], closeTo(0.94, 0.0001));
    expect(certification.studySeconds, 7200);
    expect(repository.progress(12, 1)!.status, StudyProgressStatus.certified);

    db.close();
    dir.deleteSync(recursive: true);
  });

}
