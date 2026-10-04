import 'package:flutter_test/flutter_test.dart';
import 'package:le_grenier_du_message/src/study_certification/study_exam_scoring_engine.dart';
import 'package:le_grenier_du_message/src/study_certification/study_pack_models.dart';

StudyQuestion scoredQuestion(int id, StudyQuestionCategory category) =>
    StudyQuestion(
      id: id,
      sermonId: 2,
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
  const engine = StudyExamScoringEngine();

  test('score global respecte les pondérations et le seuil', () {
    const rules = StudyExamRules(
      sermonId: 2,
      packVersion: 1,
      examSize: 4,
      passThreshold: 0.85,
      recentQuestionExclusionCount: 2,
      minimumReadingPercent: 0.95,
      minimumBankMultiplier: 2.4,
      categories: [
        StudyExamCategoryRule(
          category: StudyQuestionCategory.comprehension,
          weight: 0.4,
          questionCount: 2,
          minimumScore: 0.70,
        ),
        StudyExamCategoryRule(
          category: StudyQuestionCategory.context,
          weight: 0.6,
          questionCount: 2,
          minimumScore: 0.80,
        ),
      ],
    );
    final questions = [
      scoredQuestion(1, StudyQuestionCategory.comprehension),
      scoredQuestion(2, StudyQuestionCategory.comprehension),
      scoredQuestion(3, StudyQuestionCategory.context),
      scoredQuestion(4, StudyQuestionCategory.context),
    ];

    final failed = engine.evaluate(
      rules: rules,
      questions: questions,
      scoresByQuestion: const {
        1: 1.0,
        2: 0.8,
        3: 0.9,
        4: 0.7,
      },
    );
    expect(failed.categoryScores['comprehension'], closeTo(0.9, 0.0001));
    expect(failed.categoryScores['context'], closeTo(0.8, 0.0001));
    expect(failed.overallScore, closeTo(0.84, 0.0001));
    expect(failed.passed, isFalse);

    final passed = engine.evaluate(
      rules: rules,
      questions: questions,
      scoresByQuestion: const {
        1: 1.0,
        2: 0.8,
        3: 0.9,
        4: 0.9,
      },
    );
    expect(passed.overallScore, closeTo(0.9, 0.0001));
    expect(passed.passed, isTrue);
  });

  test('minimum de catégorie peut bloquer un score global élevé', () {
    const rules = StudyExamRules(
      sermonId: 2,
      packVersion: 1,
      examSize: 2,
      passThreshold: 0.85,
      recentQuestionExclusionCount: 0,
      minimumReadingPercent: 0.95,
      minimumBankMultiplier: 2.4,
      categories: [
        StudyExamCategoryRule(
          category: StudyQuestionCategory.comprehension,
          weight: 0.2,
          questionCount: 1,
          minimumScore: 0.70,
        ),
        StudyExamCategoryRule(
          category: StudyQuestionCategory.context,
          weight: 0.8,
          questionCount: 1,
        ),
      ],
    );
    final evaluation = engine.evaluate(
      rules: rules,
      questions: [
        scoredQuestion(1, StudyQuestionCategory.comprehension),
        scoredQuestion(2, StudyQuestionCategory.context),
      ],
      scoresByQuestion: const {
        1: 0.6,
        2: 1.0,
      },
    );
    expect(evaluation.overallScore, closeTo(0.92, 0.0001));
    expect(evaluation.passed, isFalse);
  });
}
