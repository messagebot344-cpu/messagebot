import 'package:flutter_test/flutter_test.dart';
import 'package:le_grenier_du_message/src/conversation/conversation_models.dart';
import 'package:le_grenier_du_message/src/search_v4/conceptual_query_expander.dart';
import 'package:le_grenier_du_message/src/search_v4/morphology_engine.dart';
import 'package:le_grenier_du_message/src/search_v4/query_parser_v4.dart';
import 'package:le_grenier_du_message/src/search_v4/text_normalizer.dart';
import 'package:le_grenier_du_message/src/services/corpus_repository.dart';

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

  test('natural-language questions keep subject focus and expand concepts', () {
    final spec = const QueryParserV4().parse(
      'Comment peut-on recevoir la guérison divine ?',
    );
    final expansion = ConceptualQueryExpander(
      CorpusRepository(),
      useCorpusAssociations: false,
    ).expand(spec);

    expect(expansion.questionLike, isTrue);
    expect(expansion.focusTerms, contains('guerison'));
    expect(expansion.focusTerms, isNot(contains('comment')));
    expect(expansion.focusTerms, isNot(contains('peut')));
    expect(expansion.relatedTerms, contains('maladie'));
    expect(expansion.relatedTerms, contains('guerir'));
  });

  test('safe morphology stays bounded', () {
    final values = const MorphologyEngine().expandSafe('promesses');
    expect(values.length, lessThanOrEqualTo(8));
  });
}
