import 'package:flutter/material.dart';

import '../conversation/conversation_models.dart';
import '../theme/grenier_tokens.dart';

class ConversationResultMessageHeader extends StatelessWidget {
  const ConversationResultMessageHeader({
    super.key,
    required this.count,
    required this.filters,
    this.fuzzySuggestions = const <String>[],
    this.onAddFilter,
    this.onRemoveSubject,
    this.onRemovePeriod,
    this.onRemoveSource,
  });

  final int count;
  final ConversationFilterSet filters;
  final List<String> fuzzySuggestions;
  final VoidCallback? onAddFilter;
  final VoidCallback? onRemoveSubject;
  final VoidCallback? onRemovePeriod;
  final VoidCallback? onRemoveSource;

  @override
  Widget build(BuildContext context) {
    final chips = <Widget>[];
    if (filters.subjectTerms.isNotEmpty) {
      chips.add(InputChip(
        label: Text('Sujet : ${filters.subjectTerms.join(' ')}'),
        onDeleted: onRemoveSubject,
      ));
    }
    if (filters.yearMin != null || filters.yearMax != null) {
      chips.add(InputChip(
        label: Text('Période : ${filters.yearMin ?? '…'}–${filters.yearMax ?? '…'}'),
        onDeleted: onRemovePeriod,
      ));
    }
    if (filters.sourceType != null) {
      chips.add(InputChip(
        label: Text('Source : ${filters.sourceType == 'book' ? 'livres' : 'prédications'}'),
        onDeleted: onRemoveSource,
      ));
    }

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Theme.of(context).colorScheme.outlineVariant),
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(
          children: [
            const Icon(Icons.menu_book_rounded, color: GrenierPalette.actionBlue),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                GrenierBrand.name,
                style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w800),
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),
        Text('$count passages pertinents trouvés', style: Theme.of(context).textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w700)),
        const SizedBox(height: 4),
        const Text('Classement documentaire déterministe • texte canonique uniquement'),
        const SizedBox(height: 10),
        Wrap(
          spacing: 6,
          runSpacing: 6,
          crossAxisAlignment: WrapCrossAlignment.center,
          children: [
            ...chips,
            ActionChip(
              avatar: const Icon(Icons.add, size: 18),
              label: const Text('Ajouter un filtre'),
              onPressed: onAddFilter,
            ),
          ],
        ),
        if (fuzzySuggestions.isNotEmpty) ...[
          const SizedBox(height: 8),
          Text(
            'Variantes orthographiques examinées : ${fuzzySuggestions.join(', ')}',
            style: Theme.of(context).textTheme.bodySmall,
          ),
        ],
      ]),
    );
  }
}
