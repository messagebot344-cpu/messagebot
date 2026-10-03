import 'package:flutter_test/flutter_test.dart';
import 'package:le_grenier_du_message/src/conversation/conversation_models.dart';
import 'package:le_grenier_du_message/src/search_v4/morphology_engine.dart';
import 'package:le_grenier_du_message/src/search_v4/query_parser_v4.dart';
import 'package:le_grenier_du_message/src/search_v4/text_normalizer.dart';

void main() {
  test('normalizer folds French accents deterministically', () {
    expect(const TextNormalizer().normalize('Grâce à l’Éternel — Foi!'), "grace a l'eternel - foi");
  });

  test('quoted search and year filter are parsed without generation', () {
    final q = const QueryParserV4().parse('"Dieu dans la simplicité" après 1960');
    expect(q.exactPhrase, 'Dieu dans la simplicité');
    expect(q.filters.yearMin, 1960);
    expect(q.filters.yearMax, isNull);
  });

  test('filter-only continuation inherits visible subject', () {
    final q = const QueryParserV4().parse(
      'avant 1965',
      inherited: const ConversationFilterSet(subjectTerms: ['foi', 'promesse']),
    );
    expect(q.subjectTerms, ['foi', 'promesse']);
    expect(q.filters.yearMax, 1965);
  });

  test('safe morphology stays bounded', () {
    final values = const MorphologyEngine().expandSafe('promesses');
    expect(values.length, lessThanOrEqualTo(8));
  });
}
