import 'package:flutter_test/flutter_test.dart';
import 'package:le_grenier_du_message/src/models/models.dart';
import 'package:le_grenier_du_message/src/screens/passage_target.dart';

void main() {
  test('navigation resolves exact passage id instead of assuming ordinal is index', () {
    const passages = <Passage>[
      Passage(
        id: 101,
        editionId: 'e1',
        sermonId: 1,
        ordinal: 40,
        sourcePageStart: 10,
        sourcePageEnd: 10,
        text: 'Premier passage.',
      ),
      Passage(
        id: 205,
        editionId: 'e1',
        sermonId: 1,
        ordinal: 92,
        sourcePageStart: 11,
        sourcePageEnd: 11,
        text: 'Deuxième passage avec la citation recherchée.',
      ),
      Passage(
        id: 309,
        editionId: 'e1',
        sermonId: 1,
        ordinal: 150,
        sourcePageStart: 12,
        sourcePageEnd: 12,
        text: 'Troisième passage.',
      ),
    ];

    expect(
      resolvePassageIndex(passages, passageId: 205, fallbackIndex: 0),
      1,
    );
  });

  test('highlight offsets must stay inside the targeted passage', () {
    const passage = Passage(
      id: 205,
      editionId: 'e1',
      sermonId: 1,
      ordinal: 92,
      sourcePageStart: 11,
      sourcePageEnd: 11,
      text: 'Une citation précise dans ce passage.',
    );

    expect(
      hasValidHighlight(passage, startOffset: 4, endOffset: 20),
      isTrue,
    );
    expect(
      hasValidHighlight(passage, startOffset: 4, endOffset: 200),
      isFalse,
    );
  });
}
