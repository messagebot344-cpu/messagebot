import '../services/corpus_repository.dart';
import '../services/semantic_index.dart';
import 'lexical_search_engine.dart';
import 'search_contracts.dart';

class RankedCandidate {
  const RankedCandidate({
    required this.passageId,
    required this.score,
    required this.evidence,
  });

  final int passageId;
  final double score;
  final SearchEvidence evidence;
}

class HybridRanker {
  const HybridRanker();

  List<RankedCandidate> rank({
    required QueryIntent intent,
    required LexicalSearchBundle lexical,
    required List<SemanticHit> semantic,
    required int knownTokenCount,
    required int tokenCount,
    required double tokenCoverage,
  }) {
    if (lexical.direct.isEmpty && lexical.strong.isEmpty && lexical.alternateStrong.isEmpty) {
      if (tokenCount >= 2 && knownTokenCount == 0) return const [];
      if (tokenCount >= 3 && knownTokenCount < 2 && tokenCoverage < 0.50) {
        return const [];
      }
    }

    if (lexical.direct.isEmpty &&
        lexical.strong.isEmpty &&
        lexical.broad.isEmpty &&
        lexical.alternateStrong.isEmpty &&
        lexical.alternateBroad.isEmpty) {
      final topSemanticScore = semantic.isEmpty ? 0.0 : semantic.first.score;
      if (topSemanticScore < 0.24) return const [];
    }

    const k = 60.0;
    final scores = <int, double>{};
    final evidence = <int, _MutableEvidence>{};

    void addPassages(
      Iterable<RankedPassage> items,
      double weight, {
      required String channel,
      bool alternate = false,
    }) {
      var rank = 0;
      for (final item in items) {
        scores[item.passageId] = (scores[item.passageId] ?? 0) + weight / (k + rank + 1);
        final e = evidence.putIfAbsent(item.passageId, _MutableEvidence.new);
        e.alternateEdition = e.alternateEdition || alternate;
        if (channel == 'strong') e.lexicalStrongRank ??= rank;
        if (channel == 'broad') e.lexicalBroadRank ??= rank;
        rank++;
      }
    }

    addPassages(lexical.strong, intent.exactPhrase != null ? 3.2 : 2.4, channel: 'strong');
    addPassages(lexical.broad, 1.2, channel: 'broad');
    addPassages(lexical.alternateStrong, 0.85, channel: 'strong', alternate: true);
    addPassages(lexical.alternateBroad, 0.35, channel: 'broad', alternate: true);

    var semanticRank = 0;
    for (final item in semantic) {
      scores[item.passageId] = (scores[item.passageId] ?? 0) + 1.0 / (k + semanticRank + 1);
      final e = evidence.putIfAbsent(item.passageId, _MutableEvidence.new);
      e.semanticRank ??= semanticRank;
      e.semanticScore ??= item.score;
      semanticRank++;
    }

    var directRank = 0;
    for (final passageId in lexical.direct) {
      scores[passageId] = (scores[passageId] ?? 0) + 3.0 / (k + directRank + 1);
      evidence.putIfAbsent(passageId, _MutableEvidence.new).direct = true;
      directRank++;
    }

    final ranked = scores.entries
        .map((entry) {
          final e = evidence[entry.key] ?? _MutableEvidence();
          return RankedCandidate(
            passageId: entry.key,
            score: entry.value,
            evidence: SearchEvidence(
              direct: e.direct,
              exact: intent.exactPhrase != null && e.lexicalStrongRank != null,
              lexicalStrongRank: e.lexicalStrongRank,
              lexicalBroadRank: e.lexicalBroadRank,
              semanticRank: e.semanticRank,
              semanticScore: e.semanticScore,
              alternateEdition: e.alternateEdition,
              termCoverage: tokenCoverage,
            ),
          );
        })
        .toList(growable: false)
      ..sort((a, b) {
        final score = b.score.compareTo(a.score);
        return score != 0 ? score : a.passageId.compareTo(b.passageId);
      });
    return ranked;
  }
}

class _MutableEvidence {
  bool direct = false;
  bool alternateEdition = false;
  int? lexicalStrongRank;
  int? lexicalBroadRank;
  int? semanticRank;
  double? semanticScore;
}
