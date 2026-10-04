import 'dart:math' as math;

import '../search_v4/curated_reference_index.dart';
import '../search_v4/text_normalizer.dart';

class OfflineAiTopicMatch {
  const OfflineAiTopicMatch({
    required this.topicId,
    required this.label,
    required this.score,
  });

  final String topicId;
  final String label;

  /// Cosine similarity in the compact local feature space.
  final double score;
}

/// Small, fully local semantic router.
///
/// This is intentionally not a generative model. It builds sparse TF-IDF-like
/// topic prototypes from the human-curated aliases/keywords already shipped
/// with MessageBot, then compares each user query to those prototypes using a
/// deterministic hashed word/subword feature space.
///
/// The router can only choose topics. It never returns quotation text and it
/// never writes a theological answer; corpus.db remains the sole source of
/// displayed passages.
class OfflineAiSemanticRouter {
  OfflineAiSemanticRouter._({
    required this.topics,
    required Map<int, double> idf,
    required Map<String, Map<int, double>> topicVectors,
    this.normalizer = const TextNormalizer(),
    this.dimensions = 4096,
    this.minScore = 0.105,
  })  : _idf = Map.unmodifiable(idf),
        _topicVectors = Map.unmodifiable(topicVectors);

  factory OfflineAiSemanticRouter.fromIndex(
    CuratedReferenceIndex index, {
    int dimensions = 4096,
    double minScore = 0.105,
  }) {
    final normalizer = index.normalizer;
    final topics = List<CuratedReferenceTopic>.unmodifiable(index.topics);
    final raw = <String, Map<int, double>>{};
    final documentFrequency = <int, int>{};

    for (final topic in topics) {
      final features = _rawFeatures(
        normalizer: normalizer,
        dimensions: dimensions,
        topic: topic,
      );
      raw[topic.id] = features;
      for (final feature in features.keys) {
        documentFrequency[feature] =
            (documentFrequency[feature] ?? 0) + 1;
      }
    }

    final topicCount = math.max(1, topics.length);
    final idf = <int, double>{
      for (final entry in documentFrequency.entries)
        entry.key:
            math.log((topicCount + 1) / (entry.value + 1)) + 1.0,
    };

    final vectors = <String, Map<int, double>>{};
    for (final topic in topics) {
      vectors[topic.id] = _normalize(
        raw[topic.id]!,
        idf: idf,
      );
    }

    return OfflineAiSemanticRouter._(
      topics: topics,
      idf: idf,
      topicVectors: vectors,
      normalizer: normalizer,
      dimensions: dimensions,
      minScore: minScore,
    );
  }

  final List<CuratedReferenceTopic> topics;
  final TextNormalizer normalizer;
  final int dimensions;
  final double minScore;
  final Map<int, double> _idf;
  final Map<String, Map<int, double>> _topicVectors;

  int get topicCount => topics.length;

  List<OfflineAiTopicMatch> match(
    String query, {
    int limit = 6,
  }) {
    final queryVector = _queryVector(query);
    if (queryVector.isEmpty) return const [];

    final values = <OfflineAiTopicMatch>[];
    for (final topic in topics) {
      final topicVector = _topicVectors[topic.id];
      if (topicVector == null || topicVector.isEmpty) continue;

      var score = _dot(queryVector, topicVector);

      // Exact human aliases remain privileged evidence, but they are only a
      // small calibration boost on top of the local vector model.
      final normalizedQuery = normalizer.normalize(query);
      for (final alias in topic.aliases) {
        final normalizedAlias = normalizer.normalize(alias);
        if (normalizedAlias.isEmpty) continue;
        if (normalizedQuery == normalizedAlias ||
            (' $normalizedQuery ').contains(' $normalizedAlias ')) {
          score += 0.12;
          break;
        }
      }

      if (score < minScore) continue;
      values.add(
        OfflineAiTopicMatch(
          topicId: topic.id,
          label: topic.label,
          score: score.clamp(0.0, 1.0).toDouble(),
        ),
      );
    }

    values.sort((a, b) {
      final byScore = b.score.compareTo(a.score);
      return byScore != 0
          ? byScore
          : a.topicId.compareTo(b.topicId);
    });
    return values.take(limit).toList(growable: false);
  }

  Map<int, double> _queryVector(String query) {
    final raw = _rawTextFeatures(
      normalizer: normalizer,
      dimensions: dimensions,
      text: query,
      wordWeight: 1.0,
      bigramWeight: 0.85,
      subwordWeight: 0.22,
    );
    if (raw.isEmpty) return const {};
    return _normalize(raw, idf: _idf, unknownIdf: 1.0);
  }

  static Map<int, double> _rawFeatures({
    required TextNormalizer normalizer,
    required int dimensions,
    required CuratedReferenceTopic topic,
  }) {
    final values = <int, double>{};

    void merge(Map<int, double> source, double multiplier) {
      for (final entry in source.entries) {
        values[entry.key] =
            (values[entry.key] ?? 0) + entry.value * multiplier;
      }
    }

    merge(
      _rawTextFeatures(
        normalizer: normalizer,
        dimensions: dimensions,
        text: topic.label,
        wordWeight: 1.6,
        bigramWeight: 1.25,
        subwordWeight: 0.30,
      ),
      1.0,
    );
    for (final alias in topic.aliases) {
      merge(
        _rawTextFeatures(
          normalizer: normalizer,
          dimensions: dimensions,
          text: alias,
          wordWeight: 1.25,
          bigramWeight: 1.0,
          subwordWeight: 0.26,
        ),
        1.0,
      );
    }
    for (final keyword in topic.keywords) {
      merge(
        _rawTextFeatures(
          normalizer: normalizer,
          dimensions: dimensions,
          text: keyword,
          wordWeight: 1.35,
          bigramWeight: 0.9,
          subwordWeight: 0.24,
        ),
        1.0,
      );
    }
    return values;
  }

  static Map<int, double> _rawTextFeatures({
    required TextNormalizer normalizer,
    required int dimensions,
    required String text,
    required double wordWeight,
    required double bigramWeight,
    required double subwordWeight,
  }) {
    final tokens = normalizer
        .semanticTokens(text, removeStopWords: true)
        .where((token) => !_noise.contains(token))
        .toList(growable: false);
    if (tokens.isEmpty) return const {};

    final values = <int, double>{};

    void add(String feature, double value) {
      final slot = _hash(feature, dimensions);
      values[slot] = (values[slot] ?? 0) + value;
    }

    for (final token in tokens) {
      add('w:$token', wordWeight);
      final padded = '^$token\$';
      if (padded.length >= 3) {
        for (var i = 0; i <= padded.length - 3; i++) {
          add('c:${padded.substring(i, i + 3)}', subwordWeight);
        }
      }
    }

    for (var i = 0; i + 1 < tokens.length; i++) {
      add('b:${tokens[i]}_${tokens[i + 1]}', bigramWeight);
    }
    return values;
  }

  static Map<int, double> _normalize(
    Map<int, double> raw, {
    required Map<int, double> idf,
    double unknownIdf = 1.0,
  }) {
    if (raw.isEmpty) return const {};
    final weighted = <int, double>{};
    var sumSquares = 0.0;
    for (final entry in raw.entries) {
      final value = entry.value * (idf[entry.key] ?? unknownIdf);
      weighted[entry.key] = value;
      sumSquares += value * value;
    }
    if (sumSquares <= 0) return const {};
    final norm = math.sqrt(sumSquares);
    return {
      for (final entry in weighted.entries)
        entry.key: entry.value / norm,
    };
  }

  static double _dot(
    Map<int, double> left,
    Map<int, double> right,
  ) {
    final small = left.length <= right.length ? left : right;
    final large = identical(small, left) ? right : left;
    var sum = 0.0;
    for (final entry in small.entries) {
      final value = large[entry.key];
      if (value != null) sum += entry.value * value;
    }
    return sum;
  }

  static int _hash(String value, int dimensions) {
    var hash = 0x811c9dc5;
    for (final codeUnit in value.codeUnits) {
      hash ^= codeUnit;
      hash = (hash * 0x01000193) & 0xffffffff;
    }
    return hash % dimensions;
  }

  static const Set<String> _noise = <String>{
    'comment',
    'pourquoi',
    'quel',
    'quelle',
    'quels',
    'quelles',
    'quoi',
    'qui',
    'quand',
    'peut',
    'peux',
    'puis',
    'pouvons',
    'doit',
    'dois',
    'faut',
    'etre',
  };
}
