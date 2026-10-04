import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../app_scope.dart';
import '../conversation/relevance_label.dart';
import '../models/models.dart';
import '../printing/print_document_builder.dart';
import '../printing/print_models.dart';
import 'print_preview_screen.dart';
import '../search_v4/search_explanation.dart';
import 'collection_picker.dart';
import 'passage_navigation.dart';
import 'similar_passages_screen.dart';

class ConversationResultCard extends StatelessWidget {
  const ConversationResultCard({
    super.key,
    required this.turnId,
    required this.query,
    required this.rank,
    required this.hit,
    required this.explanation,
    required this.expanded,
    required this.topScore,
  });

  final int turnId;
  final String query;
  final int rank;
  final DocumentSearchHit hit;
  final SearchExplanationV4 explanation;
  final bool expanded;
  final double topScore;

  @override
  Widget build(BuildContext context) {
    final scope = AppScope.of(context);
    final item = hit.studyPassage;
    final passage = item.passage;
    final label = relevanceLabelFor(hit.score, topScore: topScore).label;
    final page = passage.sourcePageStart == passage.sourcePageEnd ? 'p. ${passage.sourcePageStart}' : 'pp. ${passage.sourcePageStart}–${passage.sourcePageEnd}';
    final reference = item.sermon != null
        ? '${item.sermon!.code} • ${item.source.title} • $page${item.edition?.isPrimary == false ? ' • édition alternative' : ''}'
        : '${item.source.title}${item.chapterTitle == null ? '' : ' • ${item.chapterTitle}'} • $page';
    final full = passage.text.trim();
    final compact = full.length <= 680 ? full : '${full.substring(0, 680)}…';
    return Card(
      key: Key('result-rank-$rank'),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
            CircleAvatar(radius: 17, child: Text('$rank')),
            const SizedBox(width: 10),
            Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(label, style: Theme.of(context).textTheme.labelLarge?.copyWith(color: Theme.of(context).colorScheme.primary)),
              const SizedBox(height: 2),
              Text(reference, style: Theme.of(context).textTheme.bodySmall),
            ])),
            if (item.source.type == CorpusSourceType.book) const Chip(label: Text('Livre')),
          ]),
          const SizedBox(height: 12),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Theme.of(context).colorScheme.primaryContainer.withValues(alpha: 0.45),
              borderRadius: BorderRadius.circular(12),
            ),
            child: SelectableText(hit.highlightSentence, style: const TextStyle(fontWeight: FontWeight.w700)),
          ),
          const SizedBox(height: 10),
          SelectableText(expanded ? full : compact, key: expanded ? const Key('expanded-canonical-passage') : null),
          if (explanation.reasons.isNotEmpty) ...[
            const SizedBox(height: 10),
            ExpansionTile(
              tilePadding: EdgeInsets.zero,
              childrenPadding: const EdgeInsets.only(bottom: 8),
              title: const Text('Pourquoi ce résultat ?'),
              children: explanation.reasons.map((e) => Align(alignment: Alignment.centerLeft, child: Padding(
                padding: const EdgeInsets.only(bottom: 4),
                child: Text('• $e'),
              ))).toList(),
            ),
          ],
          const SizedBox(height: 6),
          Wrap(spacing: 6, runSpacing: 4, children: [
            TextButton.icon(
              onPressed: () => scope.conversationController.setExpanded(turnId, passage.id, !expanded),
              icon: Icon(expanded ? Icons.unfold_less : Icons.unfold_more),
              label: Text(expanded ? 'Réduire' : 'Développer'),
            ),
            TextButton.icon(
              onPressed: () => openStudyPassage(
                context,
                item,
                highlightStartOffset: hit.highlightStartOffset,
                highlightEndOffset: hit.highlightEndOffset,
              ),
              icon: const Icon(Icons.open_in_new),
              label: const Text('Ouvrir'),
            ),
            TextButton.icon(
              onPressed: () => Navigator.of(context).push(MaterialPageRoute(builder: (_) => SimilarPassagesScreen(passageId: passage.id))),
              icon: const Icon(Icons.hub_outlined),
              label: const Text('Passages similaires'),
            ),
            TextButton.icon(onPressed: () => addPassageToCollection(context, passage.id), icon: const Icon(Icons.create_new_folder_outlined), label: const Text('Collection')),
            TextButton.icon(
              onPressed: () async {
                await Clipboard.setData(ClipboardData(text: '${hit.highlightSentence}\n\n$reference'));
                if (context.mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Citation copiée.')));
              },
              icon: const Icon(Icons.copy_outlined),
              label: const Text('Copier'),
            ),
            TextButton.icon(
              onPressed: () async {
                final bytes = await PrintDocumentBuilder().buildTurnPdf(PrintableTurn(
                  query: query,
                  filters: scope.conversationController.currentFilters,
                  results: [PrintableResult(rank: rank, hit: hit)],
                ));
                if (!context.mounted) return;
                await Navigator.of(context).push(MaterialPageRoute(
                  builder: (_) => MessageBotPrintPreviewScreen(
                    title: 'Aperçu avant impression',
                    bytes: bytes,
                  ),
                ));
              },
              icon: const Icon(Icons.print_outlined),
              label: const Text('Imprimer'),
            ),
          ]),
        ]),
      ),
    );
  }
}
