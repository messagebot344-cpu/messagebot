import 'dart:convert';

import 'package:flutter/services.dart';

import 'text_normalizer.dart';

class CuratedSermonReference {
  const CuratedSermonReference({
    required this.id,
    required this.sermonCode,
    required this.sermonTitle,
    required this.locator,
    required this.context,
    required this.anchorTerms,
    required this.sourceIndexId,
    required this.corpusResolved,
    this.unresolvedReason,
  });

  final String id;
  final String sermonCode;
  final String sermonTitle;
  final String locator;
  final String context;
  final List<String> anchorTerms;
  final String sourceIndexId;
  final bool corpusResolved;
  final String? unresolvedReason;
}

class CuratedReferenceTopic {
  const CuratedReferenceTopic({
    required this.id,
    required this.label,
    required this.aliases,
    required this.keywords,
    required this.referenceIds,
    required this.sourceIndexId,
  });

  final String id;
  final String label;
  final List<String> aliases;
  final List<String> keywords;
  final List<String> referenceIds;
  final String sourceIndexId;
}

class CuratedTopicMatch {
  const CuratedTopicMatch({
    required this.topic,
    required this.score,
  });

  final CuratedReferenceTopic topic;
  final double score;
}

class CuratedSearchHint {
  const CuratedSearchHint({
    required this.reference,
    required this.topicLabel,
    required this.matchScore,
  });

  final CuratedSermonReference reference;
  final String topicLabel;
  final double matchScore;
}

/// Human-curated routing hints layered above the immutable canonical corpus.
///
/// The index is intentionally incapable of supplying quotation text. It only
/// suggests sermon codes and anchor terms; SearchCoordinatorV4 still resolves
/// every displayed result from corpus.db.
class CuratedReferenceIndex {
  CuratedReferenceIndex({
    required this.references,
    required this.topics,
    this.normalizer = const TextNormalizer(),
  });

  final Map<String, CuratedSermonReference> references;
  final List<CuratedReferenceTopic> topics;
  final TextNormalizer normalizer;

  static const String defaultManifestPath =
      'assets/curated/manifest.json';

  static Future<CuratedReferenceIndex> loadAsset({
    String manifestPath = defaultManifestPath,
    AssetBundle? bundle,
  }) async {
    final assets = bundle ?? rootBundle;
    final manifestRaw = await assets.loadString(manifestPath);
    final manifest = jsonDecode(manifestRaw);
    if (manifest is! Map<String, dynamic> ||
        manifest['schema_version'] != 1) {
      throw const FormatException(
        'Manifest de références thématiques invalide.',
      );
    }

    final files = (manifest['files'] as List? ?? const [])
        .whereType<String>()
        .toList(growable: false);
    if (files.isEmpty) {
      return CuratedReferenceIndex(
        references: const {},
        topics: const [],
      );
    }

    final payloads = <Map<String, dynamic>>[];
    for (final path in files) {
      final raw = jsonDecode(await assets.loadString(path));
      if (raw is! Map<String, dynamic>) {
        throw FormatException(
          'Index de références thématiques invalide: $path',
        );
      }
      payloads.add(raw);
    }
    return CuratedReferenceIndex.fromPayloads(payloads);
  }

  factory CuratedReferenceIndex.fromPayloads(
    Iterable<Map<String, dynamic>> payloads,
  ) {
    final refs = <String, CuratedSermonReference>{};
    final topics = <CuratedReferenceTopic>[];

    for (final payload in payloads) {
      if (payload['schema_version'] != 1) {
        throw const FormatException(
          'Version de schéma de référence non supportée.',
        );
      }
      final indexId = payload['index_id'] as String?;
      if (indexId == null || indexId.trim().isEmpty) {
        throw const FormatException('index_id manquant.');
      }

      for (final raw in (payload['references'] as List? ?? const [])) {
        if (raw is! Map) continue;
        final map = Map<String, dynamic>.from(raw);
        final reference = CuratedSermonReference(
          id: _requiredString(map, 'id'),
          sermonCode: _requiredString(map, 'sermon_code'),
          sermonTitle: _requiredString(map, 'sermon_title'),
          locator: _requiredString(map, 'locator'),
          context: _requiredString(map, 'context'),
          anchorTerms: _stringList(map['anchor_terms']),
          sourceIndexId: indexId,
          corpusResolved:
              (map['corpus_status'] as String? ?? 'resolved') == 'resolved',
          unresolvedReason: map['unresolved_reason'] as String?,
        );
        if (reference.anchorTerms.isEmpty) {
          throw FormatException(
            'anchor_terms manquant pour ${reference.id}.',
          );
        }
        if (refs.containsKey(reference.id)) {
          throw FormatException(
            'Référence thématique dupliquée: ${reference.id}.',
          );
        }
        refs[reference.id] = reference;
      }

      for (final raw in (payload['topics'] as List? ?? const [])) {
        if (raw is! Map) continue;
        final map = Map<String, dynamic>.from(raw);
        final topic = CuratedReferenceTopic(
          id: _requiredString(map, 'id'),
          label: _requiredString(map, 'label'),
          aliases: _stringList(map['aliases']),
          keywords: _stringList(map['keywords']),
          referenceIds: _stringList(map['reference_ids']),
          sourceIndexId: indexId,
        );
        if (topic.aliases.isEmpty ||
            topic.referenceIds.isEmpty) {
          throw FormatException(
            'Topic thématique incomplet: ${topic.id}.',
          );
        }
        topics.add(topic);
      }
    }

    for (final topic in topics) {
      for (final id in topic.referenceIds) {
        if (!refs.containsKey(id)) {
          throw FormatException(
            'Référence inconnue $id dans le topic ${topic.id}.',
          );
        }
      }
    }

    return CuratedReferenceIndex(
      references: Map.unmodifiable(refs),
      topics: List.unmodifiable(topics),
    );
  }

  List<CuratedTopicMatch> matchTopics(
    String query, {
    int limit = 6,
  }) {
    final normalizedQuery = normalizer.normalize(query);
    if (normalizedQuery.isEmpty) return const [];

    final queryTokens = _semanticTokens(query);
    final matches = <CuratedTopicMatch>[];

    for (final topic in topics) {
      var score = 0.0;
      var exactAlias = false;

      for (final alias in topic.aliases) {
        final normalizedAlias = normalizer.normalize(alias);
        if (normalizedAlias.isEmpty) continue;
        if (_containsPhrase(normalizedQuery, normalizedAlias)) {
          exactAlias = true;
          final aliasTokens = _semanticTokens(alias).toList(growable: false);
          score = score < 5.0 + aliasTokens.length * 0.15
              ? 5.0 + aliasTokens.length * 0.15
              : score;
          continue;
        }

        final aliasTokens = _semanticTokens(alias);
        if (aliasTokens.length >= 2) {
          final overlap =
              aliasTokens.where(queryTokens.contains).length;
          if (overlap >= 2) {
            final candidate =
                1.5 + (overlap / aliasTokens.length) * 2.0;
            if (candidate > score) score = candidate;
          }
        }
      }

      final keywordTokens = topic.keywords
          .expand(_semanticTokens)
          .toSet();
      final keywordHits =
          keywordTokens.where(queryTokens.contains).length;
      score += keywordHits * 0.70;

      // A broad topic must not activate from one generic word unless that
      // word is itself a deliberately registered exact alias.
      if (!exactAlias && keywordHits < 2 && score < 3.0) {
        continue;
      }
      if (score < 2.5) continue;

      matches.add(CuratedTopicMatch(topic: topic, score: score));
    }

    matches.sort((a, b) {
      final byScore = b.score.compareTo(a.score);
      return byScore != 0
          ? byScore
          : a.topic.id.compareTo(b.topic.id);
    });
    return matches.take(limit).toList(growable: false);
  }

  List<CuratedSearchHint> searchHints(
    String query, {
    int topicLimit = 6,
    int referenceLimit = 12,
  }) {
    final matches = matchTopics(query, limit: topicLimit);
    if (matches.isEmpty) return const [];

    final queryTokens = _semanticTokens(query);
    final normalizedQuery = normalizer.normalize(query);
    final best = <String, CuratedSearchHint>{};

    for (final match in matches) {
      for (var position = 0;
          position < match.topic.referenceIds.length;
          position++) {
        final id = match.topic.referenceIds[position];
        final reference = references[id];
        if (reference == null || !reference.corpusResolved) continue;

        final referenceText = [
          reference.context,
          reference.sermonTitle,
          ...reference.anchorTerms,
        ].join(' ');
        final referenceTokens = _semanticTokens(referenceText);
        final overlap = queryTokens
            .where(referenceTokens.contains)
            .length;

        // A source can contain hundreds of manually curated references.
        // Rank the individual reference by the user's wording instead of
        // always preferring the first entries in the fascicle.
        var referenceBoost = overlap * 0.75;
        final normalizedContext =
            normalizer.normalize(reference.context);
        if (normalizedContext.isNotEmpty &&
            _containsPhrase(normalizedQuery, normalizedContext)) {
          referenceBoost += 2.0;
        }

        // Position is only a deterministic tie-breaker now; it must never
        // drown a deep but much more relevant human-validated reference.
        final score =
            match.score + referenceBoost - position * 0.002;
        final previous = best[id];
        if (previous == null || score > previous.matchScore) {
          best[id] = CuratedSearchHint(
            reference: reference,
            topicLabel: match.topic.label,
            matchScore: score,
          );
        }
      }
    }

    final values = best.values.toList(growable: false)
      ..sort((a, b) {
        final byScore = b.matchScore.compareTo(a.matchScore);
        return byScore != 0
            ? byScore
            : a.reference.id.compareTo(b.reference.id);
      });
    return values.take(referenceLimit).toList(growable: false);
  }

  Set<String> _semanticTokens(String value) => normalizer
      .tokens(value, removeStopWords: true)
      .where((token) => !_routingNoise.contains(token))
      .toSet();

  static const Set<String> _routingNoise = <String>{
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

  static bool _containsPhrase(String query, String phrase) {
    if (query == phrase) return true;
    return (' $query ').contains(' $phrase ');
  }

  static String _requiredString(
    Map<String, dynamic> map,
    String key,
  ) {
    final value = map[key];
    if (value is! String || value.trim().isEmpty) {
      throw FormatException('Champ obligatoire manquant: $key');
    }
    return value.trim();
  }

  static List<String> _stringList(Object? raw) =>
      (raw as List? ?? const [])
          .whereType<String>()
          .map((value) => value.trim())
          .where((value) => value.isNotEmpty)
          .toList(growable: false);
}
