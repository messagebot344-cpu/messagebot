import 'package:flutter_test/flutter_test.dart';
import 'package:le_grenier_du_message/src/search_v4/search_explanation.dart';

void main() {
  test('l explication distingue clairement l IA locale du texte canonique', () {
    final explanation = const SearchExplanationV4(
      curatedReference: true,
      curatedReferences: ['63-1226 • §§21-22'],
    ).withOfflineAiTopics(['Avant le service et révérence']);

    expect(explanation.offlineAiSemantic, isTrue);
    expect(
      explanation.reasons.join(' '),
      contains('IA sémantique locale'),
    );
    expect(
      explanation.reasons.join(' '),
      contains('texte vérifié dans le corpus'),
    );
  });
}
