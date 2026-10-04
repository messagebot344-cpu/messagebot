import 'package:flutter/material.dart';

import '../app_scope.dart';
import '../models/models.dart';
import '../theme/grenier_tokens.dart';
import 'passage_navigation.dart';

class HighlightsScreen extends StatefulWidget {
  const HighlightsScreen({super.key});

  @override
  State<HighlightsScreen> createState() => _HighlightsScreenState();
}

class _HighlightsScreenState extends State<HighlightsScreen> {
  Future<void> _clearAll() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Effacer les surlignages ?'),
        content: const Text(
          'Tous les passages surlignés seront retirés de votre historique local. '
          'Le texte du corpus ne sera pas modifié.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: const Text('Annuler'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(dialogContext, true),
            child: const Text('Effacer'),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;
    AppScope.of(context).personalLibrary.clearHighlights();
    setState(() {});
  }

  String _dateLabel(int milliseconds) {
    final value = DateTime.fromMillisecondsSinceEpoch(milliseconds);
    String two(int n) => n.toString().padLeft(2, '0');
    return '${two(value.day)}/${two(value.month)}/${value.year} • '
        '${two(value.hour)}:${two(value.minute)}';
  }

  String _reference(StudyPassage item) {
    final passage = item.passage;
    final pages = passage.sourcePageStart == passage.sourcePageEnd
        ? 'p. ${passage.sourcePageStart}'
        : 'pp. ${passage.sourcePageStart}–${passage.sourcePageEnd}';
    if (item.sermon != null) {
      return '${item.sermon!.code} • ${item.source.title} • $pages';
    }
    final chapter = item.chapterTitle == null ? '' : ' • ${item.chapterTitle}';
    return '${item.source.title}$chapter • $pages';
  }

  @override
  Widget build(BuildContext context) {
    final scope = AppScope.of(context);
    final highlights = scope.personalLibrary.highlights();
    final details = scope.repository.studyDetailsForPassageIds(
      highlights.map((item) => item.passageId),
    );

    return Scaffold(
      appBar: AppBar(
        title: const Text('Passages surlignés'),
        actions: [
          if (highlights.isNotEmpty)
            IconButton(
              tooltip: 'Effacer tous les surlignages',
              onPressed: _clearAll,
              icon: const Icon(Icons.delete_sweep_outlined),
            ),
        ],
      ),
      body: highlights.isEmpty
          ? const Center(
              child: Padding(
                padding: EdgeInsets.all(28),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.border_color_outlined, size: 54),
                    SizedBox(height: 14),
                    Text(
                      'Aucun passage surligné',
                      style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700),
                    ),
                    SizedBox(height: 8),
                    Text(
                      'Dans une prédication, sélectionnez un extrait puis choisissez « Surligner ».',
                      textAlign: TextAlign.center,
                    ),
                  ],
                ),
              ),
            )
          : ListView.builder(
              padding: const EdgeInsets.fromLTRB(12, 12, 12, 28),
              itemCount: highlights.length,
              itemBuilder: (context, index) {
                final highlight = highlights[index];
                final item = details[highlight.passageId];
                return Padding(
                  padding: const EdgeInsets.only(bottom: 10),
                  child: Card(
                    child: InkWell(
                      borderRadius: BorderRadius.circular(16),
                      onTap: item == null
                          ? null
                          : () => openStudyPassage(
                                context,
                                item,
                                highlightStartOffset: highlight.startOffset,
                                highlightEndOffset: highlight.endOffset,
                              ),
                      child: Padding(
                        padding: const EdgeInsets.all(14),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                const Icon(
                                  Icons.border_color,
                                  size: 20,
                                  color: GrenierPalette.actionBlue,
                                ),
                                const SizedBox(width: 8),
                                Expanded(
                                  child: Text(
                                    item == null
                                        ? 'Passage #${highlight.passageId}'
                                        : _reference(item),
                                    style: Theme.of(context)
                                        .textTheme
                                        .titleSmall
                                        ?.copyWith(fontWeight: FontWeight.w700),
                                  ),
                                ),
                                IconButton(
                                  tooltip: 'Retirer ce surlignage',
                                  onPressed: () {
                                    scope.personalLibrary.removeHighlight(highlight.id);
                                    setState(() {});
                                  },
                                  icon: const Icon(Icons.close),
                                ),
                              ],
                            ),
                            const SizedBox(height: 8),
                            Container(
                              width: double.infinity,
                              padding: const EdgeInsets.all(10),
                              decoration: BoxDecoration(
                                color: Theme.of(context).brightness == Brightness.dark
                                    ? GrenierPalette.highlightDark
                                    : GrenierPalette.highlightLight,
                                borderRadius: BorderRadius.circular(10),
                              ),
                              child: SelectableText(
                                highlight.highlightedText,
                                style: const TextStyle(
                                  fontWeight: FontWeight.w700,
                                  height: 1.4,
                                ),
                              ),
                            ),
                            const SizedBox(height: 8),
                            Text(
                              'Surligné le ${_dateLabel(highlight.createdAt)}',
                              style: Theme.of(context).textTheme.bodySmall,
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                );
              },
            ),
    );
  }
}
