import 'package:flutter/material.dart';

import '../app_scope.dart';
import '../models/models.dart';

class ComparisonScreen extends StatelessWidget {
  const ComparisonScreen({super.key, required this.passageA, required this.passageB});

  final StudyPassage passageA;
  final StudyPassage passageB;

  @override
  Widget build(BuildContext context) {
    final comparison = AppScope.of(context).studyEngine.comparison.compare(
      passageA.passage.text,
      passageB.passage.text,
    );
    final percent = (comparison.similarity * 100).round();
    return Scaffold(
      appBar: AppBar(title: const Text('Comparer deux passages')),
      body: LayoutBuilder(
        builder: (context, constraints) {
          final panels = [
            _PassagePanel(label: 'Passage A', item: passageA),
            _PassagePanel(label: 'Passage B', item: passageB),
          ];
          return ListView(
            padding: const EdgeInsets.all(16),
            children: [
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Wrap(
                    spacing: 20,
                    runSpacing: 8,
                    children: [
                      Text('Similarité lexicale : $percent %'),
                      Text('${comparison.commonWordCount} mots distincts communs'),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 12),
              if (constraints.maxWidth >= 850)
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(child: panels[0]),
                    const SizedBox(width: 12),
                    Expanded(child: panels[1]),
                  ],
                )
              else ...[
                panels[0],
                const SizedBox(height: 12),
                panels[1],
              ],
              const SizedBox(height: 16),
              const Text(
                'Cette comparaison indique uniquement des ressemblances textuelles calculées. Elle ne produit aucune conclusion doctrinale.',
              ),
            ],
          );
        },
      ),
    );
  }
}

class _PassagePanel extends StatelessWidget {
  const _PassagePanel({required this.label, required this.item});
  final String label;
  final StudyPassage item;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(label, style: Theme.of(context).textTheme.labelLarge),
            const SizedBox(height: 4),
            Text(item.source.title, style: Theme.of(context).textTheme.titleMedium),
            Text(item.referenceLabel, style: Theme.of(context).textTheme.bodySmall),
            const Divider(height: 24),
            SelectableText(item.passage.text, style: const TextStyle(height: 1.5)),
          ],
        ),
      ),
    );
  }
}
