import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:le_grenier_du_message/src/conversation/conversation_controller.dart';
import 'package:le_grenier_du_message/src/conversation/conversation_models.dart';
import 'package:le_grenier_du_message/src/conversation/conversation_repository.dart';
import 'package:le_grenier_du_message/src/personal/user_database.dart';
import 'package:le_grenier_du_message/src/services/corpus_repository.dart';
import 'package:le_grenier_du_message/src/services/search_service_v4.dart';

class _FakeSearchService extends SearchServiceV4 {
  _FakeSearchService() : super(repository: CorpusRepository());

  ConversationFilterSet? inheritedSeen;
  ConversationFilterSet resolved =
      const ConversationFilterSet(subjectTerms: ['foi'], yearMin: 1960);

  @override
  Future<ResolvedSearchOutcomeV4> searchOutcome(
    String query, {
    ConversationFilterSet inherited = const ConversationFilterSet(),
    int maxResults = 800,
  }) async {
    inheritedSeen = inherited;
    return ResolvedSearchOutcomeV4(
      raw: query,
      filters: resolved,
      hits: const [],
      fuzzySuggestions: const [],
    );
  }

  @override
  List resolvePersisted(Iterable refs, {String query = ''}) => const [];
}

void main() {
  late Directory root;
  late UserDatabase database;
  late ConversationRepository repository;
  late _FakeSearchService searchService;
  late ConversationController controller;

  setUp(() {
    root = Directory.systemTemp.createTempSync('grenier-filter-test-');
    database = UserDatabase.openPath('${root.path}/nested/user.db');
    repository = ConversationRepository(database);
    searchService = _FakeSearchService();
    controller = ConversationController(
      repository: repository,
      searchService: searchService,
    );
  });

  tearDown(() {
    controller.dispose();
    database.close();
    root.deleteSync(recursive: true);
  });

  test('active filters start empty and clear one category at a time', () {
    expect(controller.activeFilters.isEmpty, isTrue);

    controller.setActiveFilters(const ConversationFilterSet(
      subjectTerms: ['mariage'],
      yearMin: 1960,
      yearMax: 1965,
      sourceType: 'sermon',
    ));
    controller.clearPeriodFilter();

    expect(controller.activeFilters.subjectTerms, ['mariage']);
    expect(controller.activeFilters.yearMin, isNull);
    expect(controller.activeFilters.yearMax, isNull);
    expect(controller.activeFilters.sourceType, 'sermon');

    controller.clearSubjectFilter();
    expect(controller.activeFilters.subjectTerms, isEmpty);
    expect(controller.activeFilters.sourceType, 'sermon');

    controller.clearSourceFilter();
    expect(controller.activeFilters.isEmpty, isTrue);
  });

  test('send inherits active filters then adopts resolved filters', () async {
    const initial = ConversationFilterSet(
      subjectTerms: ['mariage'],
      sourceType: 'sermon',
    );
    controller.setActiveFilters(initial);

    await controller.send('après 1960');

    expect(searchService.inheritedSeen?.subjectTerms, initial.subjectTerms);
    expect(searchService.inheritedSeen?.sourceType, 'sermon');
    expect(controller.activeFilters.subjectTerms, ['foi']);
    expect(controller.activeFilters.yearMin, 1960);
    expect(controller.currentFilters.subjectTerms, ['foi']);
  });

  test('loading a conversation restores the latest turn filters', () {
    final id = repository.createConversation('mariage');
    repository.appendTurn(
      conversationId: id,
      query: 'mariage',
      filters: const ConversationFilterSet(subjectTerms: ['mariage']),
      hits: const [],
    );
    repository.appendTurn(
      conversationId: id,
      query: 'après 1960',
      filters: const ConversationFilterSet(
        subjectTerms: ['mariage'],
        yearMin: 1960,
        sourceType: 'sermon',
      ),
      hits: const [],
    );

    controller.loadConversation(id);

    expect(controller.activeFilters.subjectTerms, ['mariage']);
    expect(controller.activeFilters.yearMin, 1960);
    expect(controller.activeFilters.sourceType, 'sermon');
  });
}
