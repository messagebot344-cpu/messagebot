import 'package:flutter_test/flutter_test.dart';
import 'package:le_grenier_du_message/src/search_v4/query_parser_v4.dart';

void main() {
  const parser = QueryParserV4();

  test('distingue recherche documentaire et question naturelle', () {
    expect(
      parser.parse('citations sur la prière et la foi').isNaturalQuestion,
      isFalse,
    );
    expect(
      parser.parse('Pourquoi certaines prières ne sont-elles pas exaucées ?')
          .questionIntent,
      QuestionIntent.why,
    );
    expect(
      parser.parse('Comment choisir une épouse chrétienne ?').questionIntent,
      QuestionIntent.how,
    );
    expect(
      parser.parse('Que signifie recevoir le Saint-Esprit ?').questionIntent,
      QuestionIntent.definition,
    );
    expect(
      parser.parse("Qu'est-ce que le Saint-Esprit ?").questionIntent,
      QuestionIntent.definition,
    );
    expect(
      parser.parse('Quelle différence entre volonté parfaite et permissive ?')
          .questionIntent,
      QuestionIntent.comparison,
    );
    expect(
      parser.parse('Quand faut-il jeûner ?').questionIntent,
      QuestionIntent.condition,
    );
  });

  test('une citation exacte reste une recherche documentaire explicite', () {
    final spec = parser.parse('"Dieu répond à la prière"');
    expect(spec.exactPhrase, isNotNull);
    expect(spec.questionIntent, QuestionIntent.none);
    expect(spec.isNaturalQuestion, isFalse);
  });
}
