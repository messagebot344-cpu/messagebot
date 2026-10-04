import '../conversation/conversation_models.dart';
import '../models/models.dart';
import '../search/search_contracts.dart';
import '../services/corpus_repository.dart';
import 'canonical_sentence_locator.dart';
import 'conceptual_query_expander.dart';
import 'deterministic_hybrid_ranker.dart';
import 'exact_phrase_engine.dart';
import 'fuzzy_term_matcher.dart';
import 'morphology_engine.dart';
import 'proximity_search_engine.dart';
import 'query_parser_v4.dart';
import 'retrieval_bundle.dart';
import 'search_explanation.dart';
import 'text_normalizer.dart';

class SearchOutcomeV4 {
  const SearchOutcomeV4({
    required this.query,
    required this.references,
    required this.explanations,
    this.fuzzySuggestions = const <String>[],
  });

  final QuerySpecV4 query;
  final List<PassageReference> references;
  final Map<int, SearchExplanationV4> explanations;
  final List<String> fuzzySuggestions;
}

class SearchCoordinatorV4 {
  SearchCoordinatorV4({
    required this.repository,
    this.parser = const QueryParserV4(),
    this.normalizer = const TextNormalizer(),
    this.morphology = const MorphologyEngine(),
    this.fuzzyMatcher = const FuzzyTermMatcher(),
    this.ranker = const DeterministicHybridRanker(),
    this.sentenceLocator = const CanonicalSentenceLocator(),
  })  : exactEngine = ExactPhraseEngine(repository),
        proximityEngine = ProximitySearchEngine(repository),
        conceptualExpander = ConceptualQueryExpander(repository);

  final CorpusRepository repository;
  final QueryParserV4 parser;
  final TextNormalizer normalizer;
  final MorphologyEngine morphology;
  final FuzzyTermMatcher fuzzyMatcher;
  final DeterministicHybridRanker ranker;
  final CanonicalSentenceLocator sentenceLocator;
  final ExactPhraseEngine exactEngine;
  final ProximitySearchEngine proximityEngine;
  final ConceptualQueryExpander conceptualExpander;

  Future<SearchOutcomeV4> search(
    String raw, {
    ConversationFilterSet inherited = const ConversationFilterSet(),
    int maxResults = 800,
  }) async {
    final spec = parser.parse(raw, inherited: inherited);
    if (spec.isEmpty || spec.subjectTerms.isEmpty && spec.sermonCode == null) {
      return SearchOutcomeV4(query: spec, references: const [], explanations: const {});
    }

    const candidateLimit = 1800;
    final conceptual = conceptualExpander.expand(spec);
    final tokens = conceptual.focusTerms.take(12).toList(growable: false);
    final effectiveSpec = QuerySpecV4(
      raw: spec.raw,
      normalized: spec.normalized,
      subjectTerms: tokens,
      filters: ConversationFilterSet(
        subjectTerms: tokens,
        yearMin: spec.filters.yearMin,
        yearMax: spec.filters.yearMax,
        sourceType: spec.filters.sourceType,
        sourceId: spec.filters.sourceId,
      ),
      exactPhrase: spec.exactPhrase,
      sermonCode: spec.sermonCode,
    );
    final strongQuery = _quoted(tokens, ' AND ');
    final broadQuery = _quoted(tokens, ' OR ');
    final prefixQuery = tokens.take(8).map((e) => '${_safeToken(e)}*').join(' OR ');

    final direct = <int>{
      if (spec.sermonCode != null) ...repository.titleOrCodeMatches(spec.sermonCode!, limit: 40),
      ...repository.sourceTitleMatches(
        spec.raw,
        sourceType: spec.filters.sourceType == 'book'
            ? CorpusSourceType.book
            : spec.filters.sourceType == 'sermon'
                ? CorpusSourceType.sermon
                : null,
        limit: 40,
      ),
    }.toList(growable: false);

    final exact = spec.exactPhrase == null
        ? const <RankedPassage>[]
        : exactEngine.search(effectiveSpec, limit: candidateLimit);
    final proximity = tokens.length < 2
        ? const <RankedPassage>[]
        : proximityEngine.search(effectiveSpec, limit: candidateLimit);
    final strong = strongQuery.isEmpty ? const <RankedPassage>[] : _search(effectiveSpec, strongQuery, candidateLimit);
    final broad = broadQuery.isEmpty ? const <RankedPassage>[] : _search(effectiveSpec, broadQuery, candidateLimit);
    final prefix = prefixQuery.isEmpty ? const <RankedPassage>[] : _search(effectiveSpec, prefixQuery, 900);

    final morphologyTerms = <String>{};
    for (final token in tokens) {
      morphologyTerms.addAll(morphology.expandSafe(token));
    }
    morphologyTerms.removeAll(tokens);
    final morphologyQuery = morphologyTerms.take(16).map((e) => '"${e.replaceAll('"', '""')}"').join(' OR ');
    final morphHits = morphologyQuery.isEmpty ? const <RankedPassage>[] : _search(effectiveSpec, morphologyQuery, 900);

    final conceptualTerms = conceptual.relatedTerms;
    final conceptualQuery = conceptualTerms
        .take(12)
        .map((e) => '"${e.replaceAll('"', '""')}"')
        .join(' OR ');
    final conceptualHits = conceptualQuery.isEmpty
        ? const <RankedPassage>[]
        : _search(effectiveSpec, conceptualQuery, 700);

    final fuzzyTerms = <String>[];
    for (final token in tokens.where((e) => e.length >= 4)) {
      final needle = token.length >= 4 ? token.substring(0, 3) : token;
      final candidates = repository.searchTermStats(needle, limit: 80);
      final suggestion = fuzzyMatcher.best(token, candidates);
      if (suggestion != null && !tokens.contains(suggestion.term)) fuzzyTerms.add(suggestion.term);
    }
    final fuzzyQuery = fuzzyTerms.toSet().take(12).map((e) => '"${e.replaceAll('"', '""')}"').join(' OR ');
    final fuzzyHits = fuzzyQuery.isEmpty ? const <RankedPassage>[] : _search(effectiveSpec, fuzzyQuery, 700);
    final alternate = strongQuery.isEmpty || effectiveSpec.filters.sourceType == 'book'
        ? const <RankedPassage>[]
        : repository.lexicalSearchAlternates(strongQuery, limit: 500);

    final ranked = ranker.rank(
      RetrievalBundleV4(
        direct: direct,
        exact: exact,
        proximity: proximity,
        strong: strong,
        broad: broad,
        prefix: prefix,
        morphology: morphHits,
        conceptual: conceptualHits,
        fuzzy: fuzzyHits,
        alternate: alternate,
      ),
      fuzzyTerms: fuzzyTerms,
      conceptualTerms: conceptualTerms,
    );
    if (ranked.isEmpty) {
      return SearchOutcomeV4(query: effectiveSpec, references: const [], explanations: const {}, fuzzySuggestions: fuzzyTerms);
    }

    final topScore = ranked.first.score;
    final threshold = topScore * 0.12;
    final candidates = ranked.where((e) => e.score >= threshold).take(maxResults * 4).toList(growable: false);
    final details = repository.studyDetailsForPassageIds(candidates.map((e) => e.passageId));
    final primarySermons = <int>{
      for (final item in candidates)
        if (details[item.passageId]?.edition?.isPrimary == true && details[item.passageId]?.sermon != null)
          details[item.passageId]!.sermon!.id,
    };

    final refs = <PassageReference>[];
    final explanations = <int, SearchExplanationV4>{};
    final seen = <int>{};
    for (final candidate in candidates) {
      if (refs.length >= maxResults) break;
      if (!seen.add(candidate.passageId)) continue;
      final detail = details[candidate.passageId];
      if (detail == null || !_matchesFilters(effectiveSpec.filters, detail)) continue;
      if (detail.edition != null && !detail.edition!.isPrimary && detail.sermon != null && primarySermons.contains(detail.sermon!.id)) {
        continue;
      }
      final explanation = candidate.explanation;
      refs.add(PassageReference(
        passageId: candidate.passageId,
        editionId: detail.edition?.id ?? detail.source.id,
        sermonId: detail.sermon?.id ?? 0,
        score: candidate.score,
        evidence: SearchEvidence(
          direct: explanation.direct,
          exact: explanation.exactPhrase,
          alternateEdition: explanation.alternateEdition,
        ),
        sentence: sentenceLocator.locate(
          candidate.passageId,
          detail.passage.text,
          <String>[...tokens, ...conceptualTerms.take(4)].join(' '),
        ),
      ));
      explanations[candidate.passageId] = explanation;
    }

    return SearchOutcomeV4(
      query: effectiveSpec,
      references: refs,
      explanations: explanations,
      fuzzySuggestions: fuzzyTerms.toSet().toList(growable: false),
    );
  }

  List<RankedPassage> _search(QuerySpecV4 spec, String fts, int limit) {
    if (spec.filters.sourceType == 'book') return repository.lexicalSearchBooks(fts, limit: limit);
    if (spec.filters.sourceType == 'sermon') return repository.lexicalSearch(fts, limit: limit);
    return repository.lexicalSearchAll(fts, limit: limit);
  }

  String _quoted(List<String> tokens, String joiner) => tokens
      .where((e) => e.isNotEmpty)
      .map((e) => '"${e.replaceAll('"', '""')}"')
      .join(joiner);

  String _safeToken(String value) => value.replaceAll(RegExp(r'[^a-z0-9_-]'), '');

  bool _matchesFilters(ConversationFilterSet filters, StudyPassage detail) {
    if (filters.sourceType == 'book' && detail.source.type != CorpusSourceType.book) return false;
    if (filters.sourceType == 'sermon' && detail.source.type != CorpusSourceType.sermon) return false;
    if (filters.sourceId != null && detail.source.id != filters.sourceId) return false;
    if (filters.yearMin != null || filters.yearMax != null) {
      final year = detail.sermon?.year ?? detail.source.year;
      if (year == null) return false;
      if (filters.yearMin != null && year < filters.yearMin!) return false;
      if (filters.yearMax != null && year > filters.yearMax!) return false;
    }
    return true;
  }
}
