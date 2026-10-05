import 'package:flutter_test/flutter_test.dart';
import 'package:le_grenier_du_message/src/search_v4/text_normalizer.dart';

void main() {
  const normalizer = TextNormalizer();

  test('semanticTokens sépare les élisions et mots composés français', () {
    expect(
      normalizer.semanticTokens("l'enseignant du Saint-Esprit"),
      containsAll(<String>['enseignant', 'saint', 'esprit']),
    );
    expect(
      normalizer.semanticTokens("n'est-elle pas exaucée"),
      contains('exaucee'),
    );
  });

  test('la polarité négative reste visible au moteur sémantique', () {
    final negative = normalizer.semanticTokens(
      'Dieu ne répond pas à cette prière',
    );
    expect(negative, contains('ne'));
    expect(negative, contains('pas'));
    expect(
      normalizer.hasExplicitNegation(
        'Dieu ne répond pas à cette prière',
      ),
      isTrue,
    );
    expect(
      normalizer.hasExplicitNegation(
        'Dieu répond à cette prière',
      ),
      isFalse,
    );
  });

  test('tokens lexicaux historiques restent inchangés pour les codes', () {
    expect(
      normalizer.tokens('63-1226'),
      contains('63-1226'),
    );
  });
}
