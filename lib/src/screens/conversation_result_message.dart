import 'package:flutter/material.dart';

import '../conversation/conversation_models.dart';

class ConversationResultMessageHeader extends StatelessWidget {
  const ConversationResultMessageHeader({
    super.key,
    required this.count,
    required this.filters,
    this.fuzzySuggestions = const <String>[],
  });

  final int count;
  final ConversationFilterSet filters;
  final List<String> fuzzySuggestions;

  @override
  Widget build(BuildContext context) {
    final chips = <Widget>[];
    if (filters.subjectTerms.isNotEmpty) chips.add(Chip(label: Text('Sujet : ${filters.subjectTerms.join(' ')}')));
    if (filters.yearMin != null || filters.yearMax != null) {
      chips.add(Chip(label: Text('Période : ${filters.yearMin ?? '…'}–${filters.yearMax ?? '…'}')));
    }
    if (filters.sourceType != null) chips.add(Chip(label: Text('Source : ${filters.sourceType == 'book' ? 'livres' : 'prédications'}')));
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surfaceContainerLow,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Theme.of(context).colorScheme.outlineVariant),
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          Icon(Icons.menu_book_rounded, color: Theme.of(context).colorScheme.primary),
          const SizedBox(width: 8),
          Text('Message Bot', style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w700)),
        ]),
        const SizedBox(height: 8),
        Text('$count passages pertinents trouvés', style: Theme.of(context).textTheme.titleSmall),
        const SizedBox(height: 4),
        const Text('Classement documentaire déterministe • texte canonique uniquement'),
        if (chips.isNotEmpty) ...[
          const SizedBox(height: 10),
          Wrap(spacing: 6, runSpacing: 6, children: chips),
        ],
        if (fuzzySuggestions.isNotEmpty) ...[
          const SizedBox(height: 8),
          Text('Variantes orthographiques examinées : ${fuzzySuggestions.join(', ')}', style: Theme.of(context).textTheme.bodySmall),
        ],
      ]),
    );
  }
}
