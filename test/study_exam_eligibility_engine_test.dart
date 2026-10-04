import 'package:flutter_test/flutter_test.dart';
import 'package:le_grenier_du_message/src/study_certification/study_exam_eligibility_engine.dart';
import 'package:le_grenier_du_message/src/study_certification/study_pack_models.dart';

StudyQuestion eligibleQuestion(int id, StudyQuestionCategory category) =>
    StudyQuestion(
      id: id,
      sermonId: 1,
      packVersion: 1,
      type: StudyQuestionType.singleChoice,
      category: category,
      difficulty: 4,
      prompt: 'Question $id',
      pedagogicalExplanation: '',
      validationStatus: StudyQuestionStatus.validated,
      certificationEligible: true,
      options: const [],
      evidenceIds: [id],
    );

void main() {
  const pack = SermonStudyPackSummary(
    sermonId: 1,
    sermonCode: '47-0412',
    title: 'La Foi Est l’Assurance',
    packVersion: 1,
    packSchemaVersion: 1,
    corpusVersion: 'v4',
    corpusCanonicalSha256: 'sha',
    primaryEditionId: 'e1',
    status: StudyPackStatus.published,
    sectionCount: 2,
    questionCount: 12,
    validatedQuestionCount: 12,
  );
  const progress = StudyProgressSnapshot(
    sermonId: 1,
    packVersion: 1,
    status: StudyProgressStatus.readingCompleted,
    readingPercent: 0.97,
    activeStudySeconds: 3600,
    startedAt: 1,
    lastStudiedAt: 2,
  );
  const rules = StudyExamRules(
    sermonId: 1,
    packVersion: 1,
    examSize: 4,
    passThreshold: 0.85,
    recentQuestionExclusionCount: 2,
    minimumReadingPercent: 0.95,
    minimumBankMultiplier: 2.4,
    categories: [
      StudyExamCategoryRule(
        category: StudyQuestionCategory.comprehension,
        weight: 0.5,
        questionCount: 2,
      ),
      StudyExamCategoryRule(
        category: StudyQuestionCategory.context,
        weight: 0.5,
        questionCount: 2,
      ),
    ],
  );
  const sections = [
    StudySection(
      id: 10,
      sermonId: 1,
      packVersion: 1,
      ordinal: 0,
      title: 'Introduction',
      kind: 'introduction',
      requiredForExam: true,
      minimumReadingPercent: 0.9,
      paragraphKeys: ['a'],
    ),
    StudySection(
      id: 11,
      sermonId: 1,
      packVersion: 1,
      ordinal: 1,
      title: 'Développement',
      kind: 'theme',
      requiredForExam: true,
      minimumReadingPercent: 0.9,
      paragraphKeys: ['b'],
    ),
  ];

  test('examen reste bloqué si la banque robuste est insuffisante', () {
    const engine = StudyExamEligibilityEngine();
    final result = engine.evaluate(
      pack: pack,
      progress: progress,
      rules: rules,
      sections: sections,
      completedSectionIds: const {10, 11},
      questionPool: [
        eligibleQuestion(1, StudyQuestionCategory.comprehension),
        eligibleQuestion(2, StudyQuestionCategory.comprehension),
        eligibleQuestion(101, StudyQuestionCategory.context),
        eligibleQuestion(102, StudyQuestionCategory.context),
      ],
    );

    expect(result.eligible, isFalse);
    expect(
      result.reasons.any((reason) => reason.contains('banque')),
      isTrue,
    );
  });

  test('examen se débloque seulement avec lecture, sections et banque suffisantes', () {
    const engine = StudyExamEligibilityEngine();
    final pool = [
      for (var id = 1; id <= 5; id++)
        eligibleQuestion(id, StudyQuestionCategory.comprehension),
      for (var id = 101; id <= 105; id++)
        eligibleQuestion(id, StudyQuestionCategory.context),
    ];
    final result = engine.evaluate(
      pack: pack,
      progress: progress,
      rules: rules,
      sections: sections,
      completedSectionIds: const {10, 11},
      questionPool: pool,
    );

    expect(rules.minimumQuestionBankSize, 10);
    expect(result.eligible, isTrue);
    expect(result.reasons, isEmpty);
  });
}
