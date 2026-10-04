import 'retrieval_bundle.dart';
import 'search_explanation.dart';

class RankedCandidateV4 {
  const RankedCandidateV4({required this.passageId, required this.score, required this.explanation});
  final int passageId;
  final double score;
  final SearchExplanationV4 explanation;
}

class DeterministicHybridRanker {
  const DeterministicHybridRanker();

  List<RankedCandidateV4> rank(
    RetrievalBundleV4 bundle, {
    List<String> fuzzyTerms = const [],
    List<String> conceptualTerms = const [],
  }) {
    const k = 60.0;
    final scores = <int, double>{};
    final evidence = <int, _MutableExplanation>{};

    void addRanked(Iterable<dynamic> rows, double weight, void Function(_MutableExplanation) mark) {
      var rank = 0;
      for (final row in rows) {
        final id = row.passageId as int;
        scores[id] = (scores[id] ?? 0) + weight / (k + rank + 1);
        mark(evidence.putIfAbsent(id, _MutableExplanation.new));
        rank++;
      }
    }

    var directRank = 0;
    for (final id in bundle.direct) {
      scores[id] = (scores[id] ?? 0) + 5.0 / (k + directRank + 1);
      evidence.putIfAbsent(id, _MutableExplanation.new).direct = true;
      directRank++;
    }
    addRanked(bundle.exact, 5.0, (e) => e.exactPhrase = true);
    addRanked(bundle.proximity, 3.4, (e) => e.proximity = true);
    addRanked(bundle.strong, 2.8, (e) => e.strongTerms = true);
    addRanked(bundle.broad, 1.15, (e) => e.broadTerms = true);
    addRanked(bundle.prefix, 0.85, (e) => e.prefix = true);
    addRanked(bundle.morphology, 0.75, (e) => e.morphology = true);
    addRanked(bundle.conceptual, 0.62, (e) {
      e.conceptual = true;
      e.conceptualTerms.addAll(conceptualTerms);
    });
    addRanked(bundle.fuzzy, 0.50, (e) { e.fuzzy = true; e.fuzzyTerms.addAll(fuzzyTerms); });
    addRanked(bundle.alternate, 0.35, (e) => e.alternateEdition = true);

    final result = scores.entries.map((entry) {
      final e = evidence[entry.key] ?? _MutableExplanation();
      return RankedCandidateV4(
        passageId: entry.key,
        score: entry.value,
        explanation: SearchExplanationV4(
          direct: e.direct,
          exactPhrase: e.exactPhrase,
          proximity: e.proximity,
          strongTerms: e.strongTerms,
          broadTerms: e.broadTerms,
          prefix: e.prefix,
          morphology: e.morphology,
          conceptual: e.conceptual,
          fuzzy: e.fuzzy,
          alternateEdition: e.alternateEdition,
          fuzzyTerms: e.fuzzyTerms.toList(growable: false),
          conceptualTerms: e.conceptualTerms.toList(growable: false),
        ),
      );
    }).toList(growable: false)
      ..sort((a, b) {
        final byScore = b.score.compareTo(a.score);
        return byScore != 0 ? byScore : a.passageId.compareTo(b.passageId);
      });
    return result;
  }
}

class _MutableExplanation {
  bool direct = false;
  bool exactPhrase = false;
  bool proximity = false;
  bool strongTerms = false;
  bool broadTerms = false;
  bool prefix = false;
  bool morphology = false;
  bool conceptual = false;
  bool fuzzy = false;
  bool alternateEdition = false;
  final Set<String> fuzzyTerms = <String>{};
  final Set<String> conceptualTerms = <String>{};
}
