import '../services/corpus_repository.dart';
import '../study_v4/term_association_engine.dart';
import 'query_parser_v4.dart';
import 'text_normalizer.dart';

class ConceptualExpansion {
  const ConceptualExpansion({
    required this.questionLike,
    required this.focusTerms,
    required this.relatedTerms,
  });

  final bool questionLike;
  final List<String> focusTerms;
  final List<String> relatedTerms;
}

class ConceptualQueryExpander {
  ConceptualQueryExpander(
    this.repository, {
    this.normalizer = const TextNormalizer(),
    this.useCorpusAssociations = true,
  }) : associationEngine = TermAssociationEngine(repository);

  final CorpusRepository repository;
  final TextNormalizer normalizer;
  final TermAssociationEngine associationEngine;
  final bool useCorpusAssociations;
  final Map<String, List<String>> _associationCache = <String, List<String>>{};

  ConceptualExpansion expand(QuerySpecV4 spec) {
    final normalized = normalizer.normalize(spec.raw);
    final questionLike = spec.raw.contains('?') ||
        RegExp(
          r'^(comment|pourquoi|quel|quelle|quels|quelles|que|quoi|qui|quand|ou|est ce|peut on|doit on|faut il|parle moi|dis moi|explique moi|montre moi|je veux savoir|je cherche)\b',
        ).hasMatch(normalized);

    final focus = <String>[];
    final seen = <String>{};
    for (final term in spec.subjectTerms) {
      if (questionLike && _questionNoise.contains(term)) continue;
      if (seen.add(term)) focus.add(term);
    }

    final related = <String>{};
    if (questionLike) {
      for (final term in focus) {
        for (final group in _conceptGroups) {
          if (group.contains(term)) {
            related.addAll(group);
          }
        }
      }
    }

    if (questionLike && useCorpusAssociations) {
      for (final term in focus.take(3)) {
        related.addAll(_associatedTerms(term));
      }
    }

    related
      ..removeAll(focus)
      ..removeWhere((term) => term.length < 3 || _questionNoise.contains(term));

    return ConceptualExpansion(
      questionLike: questionLike,
      focusTerms: focus.isEmpty ? spec.subjectTerms : focus,
      relatedTerms: related.take(12).toList(growable: false),
    );
  }

  List<String> _associatedTerms(String term) {
    return _associationCache.putIfAbsent(term, () {
      final values = associationEngine.related(term, limit: 10);
      return values
          .where((value) => value.count >= 3)
          .map((value) => value.term)
          .where((value) => value.length >= 4 && !_questionNoise.contains(value))
          .take(4)
          .toList(growable: false);
    });
  }

  static const _questionNoise = <String>{
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
    'pouvons',
    'doit',
    'dois',
    'faut',
    'est',
    'sont',
    'etre',
    'avoir',
    'faire',
    'dit',
    'dire',
    'parle',
    'parler',
    'explique',
    'expliquer',
    'montre',
    'montrer',
    'trouve',
    'trouver',
    'concerne',
    'concernant',
    'propos',
    'signifie',
    'signification',
    'prophete',
    'frere',
    'branham',
    'message',
  };

  static const _conceptGroups = <Set<String>>[
    {'foi', 'croire', 'croyance', 'confiance'},
    {'salut', 'sauver', 'sauve', 'redemption', 'racheter', 'rachete'},
    {'guerison', 'guerir', 'gueri', 'maladie', 'malade', 'sante'},
    {'priere', 'prier', 'intercession', 'demande'},
    {'bapteme', 'baptiser', 'baptise', 'immersion'},
    {'esprit', 'pentecote', 'onction', 'saint-esprit'},
    {'mariage', 'epoux', 'epouse', 'mari', 'femme', 'union', 'divorce'},
    {'dime', 'dixieme', 'offrande', 'donner'},
    {'communion', 'cene', 'souper'},
    {'predestination', 'predestine', 'election', 'elu'},
    {'grace', 'misericorde', 'pardon'},
    {'peche', 'iniquite', 'transgression'},
    {'resurrection', 'ressusciter', 'ressuscite'},
  ];
}
