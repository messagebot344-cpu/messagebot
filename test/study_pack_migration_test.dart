import 'package:flutter_test/flutter_test.dart';
import 'package:le_grenier_du_message/src/study_certification/study_pack_migration.dart';
import 'package:le_grenier_du_message/src/study_certification/study_pack_models.dart';

StudyParagraph p(String key, int ordinal) => StudyParagraph(
      paragraphKey: key,
      sermonId: 1,
      editionId: 'e1',
      passageId: 100 + ordinal,
      globalOrdinal: ordinal,
      startOffset: 0,
      endOffset: 10,
      sourcePageStart: 1,
      sourcePageEnd: 1,
      textSha256: 'sha-$key',
      characterCount: 10,
    );

void main() {
  test('migration conserve uniquement les paragraphes canoniquement identiques', () {
    const planner = StudyPackMigrationPlanner();
    final plan = planner.plan(
      oldParagraphs: [p('same-a', 0), p('old-changed', 1)],
      newParagraphs: [p('same-a', 0), p('new-changed', 1)],
      sectionMigrations: const [
        StudySectionMigration(
          oldSectionId: 10,
          newSectionId: 20,
          migrationKind: 'equivalent',
        ),
        StudySectionMigration(
          oldSectionId: 11,
          newSectionId: 21,
          migrationKind: 'split',
        ),
      ],
    );

    expect(plan.preservedParagraphKeys, {'same-a'});
    expect(plan.newParagraphKeysToRead, {'new-changed'});
    expect(plan.safeSectionMap, {10: 20});
    expect(plan.safeSectionMap.containsKey(11), isFalse);
  });

  test('une section supprimée ou ambiguë ne conserve jamais sa complétion', () {
    const planner = StudyPackMigrationPlanner();
    final plan = planner.plan(
      oldParagraphs: [p('a', 0)],
      newParagraphs: [p('a', 0)],
      sectionMigrations: const [
        StudySectionMigration(
          oldSectionId: 1,
          newSectionId: null,
          migrationKind: 'removed',
        ),
        StudySectionMigration(
          oldSectionId: 2,
          newSectionId: 3,
          migrationKind: 'needs_review',
        ),
      ],
    );

    expect(plan.safeSectionMap, isEmpty);
  });
}
