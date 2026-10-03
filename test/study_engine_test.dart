import 'package:flutter_test/flutter_test.dart';
import 'package:le_grenier_du_message/src/models/models.dart';
import 'package:le_grenier_du_message/src/services/corpus_repository.dart';
import 'package:le_grenier_du_message/src/study/comparison_engine.dart';
import 'package:le_grenier_du_message/src/study/similarity_engine.dart';
import 'package:le_grenier_du_message/src/study/study_engine.dart';

void main() {
  test('V4 similar passages uses sparse FTS candidates, not legacy LSA neighbors', () {
    final repo = _FakeStudyRepository();
    final results = SimilarityEngine(repo).similarPassages(1);
    expect(results.single.passage.passage.id, 2);
    expect(results.single.relationScope, 'other_source');
    expect(repo.legacyNeighborCalls, 0);
  });

  test('timeline retourne les prédications en ordre chronologique', () {
    final repo = _FakeStudyRepository();
    final years = StudyEngine(repo).timeline('foi').map((e) => e.sermon!.year).toList();
    expect(years, orderedEquals([1955, 1965]));
  });

  test('comparison calcule des différences textuelles sans synthèse', () {
    final result = const ComparisonEngine().compare(
      'La foi regarde à la promesse de Dieu',
      'La foi demeure dans la Parole de Dieu',
    );
    expect(result.commonWordCount, greaterThan(2));
    expect(result.onlyInA, contains('promesse'));
    expect(result.onlyInB, contains('parole'));
  });
}

class _FakeStudyRepository extends CorpusRepository {
  int legacyNeighborCalls = 0;

  StudyPassage _study(int id, int year) => StudyPassage(
    passage: Passage(
      id: id,
      editionId: 'e$id',
      sermonId: id,
      ordinal: 0,
      sourcePageStart: id,
      sourcePageEnd: id,
      text: id == 1
          ? 'La foi regarde la promesse de Dieu et demeure dans la Parole.'
          : 'La foi demeure dans la promesse et dans la Parole de Dieu.',
    ),
    source: CorpusSourceSummary(id: 'sermon:$id', type: CorpusSourceType.sermon, title: 'Test $id'),
    sermon: SermonSummary(id: id, code: '$year-000$id', title: 'Test $id', year: year, editionCount: 1, primaryEditionId: 'e$id'),
    edition: EditionSummary(id: 'e$id', sermonId: id, title: 'Test', isPrimary: true, isFrn: false, sourcePageStart: id, sourcePageEnd: id),
  );

  @override
  List<NeighborPassage> neighborPassages(int passageId, {int limit = 20, String? relationScope}) {
    legacyNeighborCalls++;
    return const [NeighborPassage(passageId: 99, score: 1, relationScope: 'other_source')];
  }

  @override
  List<RankedPassage> lexicalSearchAll(String ftsQuery, {int limit = 120}) => const [RankedPassage(2, -1)];

  @override
  Map<int, StudyPassage> studyDetailsForPassageIds(Iterable<int> ids) => {
    for (final id in ids) id: _study(id, id == 2 ? 1965 : 1955),
  };

  @override
  List<int> concordancePassageIds(String term, {int limit = 100, CorpusSourceType? sourceType}) => const [2, 1];
}
