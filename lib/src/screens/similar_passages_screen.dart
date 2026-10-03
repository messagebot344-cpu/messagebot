import 'package:flutter/material.dart';

import '../app_scope.dart';
import 'comparison_screen.dart';
import 'passage_navigation.dart';

class SimilarPassagesScreen extends StatefulWidget {
  const SimilarPassagesScreen({super.key, required this.passageId});
  final int passageId;

  @override
  State<SimilarPassagesScreen> createState() => _SimilarPassagesScreenState();
}

class _SimilarPassagesScreenState extends State<SimilarPassagesScreen> {
  String? _scope;

  @override
  Widget build(BuildContext context) {
    final app = AppScope.of(context);
    final source = app.repository.studyDetailsForPassageIds([widget.passageId])[widget.passageId];
    final results = app.studyEngine.similarity.similarPassages(widget.passageId, limit: 40, relationScope: _scope);
    return Scaffold(
      appBar: AppBar(title: const Text('Passages similaires')),
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 1050),
          child: Column(
            children: [
              Padding(
                padding: const EdgeInsets.all(16),
                child: SegmentedButton<String?>(
                  segments: const [
                    ButtonSegment(value: null, label: Text('Tous')),
                    ButtonSegment(value: 'same_source', label: Text('Même source')),
                    ButtonSegment(value: 'other_source', label: Text('Autres sources')),
                  ],
                  selected: {_scope},
                  onSelectionChanged: (value) => setState(() => _scope = value.first),
                ),
              ),
              Expanded(
                child: results.isEmpty
                    ? const Center(child: Text('Aucun passage voisin disponible.'))
                    : ListView.separated(
                        itemCount: results.length,
                        separatorBuilder: (_, __) => const Divider(height: 1),
                        itemBuilder: (context, index) {
                          final result = results[index];
                          final item = result.passage;
                          final percent = (result.score.clamp(0, 1) * 100).round();
                          return ListTile(
                            leading: CircleAvatar(child: Text('$percent%')),
                            title: Text(item.source.title, maxLines: 1, overflow: TextOverflow.ellipsis),
                            subtitle: Text('${item.referenceLabel}\n${item.passage.text}', maxLines: 4, overflow: TextOverflow.ellipsis),
                            isThreeLine: true,
                            trailing: source == null
                                ? null
                                : IconButton(
                                    tooltip: 'Comparer les deux passages',
                                    icon: const Icon(Icons.compare_arrows),
                                    onPressed: () => Navigator.of(context).push(MaterialPageRoute(
                                      builder: (_) => ComparisonScreen(passageA: source, passageB: item),
                                    )),
                                  ),
                            onTap: () => openStudyPassage(context, item),
                          );
                        },
                      ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
