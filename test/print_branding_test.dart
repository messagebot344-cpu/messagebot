import 'package:flutter_test/flutter_test.dart';
import 'package:le_grenier_du_message/src/conversation/conversation_models.dart';
import 'package:le_grenier_du_message/src/models/models.dart';
import 'package:le_grenier_du_message/src/printing/print_document_builder.dart';
import 'package:le_grenier_du_message/src/printing/print_models.dart';

void main() {
  final source = const CorpusSourceSummary(
    id: 'sermon:1',
    type: CorpusSourceType.sermon,
    title: 'Prédication de test',
    code: 'TEST',
    year: 1965,
  );
  final sermon = const SermonSummary(
    id: 1,
    code: 'TEST',
    title: 'Prédication de test',
    year: 1965,
    editionCount: 1,
    primaryEditionId: 'ed1',
  );
  final edition = const EditionSummary(
    id: 'ed1',
    sermonId: 1,
    title: 'Édition principale',
    isPrimary: true,
    isFrn: false,
    sourcePageStart: 1,
    sourcePageEnd: 1,
  );
  final passage = const Passage(
    id: 1,
    editionId: 'ed1',
    sermonId: 1,
    ordinal: 1,
    sourcePageStart: 12,
    sourcePageEnd: 12,
    text: 'La foi est une ferme assurance des choses qu’on espère.',
  );
  final study = StudyPassage(
    passage: passage,
    source: source,
    sermon: sermon,
    edition: edition,
  );
  final hit = DocumentSearchHit(
    studyPassage: study,
    score: 1,
    highlightSentence: 'La foi est une ferme assurance des choses qu’on espère.',
    highlightStartOffset: 0,
    highlightEndOffset: passage.text.length,
  );
  final result = PrintableResult(rank: 1, hit: hit);
  final turn = PrintableTurn(
    query: 'Que dit-il sur la foi ?',
    filters: const ConversationFilterSet(subjectTerms: ['foi']),
    results: [result],
  );

  test('all PDF levels use Grenier identity and deterministic date', () async {
    final builder = PrintDocumentBuilder(now: () => DateTime(2026, 10, 4));

    final passageBytes = await builder.buildPassagePdf(result, query: 'foi');
    expect(passageBytes, isNotEmpty);
    expect(builder.debugPlainText, contains('Le Grenier du Message'));
    expect(builder.debugPlainText, contains('04/10/2026'));
    expect(builder.debugPlainText, isNot(contains('Message Bot')));

    final turnBytes = await builder.buildTurnPdf(turn);
    expect(turnBytes, isNotEmpty);
    expect(builder.debugPlainText, contains('1 passages pertinents'));
    expect(builder.debugPlainText, contains('Que dit-il sur la foi ?'));

    final conversationBytes = await builder.buildConversationPdf(
      PrintableConversation(title: 'Conversation de test', turns: [turn, turn]),
    );
    expect(conversationBytes, isNotEmpty);
    expect(builder.debugPlainText, contains('Conversation de test'));
    expect('Que dit-il sur la foi ?'.allMatches(builder.debugPlainText).length, 2);
  });
}
