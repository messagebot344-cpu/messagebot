import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  test('la conversation limite le volume de résultats à persister', () {
    final source =
        File('lib/src/conversation/conversation_controller.dart')
            .readAsStringSync();

    expect(source, contains('static const int _maxResultsPerTurn = 80;'));
    expect(source, contains('maxResults: _maxResultsPerTurn'));
    expect(source, isNot(contains('maxResults: 800')));
  });

  test('le moteur réutilise les détails canoniques déjà chargés', () {
    final coordinator =
        File('lib/src/search_v4/search_coordinator_v4.dart')
            .readAsStringSync();
    final service =
        File('lib/src/services/search_service_v4.dart')
            .readAsStringSync();

    expect(coordinator, contains('this.details = const <int, StudyPassage>{}'));
    expect(coordinator, contains('details: <int, StudyPassage>{'));
    expect(service, contains('outcome.details.isNotEmpty'));
  });

  test('la recherche fuzzy reste un fallback préfixé dédié', () {
    final coordinator =
        File('lib/src/search_v4/search_coordinator_v4.dart')
            .readAsStringSync();
    final repository =
        File('lib/src/services/corpus_repository.dart')
            .readAsStringSync();

    expect(coordinator, contains('needsFuzzyFallback'));
    expect(coordinator, contains('searchTermStatsByPrefix'));
    expect(repository, contains('List<TermStat> searchTermStatsByPrefix'));
    expect(
      repository,
      contains("['%\$q%', q, limit]"),
      reason:
          'La concordance générale doit conserver sa recherche contains.',
    );
  });

  test('le suivi étude est borné et évite les écritures inutiles', () {
    final screen =
        File('lib/src/screens/study_reading_screen.dart')
            .readAsStringSync();
    final repository =
        File('lib/src/study_certification/study_progress_repository.dart')
            .readAsStringSync();

    expect(screen, contains('Duration(seconds: 2)'));
    expect(screen, contains('if (latestReadingPercent == _readingPercent) return;'));
    expect(repository, contains('if (wasRead)'));
    expect(repository, contains('var nextReadingPercent = current.readingPercent;'));
    expect(
      repository,
      isNot(
        contains(
          'return recalculateReadingPercent(\n      sermonId: sermonId',
        ),
      ),
    );
  });

  test('le cache sémantique reste borné en mémoire', () {
    final source =
        File('lib/src/offline_ai/offline_ai_citation_ranker.dart')
            .readAsStringSync();

    expect(source, contains('LinkedHashMap<int, _PreparedPassage>'));
    expect(source, contains('static const int _passageCacheLimit = 160;'));
    expect(source, contains('_passageCache.remove(_passageCache.keys.first)'));
  });
}
