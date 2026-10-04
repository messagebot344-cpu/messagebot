import 'dart:collection';
import 'dart:math' as math;

import '../models/models.dart';
import '../search/search_contracts.dart';
import '../search_v4/curated_reference_index.dart';
import '../search_v4/query_parser_v4.dart';
import '../search_v4/text_normalizer.dart';

class OfflineAiCitationMatch {
  const OfflineAiCitationMatch({
    required this.reference,
    required this.score,
    required this.topicLabels,
  });

  final CuratedSermonReference reference;

  /// Semantic similarity against the user question in the local vector space.
  final double score;
  final List<String> topicLabels;
}

class OfflineAiPassageMatch {
  const OfflineAiPassageMatch({
    required this.passageId,
    required this.score,
    required this.semanticScore,
    required this.coverageScore,
    required this.referencePrior,
    required this.canonicalEvidenceScore,
    required this.intentCompatibilityScore,
    this.sentence,
  });

  final int passageId;

  /// Final answer-relevance score in [0, 1].
  final double score;

  /// Best local semantic similarity found in the canonical passage.
  final double semanticScore;

  /// Query-term coverage in the canonical passage.
  final double coverageScore;

  /// Prior confidence inherited from the best matching curated reference.
  final double referencePrior;

  /// Relevance supported by the canonical quotation alone. Curated priors are
  /// intentionally excluded so a human routing hint can never rescue an
  /// unrelated passage.
  final double canonicalEvidenceScore;

  /// Small intent-compatibility signal for why/how/definition/etc.
  final double intentCompatibilityScore;

  /// Best answering sentence, always pointing inside canonical passage text.
  final SentenceReference? sentence;
}

/// Local citation selector.
///
/// This layer does two things:
/// 1. compares the user question against every active human-curated reference;
/// 2. compares the question against the real canonical passage text retrieved
///    from corpus.db, sentence by sentence.
///
/// It never generates quotation text. It only scores canonical material.
class OfflineAiCitationRanker {
  OfflineAiCitationRanker._({
    required this.references,
    required Map<String, Map<int, double>> referenceVectors,
    required Map<int, double> idf,
    required Map<String, List<String>> topicLabelsByReference,
    required Map<String, Set<String>> referenceTokensByReference,
    required Map<String, String> normalizedContextByReference,
    this.normalizer = const TextNormalizer(),
    this.dimensions = 8192,
    this.minReferenceScore = 0.045,
    this.minPassageScore = 0.08,
    this.minAnswerEvidenceScore = 0.11,
    this.minAnswerScore = 0.13,
  })  : _referenceVectors = Map.unmodifiable(referenceVectors),
        _idf = Map.unmodifiable(idf),
        _topicLabelsByReference = Map.unmodifiable(topicLabelsByReference),
        _referenceTokensByReference = Map.unmodifiable(
          referenceTokensByReference,
        ),
        _normalizedContextByReference = Map.unmodifiable(
          normalizedContextByReference,
        );

  factory OfflineAiCitationRanker.fromIndex(
    CuratedReferenceIndex index, {
    int dimensions = 8192,
    double minReferenceScore = 0.045,
    double minPassageScore = 0.08,
    double minAnswerEvidenceScore = 0.11,
    double minAnswerScore = 0.13,
  }) {
    final references = index.references.values
        .where((reference) => reference.corpusResolved)
        .toList(growable: false);

    final topicLabelsByReference = <String, List<String>>{};
    for (final topic in index.topics) {
      for (final referenceId in topic.referenceIds) {
        final values = topicLabelsByReference.putIfAbsent(
          referenceId,
          () => <String>[],
        );
        if (!values.contains(topic.label)) values.add(topic.label);
      }
    }

    final rawVectors = <String, Map<int, double>>{};
    final referenceTokensByReference = <String, Set<String>>{};
    final normalizedContextByReference = <String, String>{};
    final documentFrequency = <int, int>{};

    for (final reference in references) {
      final labels =
          topicLabelsByReference[reference.id] ?? const <String>[];
      final raw = _referenceFeatures(
        normalizer: index.normalizer,
        dimensions: dimensions,
        reference: reference,
        topicLabels: labels,
      );
      rawVectors[reference.id] = raw;
      referenceTokensByReference[reference.id] = Set.unmodifiable(
        index.normalizer
            .tokens(
              [
                reference.context,
                reference.sermonTitle,
                ...reference.anchorTerms,
              ].join(' '),
              removeStopWords: true,
            )
            .toSet(),
      );
      normalizedContextByReference[reference.id] =
          index.normalizer.normalize(reference.context);
      for (final feature in raw.keys) {
        documentFrequency[feature] =
            (documentFrequency[feature] ?? 0) + 1;
      }
    }

    final documentCount = math.max(1, references.length);
    final idf = <int, double>{
      for (final entry in documentFrequency.entries)
        entry.key:
            math.log((documentCount + 1) / (entry.value + 1)) + 1.0,
    };

    final referenceVectors = <String, Map<int, double>>{};
    for (final reference in references) {
      referenceVectors[reference.id] = _normalize(
        rawVectors[reference.id]!,
        idf: idf,
      );
    }

    return OfflineAiCitationRanker._(
      references: List.unmodifiable(references),
      referenceVectors: referenceVectors,
      idf: idf,
      topicLabelsByReference: {
        for (final entry in topicLabelsByReference.entries)
          entry.key: List.unmodifiable(entry.value),
      },
      referenceTokensByReference: referenceTokensByReference,
      normalizedContextByReference: normalizedContextByReference,
      normalizer: index.normalizer,
      dimensions: dimensions,
      minReferenceScore: minReferenceScore,
      minPassageScore: minPassageScore,
      minAnswerEvidenceScore: minAnswerEvidenceScore,
      minAnswerScore: minAnswerScore,
    );
  }

  final List<CuratedSermonReference> references;
  final TextNormalizer normalizer;
  final int dimensions;
  final double minReferenceScore;
  final double minPassageScore;
  final double minAnswerEvidenceScore;
  final double minAnswerScore;
  final Map<String, Map<int, double>> _referenceVectors;
  final Map<int, double> _idf;
  final Map<String, List<String>> _topicLabelsByReference;
  final Map<String, Set<String>> _referenceTokensByReference;
  final Map<String, String> _normalizedContextByReference;
  final LinkedHashMap<int, _PreparedPassage> _passageCache =
      LinkedHashMap<int, _PreparedPassage>();

  static const int _passageCacheLimit = 160;

  int get activeReferenceCount => references.length;
  int get cachedPassageCount => _passageCache.length;

  /// Scores every active curated reference, then returns only the strongest.
  List<OfflineAiCitationMatch> rankReferences(
    String query, {
    int limit = 48,
  }) {
    final queryVector = _queryVector(query);
    if (queryVector.isEmpty) return const [];

    final normalizedQuery = normalizer.normalize(query);
    final queryTokens = normalizer
        .tokens(query, removeStopWords: true)
        .where((token) => !_noise.contains(token))
        .toSet();
    final values = <OfflineAiCitationMatch>[];

    for (final reference in references) {
      final vector = _referenceVectors[reference.id];
      if (vector == null || vector.isEmpty) continue;

      var score = _dot(queryVector, vector);
      final referenceTokens =
          _referenceTokensByReference[reference.id] ?? const <String>{};
      final overlap =
          queryTokens.where(referenceTokens.contains).length;
      if (queryTokens.isNotEmpty && overlap > 0) {
        score += (overlap / queryTokens.length) * 0.16;
      }

      final normalizedContext =
          _normalizedContextByReference[reference.id] ?? '';
      if (normalizedContext.isNotEmpty &&
          (' $normalizedQuery ').contains(' $normalizedContext ')) {
        score += 0.12;
      }

      if (score < minReferenceScore) continue;
      values.add(
        OfflineAiCitationMatch(
          reference: reference,
          score: score.clamp(0.0, 1.0).toDouble(),
          topicLabels:
              _topicLabelsByReference[reference.id] ?? const <String>[],
        ),
      );
    }

    values.sort((a, b) {
      final byScore = b.score.compareTo(a.score);
      return byScore != 0
          ? byScore
          : a.reference.id.compareTo(b.reference.id);
    });
    return values.take(limit).toList(growable: false);
  }

  /// Reranks real canonical passages after retrieval.
  ///
  /// [referencePriors] contains the best reference-level score that led to a
  /// passage. Direct/exact corpus search candidates may have no prior.
  List<OfflineAiPassageMatch> rankPassages(
    String query,
    Iterable<StudyPassage> passages, {
    Map<int, double> referencePriors = const <int, double>{},
    QuestionIntent questionIntent = QuestionIntent.none,
  }) {
    final queryVector = _queryVector(query);
    final queryTokens = normalizer
        .tokens(query, removeStopWords: true)
        .where((token) => !_noise.contains(token))
        .toSet();
    if (queryVector.isEmpty || queryTokens.isEmpty) return const [];

    final values = <OfflineAiPassageMatch>[];

    for (final detail in passages) {
      final text = detail.passage.text;
      if (text.trim().isEmpty) continue;

      final prepared = _preparePassage(detail);
      final wholeSimilarity = _dot(queryVector, prepared.vector);

      final overlap =
          queryTokens.where(prepared.tokens.contains).length;
      final coverage = queryTokens.isEmpty
          ? 0.0
          : overlap / queryTokens.length;

      final sentence = _bestPreparedSentence(
        passageId: detail.passage.id,
        prepared: prepared,
        queryVector: queryVector,
        queryTokens: queryTokens,
      );
      final sentenceSemantic = sentence.$2;
      final prior =
          referencePriors[detail.passage.id]?.clamp(0.0, 1.0).toDouble() ??
              0.0;

      final semantic = math.max(wholeSimilarity, sentenceSemantic);
      final canonicalEvidence = (
        sentenceSemantic * 0.55 +
        wholeSimilarity * 0.20 +
        coverage * 0.25
      ).clamp(0.0, 1.0).toDouble();

      // The canonical text must stand on its own before any curated prior can
      // influence ranking. This makes the documented anti-hallucination rule
      // true in the scoring math, not only in comments.
      if (canonicalEvidence < minPassageScore) continue;

      final intentCompatibility = _intentCompatibility(
        questionIntent,
        sentence.$1 == null
            ? text
            : text.substring(
                sentence.$1!.startOffset,
                sentence.$1!.endOffset,
              ),
      );
      final intentBoost = questionIntent == QuestionIntent.none
          ? 0.0
          : intentCompatibility * 0.06;
      final finalScore = (
        sentenceSemantic * 0.50 +
        wholeSimilarity * 0.20 +
        coverage * 0.20 +
        prior * 0.10 +
        intentBoost
      ).clamp(0.0, 1.0).toDouble();

      values.add(
        OfflineAiPassageMatch(
          passageId: detail.passage.id,
          score: finalScore,
          semanticScore: semantic.clamp(0.0, 1.0).toDouble(),
          coverageScore: coverage.clamp(0.0, 1.0).toDouble(),
          referencePrior: prior,
          canonicalEvidenceScore: canonicalEvidence,
          intentCompatibilityScore: intentCompatibility,
          sentence: sentence.$1,
        ),
      );
    }

    values.sort((a, b) {
      final byScore = b.score.compareTo(a.score);
      return byScore != 0
          ? byScore
          : a.passageId.compareTo(b.passageId);
    });
    return values;
  }

  bool isStrongAnswer(OfflineAiPassageMatch match) =>
      match.canonicalEvidenceScore >= minAnswerEvidenceScore &&
      match.score >= minAnswerScore;

  double _intentCompatibility(
    QuestionIntent intent,
    String sentence,
  ) {
    if (intent == QuestionIntent.none) return 0.0;
    final normalized = normalizer.normalize(sentence);
    if (normalized.isEmpty) return 0.0;

    bool hasAny(Iterable<String> cues) => cues.any(
          (cue) => (' $normalized ').contains(' $cue '),
        );

    return switch (intent) {
      QuestionIntent.why => hasAny(const [
          'parce',
          'parce que',
          'car',
          'cause',
          'raison',
          'puisque',
          'afin',
          'because',
          'reason',
          'therefore',
        ])
          ? 1.0
          : 0.0,
      QuestionIntent.how => hasAny(const [
          'comment',
          'doit',
          'faut',
          'devez',
          'devons',
          'par',
          'ainsi',
          'must',
          'should',
          'by',
          'through',
        ])
          ? 1.0
          : 0.0,
      QuestionIntent.definition => hasAny(const [
          'signifie',
          'veut dire',
          'est',
          'c est',
          'means',
          'is',
          'called',
        ])
          ? 1.0
          : 0.0,
      QuestionIntent.comparison => hasAny(const [
          'mais',
          'tandis',
          'difference',
          'contraire',
          'plutot',
          'whereas',
          'but',
          'rather',
        ])
          ? 1.0
          : 0.0,
      QuestionIntent.condition => hasAny(const [
          'si',
          'quand',
          'lorsque',
          'condition',
          'if',
          'when',
          'unless',
        ])
          ? 1.0
          : 0.0,
      QuestionIntent.who => hasAny(const [
          'celui',
          'ceux',
          'homme',
          'femme',
          'personne',
          'who',
          'man',
          'woman',
          'person',
        ])
          ? 1.0
          : 0.0,
      QuestionIntent.other => 0.0,
      QuestionIntent.none => 0.0,
    };
  }

  Map<int, double> _queryVector(String query) => _normalize(
        _textFeatures(
          normalizer: normalizer,
          dimensions: dimensions,
          text: query,
          wordWeight: 1.0,
          bigramWeight: 0.90,
          subwordWeight: 0.22,
        ),
        idf: _idf,
        unknownIdf: 1.0,
      );

  _PreparedPassage _preparePassage(StudyPassage detail) {
    final passageId = detail.passage.id;
    final cached = _passageCache.remove(passageId);
    if (cached != null) {
      _passageCache[passageId] = cached;
      return cached;
    }

    final text = detail.passage.text;
    final vector = _normalize(
      _textFeatures(
        normalizer: normalizer,
        dimensions: dimensions,
        text: text,
        wordWeight: 1.0,
        bigramWeight: 0.80,
        subwordWeight: 0.18,
      ),
      idf: _idf,
      unknownIdf: 1.0,
    );
    final tokens = normalizer
        .tokens(text, removeStopWords: true)
        .where((token) => !_noise.contains(token))
        .toSet();
    final sentences = <_PreparedSentence>[];
    for (final span in _sentenceSpans(text)) {
      sentences.add(
        _PreparedSentence(
          span: span,
          vector: _normalize(
            _textFeatures(
              normalizer: normalizer,
              dimensions: dimensions,
              text: span.text,
              wordWeight: 1.0,
              bigramWeight: 0.95,
              subwordWeight: 0.20,
            ),
            idf: _idf,
            unknownIdf: 1.0,
          ),
          tokens: Set<String>.unmodifiable(
            normalizer
                .tokens(span.text, removeStopWords: true)
                .where((token) => !_noise.contains(token)),
          ),
        ),
      );
    }

    final prepared = _PreparedPassage(
      vector: Map<int, double>.unmodifiable(vector),
      tokens: Set<String>.unmodifiable(tokens),
      sentences: List<_PreparedSentence>.unmodifiable(sentences),
    );
    _passageCache[passageId] = prepared;
    if (_passageCache.length > _passageCacheLimit) {
      _passageCache.remove(_passageCache.keys.first);
    }
    return prepared;
  }

  (SentenceReference?, double) _bestPreparedSentence({
    required int passageId,
    required _PreparedPassage prepared,
    required Map<int, double> queryVector,
    required Set<String> queryTokens,
  }) {
    if (prepared.sentences.isEmpty) return (null, 0.0);

    _PreparedSentence? best;
    var bestScore = -1.0;

    for (final sentence in prepared.sentences) {
      final semantic = _dot(queryVector, sentence.vector);
      final overlap =
          queryTokens.where(sentence.tokens.contains).length;
      final coverage = queryTokens.isEmpty
          ? 0.0
          : overlap / queryTokens.length;
      final score = semantic * 0.78 + coverage * 0.22;
      if (score > bestScore) {
        bestScore = score;
        best = sentence;
      }
    }

    if (best == null) return (null, 0.0);
    return (
      SentenceReference(
        passageId: passageId,
        startOffset: best.span.start,
        endOffset: best.span.end,
        ordinal: best.span.ordinal,
      ),
      bestScore.clamp(0.0, 1.0).toDouble(),
    );
  }

  static Map<int, double> _referenceFeatures({
    required TextNormalizer normalizer,
    required int dimensions,
    required CuratedSermonReference reference,
    required List<String> topicLabels,
  }) {
    final values = <int, double>{};

    void merge(String text, {
      required double wordWeight,
      required double bigramWeight,
      required double subwordWeight,
      double multiplier = 1.0,
    }) {
      final source = _textFeatures(
        normalizer: normalizer,
        dimensions: dimensions,
        text: text,
        wordWeight: wordWeight,
        bigramWeight: bigramWeight,
        subwordWeight: subwordWeight,
      );
      for (final entry in source.entries) {
        values[entry.key] =
            (values[entry.key] ?? 0) + entry.value * multiplier;
      }
    }

    merge(
      reference.context,
      wordWeight: 1.55,
      bigramWeight: 1.20,
      subwordWeight: 0.28,
    );
    merge(
      reference.anchorTerms.join(' '),
      wordWeight: 1.45,
      bigramWeight: 0.90,
      subwordWeight: 0.22,
    );
    merge(
      reference.sermonTitle,
      wordWeight: 0.75,
      bigramWeight: 0.55,
      subwordWeight: 0.16,
    );
    if (topicLabels.isNotEmpty) {
      merge(
        topicLabels.join(' '),
        wordWeight: 0.85,
        bigramWeight: 0.65,
        subwordWeight: 0.16,
      );
    }
    return values;
  }

  static Map<int, double> _textFeatures({
    required TextNormalizer normalizer,
    required int dimensions,
    required String text,
    required double wordWeight,
    required double bigramWeight,
    required double subwordWeight,
  }) {
    final tokens = normalizer
        .tokens(text, removeStopWords: true)
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
    var total = 0.0;
    for (final entry in small.entries) {
      final other = large[entry.key];
      if (other != null) total += entry.value * other;
    }
    return total;
  }

  static int _hash(String value, int dimensions) {
    var hash = 0x811c9dc5;
    for (final codeUnit in value.codeUnits) {
      hash ^= codeUnit;
      hash = (hash * 0x01000193) & 0xffffffff;
    }
    return hash % dimensions;
  }

  static List<_SentenceSpan> _sentenceSpans(String text) {
    final result = <_SentenceSpan>[];
    var start = 0;
    var ordinal = 0;

    void add(int end) {
      var s = start;
      var e = end;
      while (s < e && text.codeUnitAt(s) <= 32) {
        s++;
      }
      while (e > s && text.codeUnitAt(e - 1) <= 32) {
        e--;
      }
      if (e - s >= 12) {
        result.add(
          _SentenceSpan(
            start: s,
            end: e,
            ordinal: ordinal++,
            text: text.substring(s, e),
          ),
        );
      }
    }

    for (var i = 0; i < text.length; i++) {
      final char = text[i];
      if (char == '.' ||
          char == '!' ||
          char == '?' ||
          char == '…' ||
          char == '\n') {
        add(i + 1);
        start = i + 1;
      }
    }
    if (start < text.length) add(text.length);
    return result;
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

class _PreparedPassage {
  const _PreparedPassage({
    required this.vector,
    required this.tokens,
    required this.sentences,
  });

  final Map<int, double> vector;
  final Set<String> tokens;
  final List<_PreparedSentence> sentences;
}

class _PreparedSentence {
  const _PreparedSentence({
    required this.span,
    required this.vector,
    required this.tokens,
  });

  final _SentenceSpan span;
  final Map<int, double> vector;
  final Set<String> tokens;
}

class _SentenceSpan {
  const _SentenceSpan({
    required this.start,
    required this.end,
    required this.ordinal,
    required this.text,
  });

  final int start;
  final int end;
  final int ordinal;
  final String text;
}
