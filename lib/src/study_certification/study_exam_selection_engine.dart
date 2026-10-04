import 'dart:math';

import 'study_pack_models.dart';

class StudyExamPoolException implements Exception {
  const StudyExamPoolException(this.message);
  final String message;

  @override
  String toString() => 'StudyExamPoolException: $message';
}

class StudyExamSelection {
  const StudyExamSelection({
    required this.seed,
    required this.questionIds,
    required this.optionOrderByQuestion,
  });

  final String seed;
  final List<int> questionIds;
  final Map<int, List<int>> optionOrderByQuestion;
}

class StudyExamSelectionEngine {
  const StudyExamSelectionEngine();

  String generateSeed() {
    final random = Random.secure();
    final values = List<int>.generate(16, (_) => random.nextInt(256));
    return values
        .map((value) => value.toRadixString(16).padLeft(2, '0'))
        .join();
  }

  StudyExamSelection select({
    required StudyExamRules rules,
    required List<StudyQuestion> pool,
    required Set<int> recentQuestionIds,
    String? seed,
  }) {
    final effectiveSeed = seed ?? generateSeed();
    final random = Random(_seedToInt(effectiveSeed));
    final selected = <StudyQuestion>[];

    for (final categoryRule in rules.categories) {
      final allForCategory = pool
          .where(
            (question) =>
                question.validationStatus == StudyQuestionStatus.validated &&
                question.certificationEligible &&
                question.category == categoryRule.category,
          )
          .toList(growable: false);
      if (allForCategory.length < categoryRule.questionCount) {
        throw StudyExamPoolException(
          'Banque insuffisante pour ${categoryRule.category.name}: '
          '${allForCategory.length}/${categoryRule.questionCount}.',
        );
      }

      final fresh = allForCategory
          .where((question) => !recentQuestionIds.contains(question.id))
          .toList();
      final recent = allForCategory
          .where((question) => recentQuestionIds.contains(question.id))
          .toList();
      fresh.shuffle(random);
      recent.shuffle(random);

      final categorySelection = <StudyQuestion>[
        ...fresh.take(categoryRule.questionCount),
      ];
      if (categorySelection.length < categoryRule.questionCount) {
        categorySelection.addAll(
          recent.take(categoryRule.questionCount - categorySelection.length),
        );
      }
      selected.addAll(categorySelection);
    }

    if (selected.length != rules.examSize) {
      throw StudyExamPoolException(
        'La somme des quotas (${selected.length}) ne correspond pas à '
        'exam_size=${rules.examSize}.',
      );
    }

    selected.shuffle(random);
    final optionOrder = <int, List<int>>{};
    for (final question in selected) {
      final ids = question.options.map((option) => option.id).toList();
      ids.shuffle(random);
      optionOrder[question.id] = ids;
    }

    return StudyExamSelection(
      seed: effectiveSeed,
      questionIds: selected.map((question) => question.id).toList(),
      optionOrderByQuestion: optionOrder,
    );
  }

  int _seedToInt(String value) {
    var hash = 0x811C9DC5;
    for (final codeUnit in value.codeUnits) {
      hash ^= codeUnit;
      hash = (hash * 0x01000193) & 0x7FFFFFFF;
    }
    return hash;
  }
}
