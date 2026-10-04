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

  test('tokens lexicaux historiques restent inchangés pour les codes', () {
    expect(
      normalizer.tokens('63-1226'),
      contains('63-1226'),
    );
  });
}
