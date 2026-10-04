import 'package:flutter_test/flutter_test.dart';
import 'package:le_grenier_du_message/src/search_v4/deterministic_hybrid_ranker.dart';
import 'package:le_grenier_du_message/src/search_v4/retrieval_bundle.dart';
import 'package:le_grenier_du_message/src/services/corpus_repository.dart';

void main() {
  test('un repère humain validé booste un passage sans dépasser une citation exacte', () {
    const ranker = DeterministicHybridRanker();
    final ranked = ranker.rank(
      const RetrievalBundleV4(
        exact: [RankedPassage(1, 0)],
        curated: [RankedPassage(2, 0)],
        broad: [RankedPassage(3, 0)],
      ),
    );

    expect(ranked.map((value) => value.passageId).toList(), [1, 2, 3]);
    expect(ranked[1].explanation.curatedReference, isTrue);
    expect(
      ranked[1].explanation.reasons.join(' '),
      contains('Repère thématique validé manuellement'),
    );
  });
}
