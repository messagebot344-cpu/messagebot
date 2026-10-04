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

  test('les associations conceptuelles coûteuses sont différées', () {
    final coordinator =
        File('lib/src/search_v4/search_coordinator_v4.dart')
            .readAsStringSync();
    final expander =
        File('lib/src/search_v4/conceptual_query_expander.dart')
            .readAsStringSync();

    expect(coordinator, contains('includeCorpusAssociations: false'));
    expect(coordinator, contains('strongEvidenceCount < 40'));
    expect(expander, contains('bool includeCorpusAssociations = true'));
  });

  test('le suivi étude est borné et évite les écritures inutiles', () {
    final screen =
        File('lib/src/screens/study_reading_screen.dart')
            .readAsStringSync();
    final repository =
        File('lib/src/study_certification/study_progress_repository.dart')
            .readAsStringSync();

    expect(screen, contains('Duration(seconds: 2)'));
    expect(screen, contains('recordStudyHeartbeat'));
    expect(screen, contains('if (latestReadingPercent == _readingPercent) return;'));
    expect(repository, contains('if (wasRead)'));
    expect(repository, contains('void recordStudyHeartbeat'));
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

  test('les pools de récupération s adaptent au volume réellement demandé', () {
    final source =
        File('lib/src/search_v4/search_coordinator_v4.dart')
            .readAsStringSync();

    expect(source, contains('(maxResults * 10).clamp(600, 1200)'));
    expect(source, contains('final expansionLimit'));
    expect(source, contains('final secondaryLimit'));
    expect(source, isNot(contains('const candidateLimit = 1800')));
  });

  test('les écrans de saisie évitent les requêtes SQLite à chaque frappe', () {
    final library =
        File('lib/src/screens/library_screen.dart').readAsStringSync();
    final concordance =
        File('lib/src/screens/concordance_screen.dart').readAsStringSync();

    expect(library, contains('Duration(milliseconds: 180)'));
    expect(concordance, contains('Duration(milliseconds: 180)'));
    expect(library, contains('bookChapterCounts'));
    expect(library, contains('favoriteCodes'));
  });

  test('le lecteur limite les lectures et écritures personnelles', () {
    final reader =
        File('lib/src/screens/reader_screen.dart').readAsStringSync();
    final library =
        File('lib/src/personal/personal_library.dart')
            .readAsStringSync();

    expect(reader, contains('highlightsForPassages'));
    expect(reader, contains('Duration(milliseconds: 350)'));
    expect(reader, isNot(contains('highlights(limit: 1000000)')));
    expect(library, contains('const batchSize = 400'));
  });

  test('le cache SQLite canonique reste borné et invalidé au changement de corpus', () {
    final source =
        File('lib/src/services/corpus_repository.dart')
            .readAsStringSync();

    expect(source, contains('LinkedHashMap<int, StudyPassage>'));
    expect(source, contains('static const int _studyDetailCacheLimit = 256;'));
    expect(source, contains('_studyDetailCache.clear();'));
    expect(source, contains('_studyDetailCache.remove(_studyDetailCache.keys.first)'));
  });

  test('afficher plus de résultats ne relance pas le moteur', () {
    final source =
        File('lib/src/screens/search_results_screen.dart')
            .readAsStringSync();

    expect(source, contains('static const int _fetchLimit = 50;'));
    expect(source, contains('_visibleLimit'));
    final loadMoreStart = source.indexOf('void _loadMore()');
    final buildStart = source.indexOf('@override\n  Widget build', loadMoreStart);
    final loadMoreBlock = source.substring(loadMoreStart, buildStart);
    expect(loadMoreBlock, isNot(contains('searchDocuments')));
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
