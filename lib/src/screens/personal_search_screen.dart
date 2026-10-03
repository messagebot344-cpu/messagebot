import 'package:flutter/material.dart';

import '../app_scope.dart';
import 'passage_navigation.dart';

class PersonalSearchScreen extends StatefulWidget {
  const PersonalSearchScreen({super.key});

  @override
  State<PersonalSearchScreen> createState() => _PersonalSearchScreenState();
}

class _PersonalSearchScreenState extends State<PersonalSearchScreen> {
  final _controller = TextEditingController();
  String _query = '';

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final scope = AppScope.of(context);
    final notes = scope.personalLibrary.searchNotes(_query, limit: 200);
    final details = scope.repository.studyDetailsForPassageIds(notes.map((e) => e.passageId));
    return Scaffold(
      appBar: AppBar(title: const Text('Notes personnelles')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          TextField(
            controller: _controller,
            onChanged: (value) => setState(() => _query = value.trim()),
            decoration: const InputDecoration(prefixIcon: Icon(Icons.search), hintText: 'Rechercher dans vos notes locales'),
          ),
          const SizedBox(height: 12),
          const Text('Les notes restent séparées du corpus canonique et ne sont jamais présentées comme une citation.', style: TextStyle(fontStyle: FontStyle.italic)),
          const SizedBox(height: 12),
          ...notes.map((note) {
            final item = details[note.passageId];
            return Card(child: ListTile(
              leading: const Icon(Icons.note_outlined),
              title: Text(note.note),
              subtitle: item == null ? const Text('Passage associé indisponible') : Text(item.referenceLabel),
              onTap: item == null ? null : () => openStudyPassage(context, item),
            ));
          }),
        ],
      ),
    );
  }
}
