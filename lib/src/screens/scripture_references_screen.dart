import 'package:flutter/material.dart';

import '../app_scope.dart';
import '../models/models.dart';
import '../study_v4/scripture_reference_engine.dart';
import 'passage_navigation.dart';

class ScriptureReferencesScreen extends StatefulWidget {
  const ScriptureReferencesScreen({super.key});

  @override
  State<ScriptureReferencesScreen> createState() => _ScriptureReferencesScreenState();
}

class _ScriptureReferencesScreenState extends State<ScriptureReferencesScreen> {
  final _controller = TextEditingController();
  List<StudyPassage> _results = const [];
  String _query = '';

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _search() {
    final query = _controller.text.trim();
    if (query.isEmpty) return;
    final engine = ScriptureReferenceEngine(AppScope.of(context).repository);
    setState(() {
      _query = query;
      _results = engine.occurrences(query);
    });
  }

  void _open(StudyPassage item) {
    final lower = item.passage.text.toLowerCase();
    final needle = _query.toLowerCase();
    final start = lower.indexOf(needle);
    openStudyPassage(
      context,
      item,
      highlightStartOffset: start >= 0 ? start : null,
      highlightEndOffset: start >= 0 ? start + _query.length : null,
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Références bibliques')),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(16),
            child: TextField(
              controller: _controller,
              textInputAction: TextInputAction.search,
              onSubmitted: (_) => _search(),
              decoration: InputDecoration(
                hintText: 'Ex. Jean 3:16',
                prefixIcon: const Icon(Icons.menu_book_outlined),
                suffixIcon: IconButton(onPressed: _search, icon: const Icon(Icons.search), tooltip: 'Rechercher'),
              ),
            ),
          ),
          Expanded(
            child: _query.isEmpty
                ? const Center(child: Text('Recherchez une référence biblique dans le corpus canonique.'))
                : _results.isEmpty
                    ? const Center(child: Text('Aucune occurrence trouvée.'))
                    : ListView.builder(
                        padding: const EdgeInsets.fromLTRB(12, 0, 12, 16),
                        itemCount: _results.length,
                        itemBuilder: (context, index) {
                          final item = _results[index];
                          return Card(
                            child: ListTile(
                              key: Key('scripture-result-$index'),
                              leading: const Icon(Icons.menu_book_outlined),
                              title: Text(item.referenceLabel),
                              subtitle: Text(item.passage.text, maxLines: 3, overflow: TextOverflow.ellipsis),
                              trailing: const Icon(Icons.open_in_new),
                              onTap: () => _open(item),
                            ),
                          );
                        },
                      ),
          ),
        ],
      ),
    );
  }
}
