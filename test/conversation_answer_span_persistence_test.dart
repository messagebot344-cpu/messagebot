import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:le_grenier_du_message/src/conversation/conversation_models.dart';
import 'package:le_grenier_du_message/src/conversation/conversation_repository.dart';
import 'package:le_grenier_du_message/src/personal/user_database.dart';

void main() {
  test('la citation ciblée reste identique après rechargement', () {
    final dir = Directory.systemTemp.createTempSync(
      'grenier-conversation-span-',
    );
    final db = UserDatabase.openPath('${dir.path}/user.db');
    final repository = ConversationRepository(db);

    final conversationId = repository.createConversation(
      'Pourquoi la prière reste-t-elle sans réponse ?',
    );
    repository.appendTurn(
      conversationId: conversationId,
      query: 'Pourquoi la prière reste-t-elle sans réponse ?',
      filters: const ConversationFilterSet(
        subjectTerms: <String>['priere', 'reponse'],
      ),
      hits: const <PersistedHitRef>[
        PersistedHitRef(
          passageId: 123,
          rank: 1,
          score: 0.72,
          answerStartOffset: 18,
          answerEndOffset: 94,
          answerOrdinal: 4,
          answerConfidence: 0.61,
        ),
      ],
    );

    final loaded = repository.loadConversation(conversationId);
    expect(loaded, hasLength(1));
    expect(loaded.single.hits, hasLength(1));
    final hit = loaded.single.hits.single;
    expect(hit.answerStartOffset, 18);
    expect(hit.answerEndOffset, 94);
    expect(hit.answerOrdinal, 4);
    expect(hit.answerConfidence, closeTo(0.61, 0.000001));
    expect(hit.hasAnswerSpan, isTrue);

    final schema = int.parse(db.meta('schema_version')!);
    expect(schema, greaterThanOrEqualTo(7));
    final table = db.db.select(
      "SELECT name FROM sqlite_master "
      "WHERE type='table' AND name='conversation_answer_spans'",
    );
    expect(table, isNotEmpty);

    db.close();
    dir.deleteSync(recursive: true);
  });
}
