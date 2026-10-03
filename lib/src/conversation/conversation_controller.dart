import 'package:flutter/foundation.dart';

import '../models/models.dart';
import '../search_v4/search_explanation.dart';
import '../services/search_service_v4.dart';
import 'conversation_models.dart';
import 'conversation_repository.dart';

class ConversationTurnView {
  const ConversationTurnView({
    required this.record,
    required this.hits,
    required this.explanations,
    this.fuzzySuggestions = const <String>[],
  });

  final ConversationTurnRecord record;
  final List<DocumentSearchHit> hits;
  final Map<int, SearchExplanationV4> explanations;
  final List<String> fuzzySuggestions;
}

class ConversationController extends ChangeNotifier {
  ConversationController({required this.repository, required this.searchService}) {
    refreshConversations(notify: false);
  }

  final ConversationRepository repository;
  final SearchServiceV4 searchService;

  int? _conversationId;
  bool _searching = false;
  List<ConversationTurnView> _turns = const [];
  List<ConversationSummary> _conversations = const [];
  String _conversationSearch = '';

  int? get conversationId => _conversationId;
  bool get searching => _searching;
  List<ConversationTurnView> get turns => _turns;
  List<ConversationSummary> get conversations => _conversations;
  bool get hasConversation => _conversationId != null;
  ConversationFilterSet get currentFilters => _turns.isEmpty ? const ConversationFilterSet() : _turns.last.record.filters;

  void startNewConversation() {
    _conversationId = null;
    _turns = const [];
    notifyListeners();
  }

  Future<void> send(String raw) async {
    if (_searching) return;
    final parsed = searchService.coordinator.parser.parse(raw, inherited: currentFilters);
    if (parsed.isEmpty) return;
    _searching = true;
    notifyListeners();
    try {
      final outcome = await searchService.searchOutcome(raw, inherited: currentFilters, maxResults: 800);
      var id = _conversationId;
      if (id == null) {
        id = repository.createConversation(raw);
        _conversationId = id;
      }
      final refs = <PersistedHitRef>[
        for (var i = 0; i < outcome.hits.length; i++)
          PersistedHitRef(
            passageId: outcome.hits[i].hit.studyPassage.passage.id,
            rank: i + 1,
            score: outcome.hits[i].hit.score,
          ),
      ];
      final turnId = repository.appendTurn(
        conversationId: id,
        query: raw.trim(),
        filters: outcome.filters,
        hits: refs,
      );
      final record = ConversationTurnRecord(
        id: turnId,
        conversationId: id,
        query: raw.trim(),
        filters: outcome.filters,
        createdAt: DateTime.now().millisecondsSinceEpoch,
        hits: refs,
      );
      final explanationById = <int, SearchExplanationV4>{
        for (final value in outcome.hits) value.hit.studyPassage.passage.id: value.explanation,
      };
      _turns = [
        ..._turns,
        ConversationTurnView(
          record: record,
          hits: outcome.hits.map((e) => e.hit).toList(growable: false),
          explanations: explanationById,
          fuzzySuggestions: outcome.fuzzySuggestions,
        ),
      ];
      refreshConversations(notify: false);
    } finally {
      _searching = false;
      notifyListeners();
    }
  }

  void loadConversation(int id) {
    final records = repository.loadConversation(id);
    _conversationId = id;
    _turns = records.map((record) => ConversationTurnView(
      record: record,
      hits: searchService.resolvePersisted(record.hits, query: record.query),
      explanations: const <int, SearchExplanationV4>{},
    )).toList(growable: false);
    notifyListeners();
  }

  void setExpanded(int turnId, int passageId, bool expanded) {
    repository.setHitExpanded(turnId, passageId, expanded);
    _turns = _turns.map((turn) {
      if (turn.record.id != turnId) return turn;
      final hits = turn.record.hits.map((hit) => hit.passageId == passageId
          ? PersistedHitRef(passageId: hit.passageId, rank: hit.rank, score: hit.score, expanded: expanded)
          : hit).toList(growable: false);
      return ConversationTurnView(
        record: ConversationTurnRecord(
          id: turn.record.id,
          conversationId: turn.record.conversationId,
          query: turn.record.query,
          filters: turn.record.filters,
          createdAt: turn.record.createdAt,
          hits: hits,
        ),
        hits: turn.hits,
        explanations: turn.explanations,
        fuzzySuggestions: turn.fuzzySuggestions,
      );
    }).toList(growable: false);
    notifyListeners();
  }

  void renameCurrent(String title) {
    final id = _conversationId;
    if (id == null) return;
    repository.renameConversation(id, title);
    refreshConversations();
  }

  void deleteConversation(int id) {
    repository.deleteConversation(id);
    if (_conversationId == id) startNewConversation();
    refreshConversations();
  }

  void togglePin(int id, bool pinned) {
    repository.pinConversation(id, pinned);
    refreshConversations();
  }

  void setConversationSearch(String value) {
    _conversationSearch = value;
    refreshConversations();
  }

  void refreshConversations({bool notify = true}) {
    _conversations = repository.listConversations(search: _conversationSearch);
    if (notify) notifyListeners();
  }
}
