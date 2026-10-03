import 'package:flutter/material.dart';

import '../app_scope.dart';
import '../models/models.dart';
import 'passage_navigation.dart';

class TimelineScreen extends StatefulWidget {
  const TimelineScreen({super.key});

  @override
  State<TimelineScreen> createState() => _TimelineScreenState();
}

class _TimelineScreenState extends State<TimelineScreen> {
  final TextEditingController _controller = TextEditingController();
  List<StudyPassage> _items = const [];
  String _query = '';

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _search() {
    final query = _controller.text.trim();
    if (query.isEmpty) return;
    setState(() {
      _query = query;
      _items = AppScope.of(context).studyEngine.timeline(query, limit: 300);
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Chronologie')),
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 1000),
          child: Column(
            children: [
              Padding(
                padding: const EdgeInsets.all(16),
                child: TextField(
                  controller: _controller,
                  textInputAction: TextInputAction.search,
                  onSubmitted: (_) => _search(),
                  decoration: InputDecoration(
                    labelText: 'Terme à suivre dans le temps',
                    prefixIcon: const Icon(Icons.timeline),
                    suffixIcon: IconButton(onPressed: _search, icon: const Icon(Icons.search)),
                  ),
                ),
              ),
              if (_query.isNotEmpty)
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  child: Align(
                    alignment: Alignment.centerLeft,
                    child: Text('${_items.length} passage(s) pour « $_query »'),
                  ),
                ),
              const SizedBox(height: 8),
              Expanded(
                child: _items.isEmpty
                    ? const Center(child: Text('Saisissez un terme pour afficher les prédications dans l’ordre chronologique.'))
                    : ListView.builder(
                        itemCount: _items.length,
                        itemBuilder: (context, index) {
                          final item = _items[index];
                          final sermon = item.sermon!;
                          return ListTile(
                            leading: CircleAvatar(child: Text('${sermon.year % 100}'.padLeft(2, '0'))),
                            title: Text('${sermon.year} • ${sermon.title}'),
                            subtitle: Text('${sermon.code} • p. ${item.passage.sourcePageStart}\n${item.passage.text}', maxLines: 4, overflow: TextOverflow.ellipsis),
                            isThreeLine: true,
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
