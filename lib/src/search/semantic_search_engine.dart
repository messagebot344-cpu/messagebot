import '../services/semantic_index.dart';

class SemanticSearchEngine {
  const SemanticSearchEngine(this.index);

  final SemanticIndex index;

  List<String> tokens(String query) => index.tokens(query);
  int knownTokenCount(String query) => index.knownTokenCount(query);
  double knownTokenCoverage(String query) => index.knownTokenCoverage(query);

  List<SemanticHit> search(String query, {int limit = 120}) =>
      index.search(query, limit: limit);
}
