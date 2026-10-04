import 'study_pack_models.dart';

class StudySectionMigration {
  const StudySectionMigration({
    required this.oldSectionId,
    required this.newSectionId,
    required this.migrationKind,
  });

  final int oldSectionId;
  final int? newSectionId;
  final String migrationKind;

  bool get safelyPreservesCompletion =>
      newSectionId != null && migrationKind == 'equivalent';
}

class StudyPackMigrationPlan {
  const StudyPackMigrationPlan({
    required this.preservedParagraphKeys,
    required this.newParagraphKeysToRead,
    required this.safeSectionMap,
  });

  final Set<String> preservedParagraphKeys;
  final Set<String> newParagraphKeysToRead;
  final Map<int, int> safeSectionMap;
}

class StudyPackMigrationPlanner {
  const StudyPackMigrationPlanner();

  StudyPackMigrationPlan plan({
    required List<StudyParagraph> oldParagraphs,
    required List<StudyParagraph> newParagraphs,
    required List<StudySectionMigration> sectionMigrations,
  }) {
    final oldKeys = oldParagraphs.map((item) => item.paragraphKey).toSet();
    final newKeys = newParagraphs.map((item) => item.paragraphKey).toSet();
    final preserved = oldKeys.intersection(newKeys);
    final toRead = newKeys.difference(preserved);

    final safeSections = <int, int>{};
    for (final migration in sectionMigrations) {
      if (migration.safelyPreservesCompletion) {
        safeSections[migration.oldSectionId] = migration.newSectionId!;
      }
    }

    return StudyPackMigrationPlan(
      preservedParagraphKeys: Set.unmodifiable(preserved),
      newParagraphKeysToRead: Set.unmodifiable(toRead),
      safeSectionMap: Map.unmodifiable(safeSections),
    );
  }
}
