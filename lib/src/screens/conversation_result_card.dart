import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../app_scope.dart';
import '../conversation/conversation_models.dart';
import '../conversation/relevance_label.dart';
import '../models/models.dart';
import '../printing/print_document_builder.dart';
import '../printing/print_models.dart';
import '../search_v4/search_explanation.dart';
import '../theme/grenier_tokens.dart';
import 'canonical_highlight_text.dart';
import 'collection_picker.dart';
import 'comparison_picker_screen.dart';
import 'passage_navigation.dart';
import 'print_preview_screen.dart';
import 'result_details_panel.dart';
import 'similar_passages_screen.dart';

class ConversationResultCard extends StatelessWidget {
  const ConversationResultCard({
    super.key,
    required this.turnId,
    required this.query,
    required this.filters,
    required this.rank,
    required this.hit,
    required this.explanation,
    required this.expanded,
    required this.topScore,
    this.onSelected,
  });

  final int turnId;
  final String query;
  final ConversationFilterSet filters;
  final int rank;
  final DocumentSearchHit hit;
  final SearchExplanationV4 explanation;
  final bool expanded;
  final double topScore;
  final ValueChanged<ResultSelection>? onSelected;

  ResultSelection _selection() => ResultSelection(
        turnId: turnId,
        query: query,
        filters: filters,
        rank: rank,
        hit: hit,
        explanation: explanation,
        topScore: topScore,
      );

  @override
  Widget build(BuildContext context) {
    final scope = AppScope.of(context);
    final item = hit.studyPassage;
    final passage = item.passage;
    final label = relevanceLabelFor(hit.score, topScore: topScore).label;
    final page = passage.sourcePageStart == passage.sourcePageEnd
        ? 'p. ${passage.sourcePageStart}'
        : 'pp. ${passage.sourcePageStart}–${passage.sourcePageEnd}';
    final date = item.sermon?.year.toString();
    final reference = item.sermon != null
        ? '${item.sermon!.code} • ${item.source.title} • $page${date == null || date.isEmpty ? '' : ' • $date'}${item.edition?.isPrimary == false ? ' • édition alternative' : ''}'
        : '${item.source.title}${item.chapterTitle == null ? '' : ' • ${item.chapterTitle}'} • $page';
    final full = passage.text.trim();
    final compact = full.length <= 680 ? full : '${full.substring(0, 680)}…';
    final terms = <String>[query, ...filters.subjectTerms];

    return Card(
      key: Key('result-rank-$rank'),
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: onSelected == null ? null : () => onSelected!(_selection()),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Container(
                width: 36,
                height: 36,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: GrenierPalette.navy,
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Text('$rank', style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w800)),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Wrap(
                    spacing: 8,
                    runSpacing: 6,
                    crossAxisAlignment: WrapCrossAlignment.center,
                    children: [
                      Chip(
                        avatar: const Icon(Icons.auto_awesome_outlined, size: 16),
                        label: Text(label),
                        visualDensity: VisualDensity.compact,
                      ),
                      if (item.source.type == CorpusSourceType.book)
                        const Chip(label: Text('Livre'), visualDensity: VisualDensity.compact),
                    ],
                  ),
                  const SizedBox(height: 4),
                  Text(reference, style: Theme.of(context).textTheme.bodySmall),
                ]),
              ),
            ]),
            const SizedBox(height: 12),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Theme.of(context).brightness == Brightness.dark
                    ? Theme.of(context).colorScheme.surfaceContainerHighest
                    : const Color(0xFFFFFBED),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: Theme.of(context).colorScheme.outlineVariant),
              ),
              child: CanonicalHighlightText(
                text: hit.highlightSentence,
                terms: terms,
                style: Theme.of(context).textTheme.bodyLarge?.copyWith(fontWeight: FontWeight.w700, height: 1.45),
              ),
            ),
            const SizedBox(height: 10),
            SelectableText(
              expanded ? full : compact,
              key: expanded ? const Key('expanded-canonical-passage') : null,
              style: const TextStyle(height: 1.45),
            ),
            if (explanation.reasons.isNotEmpty) ...[
              const SizedBox(height: 10),
              ExpansionTile(
                tilePadding: EdgeInsets.zero,
                childrenPadding: const EdgeInsets.only(bottom: 8),
                title: const Text('Pourquoi ce résultat ?'),
                children: explanation.reasons
                    .map((reason) => Align(
                          alignment: Alignment.centerLeft,
                          child: Padding(
                            padding: const EdgeInsets.only(bottom: 4),
                            child: Text('• $reason'),
                          ),
                        ))
                    .toList(),
              ),
            ],
            const SizedBox(height: 8),
            Wrap(spacing: 6, runSpacing: 4, children: [
              TextButton.icon(
                onPressed: () => scope.conversationController.setExpanded(turnId, passage.id, !expanded),
                icon: Icon(expanded ? Icons.unfold_less : Icons.unfold_more),
                label: Text(expanded ? 'Voir moins' : 'Développer'),
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
              if (onSelected != null)
                Tooltip(
                  message: 'Détails du résultat',
                  child: TextButton.icon(
                    onPressed: () => onSelected!(_selection()),
                    icon: const Icon(Icons.info_outline),
                    label: const Text('Détails'),
                  ),
                ),
              TextButton.icon(
                onPressed: () => Navigator.of(context).push(MaterialPageRoute(
                  builder: (_) => ComparisonPickerScreen(initialPassage: item),
                )),
                icon: const Icon(Icons.compare_arrows),
                label: const Text('Comparer'),
              ),
              TextButton.icon(
                onPressed: () => Navigator.of(context).push(
                  MaterialPageRoute(builder: (_) => SimilarPassagesScreen(passageId: passage.id)),
                ),
                icon: const Icon(Icons.hub_outlined),
                label: const Text('Passages similaires'),
              ),
              TextButton.icon(
                onPressed: () => addPassageToCollection(context, passage.id),
                icon: const Icon(Icons.create_new_folder_outlined),
                label: const Text('Collection'),
              ),
              TextButton.icon(
                onPressed: () async {
                  await Clipboard.setData(ClipboardData(text: '${hit.highlightSentence}\n\n$reference'));
                  if (context.mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Citation copiée.')));
                  }
                },
                icon: const Icon(Icons.copy_outlined),
                label: const Text('Copier'),
              ),
              TextButton.icon(
                onPressed: () async {
                  final bytes = await PrintDocumentBuilder().buildTurnPdf(PrintableTurn(
                    query: query,
                    filters: filters,
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
              TextButton.icon(
                onPressed: () async {
                  final citation = '“${hit.highlightSentence}”\n$reference';
                  await Clipboard.setData(ClipboardData(text: citation));
                  if (context.mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Référence prête à être citée.')));
                  }
                },
                icon: const Icon(Icons.format_quote),
                label: const Text('Citer'),
              ),
            ]),
          ]),
        ),
      ),
    );
  }
}
