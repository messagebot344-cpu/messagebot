import 'package:flutter_test/flutter_test.dart';
import 'package:le_grenier_du_message/src/search/query_analyzer.dart';
import 'package:le_grenier_du_message/src/search/search_contracts.dart';

void main() {
  test('classifies a French conceptual question', () {
    final intent = QueryAnalyzer().analyze(
      'Pourquoi la foi est-elle importante ?',
    );

    expect(intent.kind, QueryKind.conceptual);
  });
}
