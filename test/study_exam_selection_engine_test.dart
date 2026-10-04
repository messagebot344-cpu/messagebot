import 'package:flutter_test/flutter_test.dart';
import 'package:le_grenier_du_message/src/study_certification/study_exam_selection_engine.dart';
import 'package:le_grenier_du_message/src/study_certification/study_pack_models.dart';

StudyQuestion question(int id, StudyQuestionCategory category) => StudyQuestion(
      id: id,
      sermonId: 1,
      packVersion: 1,
      type: StudyQuestionType.singleChoice,
      category: category,
      difficulty: 4,
      prompt: 'Question $id',
      pedagogicalExplanation: 'Explication pédagogique.',
      validationStatus: StudyQuestionStatus.validated,
      certificationEligible: true,
      options: [
        StudyQuestionOption(
          id: id * 10 + 1,
          questionId: id,
          ordinal: 0,
          text: 'A',
          isCorrect: true,
        ),
        StudyQuestionOption(
          id: id * 10 + 2,
          questionId: id,
          ordinal: 1,
          text: 'B',
          isCorrect: false,
        ),
        StudyQuestionOption(
          id: id * 10 + 3,
          questionId: id,
          ordinal: 2,
          text: 'C',
          isCorrect: false,
        ),
      ],
      evidenceIds: [id],
    );

void main() {
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

  final pool = [
    for (var id = 1; id <= 8; id++)
      question(id, StudyQuestionCategory.comprehension),
    for (var id = 101; id <= 108; id++)
      question(id, StudyQuestionCategory.context),
  ];

  test('même seed produit exactement le même examen', () {
    const engine = StudyExamSelectionEngine();
    final first = engine.select(
      rules: rules,
      pool: pool,
      recentQuestionIds: const {},
      seed: 'seed-stable',
    );
    final second = engine.select(
      rules: rules,
      pool: pool,
      recentQuestionIds: const {},
      seed: 'seed-stable',
    );

    expect(second.questionIds, first.questionIds);
    expect(second.optionOrderByQuestion, first.optionOrderByQuestion);
    expect(first.questionIds, hasLength(4));
  });

  test('questions récentes sont évitées lorsque la banque le permet', () {
    const engine = StudyExamSelectionEngine();
    final selection = engine.select(
      rules: rules,
      pool: pool,
      recentQuestionIds: const {1, 2, 3, 101, 102, 103},
      seed: 'fresh-first',
    );

    expect(
      selection.questionIds.any(
        (id) => const {1, 2, 3, 101, 102, 103}.contains(id),
      ),
      isFalse,
    );
  });

  test('banque insuffisante bloque l’examen au lieu d’inventer des questions', () {
    const engine = StudyExamSelectionEngine();
    expect(
      () => engine.select(
        rules: rules,
        pool: [
          question(1, StudyQuestionCategory.comprehension),
          question(101, StudyQuestionCategory.context),
        ],
        recentQuestionIds: const {},
        seed: 'insufficient',
      ),
      throwsA(isA<StudyExamPoolException>()),
    );
  });
}
