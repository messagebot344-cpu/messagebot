import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../app_scope.dart';
import '../conversation/conversation_models.dart';
import '../models/models.dart';
import '../printing/print_document_builder.dart';
import '../printing/print_models.dart';
import '../search_v4/search_explanation.dart';
import 'passage_navigation.dart';
import 'print_preview_screen.dart';

class ResultSelection {
  const ResultSelection({
    required this.turnId,
    required this.query,
    required this.filters,
    required this.rank,
    required this.hit,
    required this.explanation,
    required this.topScore,
  });

  final int turnId;
  final String query;
  final ConversationFilterSet filters;
  final int rank;
  final DocumentSearchHit hit;
  final SearchExplanationV4 explanation;
  final double topScore;
}

class ResultDetailsPanel extends StatelessWidget {
  const ResultDetailsPanel({
    super.key,
    required this.selection,
    required this.onClose,
  });

  final ResultSelection selection;
  final VoidCallback onClose;

  @override
  Widget build(BuildContext context) {
    final item = selection.hit.studyPassage;
    final passage = item.passage;
    final page = passage.sourcePageStart == passage.sourcePageEnd
        ? 'p. ${passage.sourcePageStart}'
        : 'pp. ${passage.sourcePageStart}–${passage.sourcePageEnd}';
    final source = item.sermon == null
        ? item.source.title
        : '${item.sermon!.code} • ${item.source.title}';

    return Material(
      color: Theme.of(context).colorScheme.surface,
      child: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(18, 14, 18, 22),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Text(
                      'Détails du résultat',
                      style: Theme.of(context).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w800),
                    ),
                  ),
                  IconButton(onPressed: onClose, icon: const Icon(Icons.close), tooltip: 'Fermer les détails'),
                ],
              ),
              const SizedBox(height: 12),
              _DetailLine(label: 'Rang', value: '#${selection.rank}'),
              _DetailLine(label: 'Référence', value: source),
              _DetailLine(label: 'Page', value: page),
              if (item.sermon != null) _DetailLine(label: 'Date', value: item.sermon!.dateDisplay),
              const SizedBox(height: 18),
              Text('Citation ciblée', style: Theme.of(context).textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w800)),
              const SizedBox(height: 8),
              SelectableText(selection.hit.highlightSentence),
              const SizedBox(height: 18),
              Text('Contexte plus large', style: Theme.of(context).textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w800)),
              const SizedBox(height: 8),
              SelectableText(passage.text, style: const TextStyle(height: 1.45)),
              if (selection.explanation.reasons.isNotEmpty) ...[
                const SizedBox(height: 18),
                Text('Pourquoi ce résultat ?', style: Theme.of(context).textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w800)),
                const SizedBox(height: 6),
                for (final reason in selection.explanation.reasons)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 5),
                    child: Text('• $reason'),
                  ),
              ],
              const SizedBox(height: 20),
              FilledButton.icon(
                onPressed: () => openStudyPassage(
                  context,
                  item,
                  highlightStartOffset: selection.hit.highlightStartOffset,
                  highlightEndOffset: selection.hit.highlightEndOffset,
                ),
                icon: const Icon(Icons.open_in_new),
                label: const Text('Voir le passage complet'),
              ),
              const SizedBox(height: 8),
              OutlinedButton.icon(
                onPressed: () async {
                  await Clipboard.setData(
                    ClipboardData(text: '${selection.hit.highlightSentence}\n\n$source • $page'),
                  );
                  if (context.mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Citation copiée.')));
                  }
                },
                icon: const Icon(Icons.format_quote),
                label: const Text('Citer'),
              ),
              const SizedBox(height: 8),
              OutlinedButton.icon(
                onPressed: () async {
                  final bytes = await PrintDocumentBuilder().buildTurnPdf(PrintableTurn(
                    query: selection.query,
                    filters: selection.filters,
                    results: [PrintableResult(rank: selection.rank, hit: selection.hit)],
                  ));
                  if (!context.mounted) return;
                  await Navigator.of(context).push(MaterialPageRoute(
                    builder: (_) => MessageBotPrintPreviewScreen(
                      title: 'Aperçu avant impression',
                      bytes: bytes,
                    ),
                  ));
                },
                icon: const Icon(Icons.picture_as_pdf_outlined),
                label: const Text('Imprimer / Exporter'),
              ),
              const SizedBox(height: 8),
              TextButton.icon(
                onPressed: () {
                  final scope = AppScope.of(context);
                  scope.conversationController.setExpanded(
                    selection.turnId,
                    passage.id,
                    true,
                  );
                },
                icon: const Icon(Icons.unfold_more),
                label: const Text('Développer dans la conversation'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _DetailLine extends StatelessWidget {
  const _DetailLine({required this.label, required this.value});
  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 7),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(width: 82, child: Text(label, style: Theme.of(context).textTheme.bodySmall)),
          const SizedBox(width: 8),
          Expanded(child: Text(value, style: const TextStyle(fontWeight: FontWeight.w600))),
        ],
      ),
    );
  }
}
