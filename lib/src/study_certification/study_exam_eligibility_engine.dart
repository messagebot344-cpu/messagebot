import 'study_pack_models.dart';

class StudyExamEligibility {
  const StudyExamEligibility({
    required this.eligible,
    required this.reasons,
  });

  final bool eligible;
  final List<String> reasons;
}

class StudyExamEligibilityEngine {
  const StudyExamEligibilityEngine();

  StudyExamEligibility evaluate({
    required SermonStudyPackSummary pack,
    required StudyProgressSnapshot progress,
    required StudyExamRules rules,
    required List<StudySection> sections,
    required Set<int> completedSectionIds,
    required List<StudyQuestion> questionPool,
  }) {
    final reasons = <String>[];

    if (!pack.isPublished) {
      reasons.add('Le parcours d’étude n’est pas publié.');
    }
    if (progress.readingPercent < rules.minimumReadingPercent) {
      reasons.add('La lecture minimale requise n’est pas atteinte.');
    }

    final requiredSections = sections
        .where((section) => section.requiredForExam)
        .map((section) => section.id)
        .toSet();
    final missingSections =
        requiredSections.difference(completedSectionIds);
    if (missingSections.isNotEmpty) {
      reasons.add(
        'Des sections obligatoires ne sont pas encore terminées.',
      );
    }

    final eligibleQuestions = questionPool
        .where(
          (question) =>
              question.validationStatus == StudyQuestionStatus.validated &&
              question.certificationEligible,
        )
        .toList(growable: false);

    if (eligibleQuestions.length < rules.minimumQuestionBankSize) {
      reasons.add(
        'La banque de questions validées est insuffisante pour '
        'une certification robuste.',
      );
    }

    for (final categoryRule in rules.categories) {
      final count = eligibleQuestions
          .where((question) => question.category == categoryRule.category)
          .length;
      if (count < categoryRule.questionCount) {
        reasons.add(
          'Banque insuffisante pour la catégorie '
          '${categoryRule.category.name}.',
        );
      }
    }

    return StudyExamEligibility(
      eligible: reasons.isEmpty,
      reasons: List.unmodifiable(reasons),
    );
  }
}
