import 'study_pack_models.dart';

class StudyExamEvaluation {
  const StudyExamEvaluation({
    required this.overallScore,
    required this.categoryScores,
    required this.passed,
  });

  final double overallScore;
  final Map<String, double> categoryScores;
  final bool passed;
}

class StudyExamScoringEngine {
  const StudyExamScoringEngine();

  StudyExamEvaluation evaluate({
    required StudyExamRules rules,
    required List<StudyQuestion> questions,
    required Map<int, double> scoresByQuestion,
  }) {
    if (questions.length != rules.examSize) {
      throw StateError(
        'Le nombre de questions notées ne correspond pas à exam_size.',
      );
    }

    final categoryScores = <String, double>{};
    var weightedSum = 0.0;
    var weightSum = 0.0;
    var categoryMinimumsPassed = true;

    for (final categoryRule in rules.categories) {
      final categoryQuestions = questions
          .where((question) => question.category == categoryRule.category)
          .toList(growable: false);
      if (categoryQuestions.length != categoryRule.questionCount) {
        throw StateError(
          'Quota incohérent pour ${categoryRule.category.name}.',
        );
      }

      var sum = 0.0;
      for (final question in categoryQuestions) {
        final score = scoresByQuestion[question.id];
        if (score == null) {
          throw StateError(
            'Réponse manquante pour la question ${question.id}.',
          );
        }
        sum += score.clamp(0.0, 1.0);
      }

      final categoryScore = categoryQuestions.isEmpty
          ? 0.0
          : sum / categoryQuestions.length;
      final key = _categoryName(categoryRule.category);
      categoryScores[key] = categoryScore;
      weightedSum += categoryScore * categoryRule.weight;
      weightSum += categoryRule.weight;

      final minimum = categoryRule.minimumScore;
      if (minimum != null && categoryScore < minimum) {
        categoryMinimumsPassed = false;
      }
    }

    if (weightSum <= 0) {
      throw StateError('La pondération de l’examen est invalide.');
    }
    final overall = (weightedSum / weightSum).clamp(0.0, 1.0).toDouble();
    return StudyExamEvaluation(
      overallScore: overall,
      categoryScores: Map.unmodifiable(categoryScores),
      passed: overall >= rules.passThreshold && categoryMinimumsPassed,
    );
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
}
