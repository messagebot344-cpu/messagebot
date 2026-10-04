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

  test('certification impossible après échec et créée après réussite', () {
    var now = 9000000;
    final dir = Directory.systemTemp.createTempSync('grenier-certification-');
    final db = UserDatabase.openPath('${dir.path}/user.db');
    final repository = StudyProgressRepository(db, now: () => now);

    repository.addActiveStudySeconds(
      sermonId: 12,
      packVersion: 1,
      seconds: 7200,
      appIsActive: true,
      studyScreenIsActive: true,
    );

    final failed = repository.startExamAttempt(
      sermonId: 12,
      packVersion: 1,
      seed: 'failed-seed',
      questionIds: const [1, 2],
      optionOrderByQuestion: const {
        1: [11, 12],
        2: [21, 22],
      },
    );
    repository.submitExamAttempt(
      attemptId: failed,
      overallScore: 0.70,
      categoryScores: const {'comprehension': 0.7},
      passed: false,
    );
    expect(
      () => repository.createCertification(
        attemptId: failed,
        sermonId: 12,
        packVersion: 1,
        corpusVersion: 'corpus-v4',
        level: 'Certification',
      ),
      throwsStateError,
    );

    now += 1000;
    final passed = repository.startExamAttempt(
      sermonId: 12,
      packVersion: 1,
      seed: 'passed-seed',
      questionIds: const [3, 4],
      optionOrderByQuestion: const {
        3: [31, 32],
        4: [41, 42],
      },
    );
    repository.submitExamAttempt(
      attemptId: passed,
      overallScore: 0.92,
      categoryScores: const {
        'comprehension': 0.90,
        'context': 0.94,
      },
      passed: true,
    );
    final certification = repository.createCertification(
      attemptId: passed,
      sermonId: 12,
      packVersion: 1,
      corpusVersion: 'corpus-v4',
      level: 'Certification',
    );
    expect(certification.certificationId, startsWith('GRN-12-1-'));
    expect(certification.score, closeTo(0.92, 0.0001));
    expect(certification.studySeconds, 7200);
    expect(repository.progress(12, 1)!.status, StudyProgressStatus.certified);

    db.close();
    dir.deleteSync(recursive: true);
  });
}
