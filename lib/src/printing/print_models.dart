import '../conversation/conversation_models.dart';
import '../models/models.dart';

class PrintableResult {
  const PrintableResult({required this.rank, required this.hit});
  final int rank;
  final DocumentSearchHit hit;
}

class PrintableTurn {
  const PrintableTurn({
    required this.query,
    required this.filters,
    required this.results,
  });

  final String query;
  final ConversationFilterSet filters;
  final List<PrintableResult> results;
}

class PrintableConversation {
  const PrintableConversation({
    required this.title,
    required this.turns,
  });

  final String title;
  final List<PrintableTurn> turns;
}
