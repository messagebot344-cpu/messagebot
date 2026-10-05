import 'package:flutter_test/flutter_test.dart';
import 'package:le_grenier_du_message/src/conversation/relevance_label.dart';

void main() {
  test('la confiance absolue empêche de sur-vendre le premier résultat', () {
    expect(
      relevanceLabelFor(
        1.0,
        topScore: 1.0,
        answerConfidence: 0.08,
      ),
      RelevanceLabel.partial,
    );
    expect(
      relevanceLabelFor(
        0.7,
        topScore: 1.0,
        answerConfidence: 0.20,
      ),
      RelevanceLabel.relevant,
    );
    expect(
      relevanceLabelFor(
        0.4,
        topScore: 1.0,
        answerConfidence: 0.50,
      ),
      RelevanceLabel.veryRelevant,
    );
  });

  test('sans confiance absolue le classement relatif reste disponible', () {
    expect(
      relevanceLabelFor(1.0, topScore: 1.0),
      RelevanceLabel.veryRelevant,
    );
  });
}
