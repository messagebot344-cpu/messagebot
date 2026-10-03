import 'dart:convert';
import 'dart:math' as math;
import 'dart:typed_data';

import 'package:flutter/services.dart';

class SemanticHit {
  const SemanticHit(this.passageId, this.score);
  final int passageId;
  final double score;
}

class SemanticIndex {
  Map<String, int> _termToIndex = const {};
  Set<String> _stopwords = const {};
  Float32List _idf = Float32List(0);
  Float32List _components = Float32List(0);
  Float32List _vectors = Float32List(0);
  Int32List _passageIds = Int32List(0);
  int _dimensions = 0;
  int _features = 0;

  int get dimensions => _dimensions;
  int get documentCount => _passageIds.length;

  Future<void> load() async {
    final vocab = jsonDecode(
      await rootBundle.loadString('assets/corpus/semantic_vocab.json'),
    ) as Map<String, dynamic>;
    final terms = (vocab['terms'] as List).cast<String>();
    final idfValues = (vocab['idf'] as List).cast<num>();
    _dimensions = vocab['dimensions'] as int;
    _stopwords = ((vocab['stopwords'] as List?) ?? const []).cast<String>().toSet();
    _features = terms.length;
    _termToIndex = <String, int>{
      for (var i = 0; i < terms.length; i++) terms[i]: i,
    };
    _idf = Float32List.fromList(idfValues.map((e) => e.toDouble()).toList());
    _components = _asFloat32(
      await rootBundle.load('assets/corpus/semantic_components.f32'),
    );
    _vectors = _asFloat32(
      await rootBundle.load('assets/corpus/semantic_vectors.f32'),
    );
    _passageIds = _asInt32(
      await rootBundle.load('assets/corpus/semantic_passage_ids.i32'),
    );
    if (_components.length != _dimensions * _features) {
      throw StateError('Modèle sémantique incohérent (composantes).');
    }
    if (_vectors.length != _passageIds.length * _dimensions) {
      throw StateError('Modèle sémantique incohérent (vecteurs).');
    }
  }

  Float32List _asFloat32(ByteData data) {
    final bytes = Uint8List.fromList(
      data.buffer.asUint8List(data.offsetInBytes, data.lengthInBytes),
    );
    return Float32List.view(bytes.buffer);
  }

  Int32List _asInt32(ByteData data) {
    final bytes = Uint8List.fromList(
      data.buffer.asUint8List(data.offsetInBytes, data.lengthInBytes),
    );
    return Int32List.view(bytes.buffer);
  }

  String normalize(String input) {
    var s = input.toLowerCase();
    const replacements = <String, String>{
      'à': 'a', 'á': 'a', 'â': 'a', 'ä': 'a', 'ã': 'a', 'å': 'a',
      'ç': 'c', 'è': 'e', 'é': 'e', 'ê': 'e', 'ë': 'e',
      'ì': 'i', 'í': 'i', 'î': 'i', 'ï': 'i',
      'ñ': 'n', 'ò': 'o', 'ó': 'o', 'ô': 'o', 'ö': 'o', 'õ': 'o',
      'ù': 'u', 'ú': 'u', 'û': 'u', 'ü': 'u', 'ý': 'y', 'ÿ': 'y',
      'œ': 'oe', 'æ': 'ae', '’': "'", '‘': "'",
    };
    replacements.forEach((from, to) => s = s.replaceAll(from, to));
    return RegExp(r'[a-z0-9]+')
        .allMatches(s)
        .map((m) => m.group(0)!)
        .where((t) => t.length >= 2 && !_stopwords.contains(t))
        .join(' ');
  }

  List<String> tokens(String input) {
    final n = normalize(input);
    return n.isEmpty ? const [] : n.split(' ');
  }

  int knownTokenCount(String input) {
    return tokens(input).where(_termToIndex.containsKey).length;
  }

  double knownTokenCoverage(String input) {
    final queryTokens = tokens(input);
    if (queryTokens.isEmpty) return 0;
    final known = queryTokens.where(_termToIndex.containsKey).length;
    return known / queryTokens.length;
  }

  List<String> unknownTokens(String input) {
    return tokens(input)
        .where((token) => !_termToIndex.containsKey(token))
        .toSet()
        .toList(growable: false);
  }

  Float32List encode(String input) {
    final ts = tokens(input);
    if (ts.isEmpty || _dimensions == 0) return Float32List(_dimensions);
    final counts = <int, double>{};
    for (final token in ts) {
      final index = _termToIndex[token];
      if (index != null) counts[index] = (counts[index] ?? 0) + 1;
    }
    if (counts.isEmpty) return Float32List(_dimensions);

    var tfidfNorm2 = 0.0;
    final weights = <int, double>{};
    counts.forEach((index, count) {
      final w = (1 + math.log(count)) * _idf[index];
      weights[index] = w;
      tfidfNorm2 += w * w;
    });
    final tfidfNorm = math.sqrt(tfidfNorm2);
    if (tfidfNorm == 0) return Float32List(_dimensions);

    final out = Float32List(_dimensions);
    for (var d = 0; d < _dimensions; d++) {
      var sum = 0.0;
      final base = d * _features;
      weights.forEach((index, weight) {
        sum += (weight / tfidfNorm) * _components[base + index];
      });
      out[d] = sum;
    }
    _normalizeVector(out);
    return out;
  }

  List<SemanticHit> search(String query, {int limit = 80}) {
    final q = encode(query);
    if (_norm2(q) == 0) return const [];
    final best = <SemanticHit>[];
    for (var row = 0; row < _passageIds.length; row++) {
      final offset = row * _dimensions;
      var score = 0.0;
      for (var d = 0; d < _dimensions; d++) {
        score += q[d] * _vectors[offset + d];
      }
      if (best.length < limit) {
        best.add(SemanticHit(_passageIds[row], score));
      } else {
        var minIndex = 0;
        var minScore = best[0].score;
        for (var i = 1; i < best.length; i++) {
          if (best[i].score < minScore) {
            minScore = best[i].score;
            minIndex = i;
          }
        }
        if (score > minScore) best[minIndex] = SemanticHit(_passageIds[row], score);
      }
    }
    best.sort((a, b) => b.score.compareTo(a.score));
    return best;
  }

  String bestSentence(String text, String query) {
    final sentences = _splitSentences(text);
    if (sentences.isEmpty) return text.trim();

    final queryTokens = tokens(query).toSet();
    final q = encode(query);
    final semanticAvailable = _norm2(q) > 0;
    String? best;
    var bestScore = -double.infinity;

    for (final sentence in sentences) {
      if (sentence.trim().length < 12 || _isEditorialSentence(sentence)) continue;
      final sentenceTokens = tokens(sentence).toSet();
      final overlap = queryTokens.isEmpty
          ? 0.0
          : sentenceTokens.where(queryTokens.contains).length / queryTokens.length;

      var semanticScore = 0.0;
      if (semanticAvailable) {
        final v = encode(sentence);
        for (var i = 0; i < _dimensions; i++) {
          semanticScore += q[i] * v[i];
        }
      }

      // Exact lexical overlap gets a small boost while the semantic score
      // remains the main signal. The returned value is always an existing
      // sentence from the corpus; nothing is generated or rewritten.
      final score = semanticScore + (overlap * 0.35);
      if (score > bestScore) {
        bestScore = score;
        best = sentence;
      }
    }
    return (best ?? sentences.first).trim();
  }

  bool _isEditorialSentence(String sentence) {
    final value = sentence.toLowerCase();
    const markers = <String>[
      'www.branham.fr',
      'www.branham.ru',
      'shekinah publications',
      'shekinahgospelmissions',
      'exemplaires supplémentaires',
      'exemplaires supplementaires',
      'ce texte est la version française du message oral',
      'ce texte est la version francaise du message oral',
      'la traduction de ce sermon',
      'veuillez trouver les autres prédications',
      'veuillez trouver les autres predications',
      'central africa',
      'b.p. 10. 493',
      'pasteurdick@',
      'shekinahmission@',
    ];
    return markers.any(value.contains);
  }

  List<String> _splitSentences(String text) {
    final clean = text.replaceAll(RegExp(r'\s+'), ' ').trim();
    if (clean.isEmpty) return const [];
    final result = <String>[];
    var start = 0;
    for (var i = 0; i < clean.length; i++) {
      final c = clean[i];
      if (c == '.' || c == '!' || c == '?' || c == '…') {
        final end = i + 1;
        if (end - start >= 12) result.add(clean.substring(start, end).trim());
        start = end;
      }
    }
    if (start < clean.length) result.add(clean.substring(start).trim());
    return result.where((s) => s.isNotEmpty).toList(growable: false);
  }

  void _normalizeVector(Float32List v) {
    final n = math.sqrt(_norm2(v));
    if (n == 0) return;
    for (var i = 0; i < v.length; i++) v[i] /= n;
  }

  double _norm2(Float32List v) {
    var total = 0.0;
    for (final x in v) total += x * x;
    return total;
  }
}
