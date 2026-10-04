import 'package:flutter/material.dart';

import '../app_scope.dart';
import '../models/models.dart';
import 'comparison_screen.dart';

class ComparisonPickerScreen extends StatefulWidget {
  const ComparisonPickerScreen({super.key, this.initialPassage});

  final StudyPassage? initialPassage;

  @override
  State<ComparisonPickerScreen> createState() => _ComparisonPickerScreenState();
}

class _ComparisonPickerScreenState extends State<ComparisonPickerScreen> {
  final _controller = TextEditingController();
  List<DocumentSearchHit> _results = const [];
  StudyPassage? _passageA;
  StudyPassage? _passageB;
  bool _busy = false;

  @override
  void initState() {
    super.initState();
    _passageA = widget.initialPassage;
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Future<void> _search() async {
    final query = _controller.text.trim();
    if (query.isEmpty || _busy) return;
    setState(() => _busy = true);
    final values = await AppScope.of(context).searchService.searchDocuments(query, limit: 60);
    if (!mounted) return;
    setState(() {
      _results = values;
      _busy = false;
    });
  }

  void _choose(StudyPassage passage) {
    setState(() {
      if (_passageA == null) {
        _passageA = passage;
      } else {
        _passageB = passage;
      }
    });
  }

  void _compare() {
    final a = _passageA;
    final b = _passageB;
    if (a == null || b == null) return;
    Navigator.of(context).push(MaterialPageRoute(
      builder: (_) => ComparisonScreen(passageA: a, passageB: b),
    ));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Comparer deux passages')),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 14, 16, 10),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    _SelectedPassageChip(
                      label: 'Passage A',
                      passage: _passageA,
                      onClear: () => setState(() {
                        _passageA = null;
                        _passageB = null;
                      }),
                    ),
                    _SelectedPassageChip(
                      label: 'Passage B',
                      passage: _passageB,
                      onClear: () => setState(() => _passageB = null),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: _controller,
                  textInputAction: TextInputAction.search,
                  onSubmitted: (_) => _search(),
                  decoration: InputDecoration(
                    hintText: _passageA == null ? 'Rechercher le premier passage' : 'Rechercher le passage à comparer',
                    prefixIcon: const Icon(Icons.search),
                    suffixIcon: _busy
                        ? const Padding(
                            padding: EdgeInsets.all(14),
                            child: SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2)),
                          )
                        : IconButton(onPressed: _search, icon: const Icon(Icons.arrow_forward), tooltip: 'Rechercher'),
                  ),
                ),
                const SizedBox(height: 10),
                FilledButton.icon(
                  onPressed: _passageA != null && _passageB != null ? _compare : null,
                  icon: const Icon(Icons.compare_arrows),
                  label: const Text('Comparer'),
                ),
              ],
            ),
          ),
          const Divider(height: 1),
          Expanded(
            child: _results.isEmpty
                ? Center(
                    child: Text(
                      _busy ? 'Recherche…' : 'Recherchez un passage puis sélectionnez-le.',
                      textAlign: TextAlign.center,
                    ),
                  )
                : ListView.builder(
                    padding: const EdgeInsets.all(12),
                    itemCount: _results.length,
                    itemBuilder: (context, index) {
                      final hit = _results[index];
                      final item = hit.studyPassage;
                      return Card(
                        child: ListTile(
                          title: Text(item.referenceLabel, maxLines: 2, overflow: TextOverflow.ellipsis),
                          subtitle: Text(hit.highlightSentence, maxLines: 3, overflow: TextOverflow.ellipsis),
                          trailing: const Icon(Icons.add_circle_outline),
                          onTap: () => _choose(item),
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

class _SelectedPassageChip extends StatelessWidget {
  const _SelectedPassageChip({
    required this.label,
    required this.passage,
    required this.onClear,
  });

  final String label;
  final StudyPassage? passage;
  final VoidCallback onClear;

  @override
  Widget build(BuildContext context) {
    final passage = this.passage;
    if (passage == null) return Chip(label: Text('$label : non sélectionné'));
    return InputChip(
      label: Text('$label : ${passage.referenceLabel}', overflow: TextOverflow.ellipsis),
      onDeleted: onClear,
    );
  }
}
