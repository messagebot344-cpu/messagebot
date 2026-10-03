import 'package:flutter_test/flutter_test.dart';
import 'package:le_grenier_du_message/src/search/query_analyzer.dart';
import 'package:le_grenier_du_message/src/search/search_contracts.dart';

void main() {
  final analyzer = QueryAnalyzer();

  test('détecte un code de prédication', () {
    final intent = analyzer.analyze('65-1206');
    expect(intent.sermonCode, '65-1206');
    expect(intent.kind, QueryKind.sermonCode);
  });

  test('protège une expression exacte entre guillemets', () {
    final intent = analyzer.analyze('"Dieu dans la simplicité"');
    expect(intent.exactPhrase, 'Dieu dans la simplicité');
    expect(intent.kind, QueryKind.exact);
  });

  test('détecte un filtre chronologique après une année', () {
    final intent = analyzer.analyze('mariage après 1960');
    expect(intent.yearMin, 1960);
    expect(intent.yearMax, isNull);
  });

  test('détecte la source livres sans écrire de réponse', () {
    final intent = analyzer.analyze('chercher dans le livre Exposé');
    expect(intent.sourceFilter, SourceFilter.books);
  });
}
