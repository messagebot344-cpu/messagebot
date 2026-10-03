from __future__ import annotations

import argparse
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]


def require(path: str, needles: list[str]) -> list[str]:
    p = ROOT / path
    if not p.exists():
        return [f'missing:{path}']
    text = p.read_text(encoding='utf-8')
    return [f'{path}:missing:{needle}' for needle in needles if needle not in text]


def main() -> None:
    parser = argparse.ArgumentParser()
    parser.add_argument('--phase', default='all')
    args = parser.parse_args()
    issues: list[str] = []
    if args.phase in {'query', 'all'}:
        issues += require('lib/src/search/search_contracts.dart', [
            'class PassageReference', 'class SentenceReference', 'class SearchEvidence',
            'class QueryIntent',
        ])
        issues += require('lib/src/search/query_analyzer.dart', [
            'class QueryAnalyzer', 'QueryIntent analyze(', 'sermonCode', 'exactPhrase', 'yearMin',
        ])
        issues += require('test/query_analyzer_test.dart', ['65-1206', 'Dieu dans la simplicité', '1960'])
    if args.phase in {'search', 'all'}:
        issues += require('lib/src/search/lexical_search_engine.dart', ['class LexicalSearchEngine', 'LexicalSearchBundle'])
        issues += require('lib/src/search/semantic_search_engine.dart', ['class SemanticSearchEngine'])
        issues += require('lib/src/search/hybrid_ranker.dart', ['class HybridRanker', 'rank('])
        issues += require('lib/src/search/sentence_locator.dart', ['class SentenceLocator', 'locate('])
        issues += require('lib/src/search/search_coordinator.dart', ['class SearchCoordinator', 'Future<List<PassageReference>> search'])
        issues += require('lib/src/services/search_service.dart', ['SearchCoordinator', 'resolveReferences'])
        issues += require('test/hybrid_ranker_test.dart', ['direct', 'semantic'])
        issues += require('test/sentence_locator_test.dart', ['substring'])
    if args.phase in {'personal', 'all'}:
        issues += require('lib/src/personal/user_database.dart', ['class UserDatabase', 'favorites', 'passage_bookmarks', 'collections', 'user_notes', 'reading_positions', 'search_history'])
        issues += require('lib/src/personal/personal_library.dart', ['class PersonalLibrary', 'migrateFromLegacy', 'createCollection', 'addPassageBookmark'])
        issues += require('lib/src/app_scope.dart', ['PersonalLibrary', 'personalLibrary'])
        issues += require('lib/src/app.dart', ['UserDatabase', 'PersonalLibrary', 'migrateFromLegacy'])
        issues += require('test/personal_library_test.dart', ['user.db', 'collection', 'migration'])
    if args.phase in {'study', 'all'}:
        issues += require('lib/src/study/similarity_engine.dart', ['class SimilarityEngine', 'similarPassages'])
        issues += require('lib/src/study/concordance_engine.dart', ['class ConcordanceEngine', 'searchTerms', 'occurrences'])
        issues += require('lib/src/study/study_engine.dart', ['class StudyEngine', 'timeline'])
        issues += require('lib/src/study/comparison_engine.dart', ['class ComparisonEngine', 'compare'])
        issues += require('lib/src/services/corpus_repository.dart', ['studyDetailsForPassageIds', 'neighborPassages', 'searchTermStats', 'concordancePassageIds'])
        issues += require('test/study_engine_test.dart', ['neighbors', 'chronological', 'comparison'])
    if args.phase in {'ui', 'all'}:
        issues += require('lib/src/screens/shell_screen.dart', ['Accueil', 'Rechercher', 'Bibliothèque', 'Étudier', 'Favoris'])
        issues += require('lib/src/screens/search_screen.dart', ['class SearchScreen', 'SearchResultsScreen'])
        issues += require('lib/src/screens/search_results_screen.dart', ['searchDocuments', 'DocumentSearchHit'])
        issues += require('lib/src/screens/study_screen.dart', ['class StudyScreen', 'Concordance', 'Chronologie', 'Collections'])
        issues += require('lib/src/screens/concordance_screen.dart', ['class ConcordanceScreen'])
        issues += require('lib/src/screens/timeline_screen.dart', ['class TimelineScreen'])
        issues += require('lib/src/screens/similar_passages_screen.dart', ['class SimilarPassagesScreen'])
        issues += require('lib/src/screens/comparison_screen.dart', ['class ComparisonScreen'])
        issues += require('lib/src/screens/collections_screen.dart', ['class CollectionsScreen', 'Note personnelle'])
        issues += require('lib/src/screens/book_reader_screen.dart', ['class BookReaderScreen'])
        issues += require('lib/src/screens/reader_screen.dart', ['Passages similaires', 'Ajouter à une collection', 'Rechercher dans cette prédication'])
        issues += require('lib/src/screens/passage_navigation.dart', ['Future<void> openStudyPassage'])
        nav_text = (ROOT / 'lib/src/screens/passage_navigation.dart').read_text(encoding='utf-8')
        if 'Future<void?>' in nav_text:
            issues.append('lib/src/screens/passage_navigation.dart:nullable-void-future')
        issues += require('test/v3_navigation_contract_test.dart', ['Accueil', 'Rechercher', 'Étudier', 'Favoris'])
    if issues:
        print('\n'.join(issues))
        raise SystemExit(1)
    print('OK')


if __name__ == '__main__':
    main()
