import 'package:flutter/material.dart';

import '../app_scope.dart';
import '../models/models.dart';
import '../personal/personal_library.dart';
import 'passage_navigation.dart';

class CollectionsScreen extends StatefulWidget {
  const CollectionsScreen({super.key});

  @override
  State<CollectionsScreen> createState() => _CollectionsScreenState();
}

class _CollectionsScreenState extends State<CollectionsScreen> {
  Future<void> _createCollection() async {
    final controller = TextEditingController();
    final name = await showDialog<String>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Nouvelle collection'),
        content: TextField(
          controller: controller,
          autofocus: true,
          decoration: const InputDecoration(labelText: 'Nom'),
          onSubmitted: (value) => Navigator.pop(dialogContext, value),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(dialogContext), child: const Text('Annuler')),
          FilledButton(onPressed: () => Navigator.pop(dialogContext, controller.text), child: const Text('Créer')),
        ],
      ),
    );
    controller.dispose();
    if (name == null || name.trim().isEmpty || !mounted) return;
    try {
      AppScope.of(context).personalLibrary.createCollection(name);
      setState(() {});
    } catch (_) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Une collection porte déjà ce nom.')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final scope = AppScope.of(context);
    final collections = scope.personalLibrary.collections();
    final bookmarks = scope.personalLibrary.passageBookmarks.toList(growable: false);
    return Scaffold(
      appBar: AppBar(
        title: const Text('Collections'),
        actions: [
          IconButton(onPressed: _createCollection, tooltip: 'Nouvelle collection', icon: const Icon(Icons.create_new_folder_outlined)),
        ],
      ),
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 980),
          child: ListView(
            padding: const EdgeInsets.all(16),
            children: [
              const Card(
                child: Padding(
                  padding: EdgeInsets.all(16),
                  child: Text(
                    'Les collections et chaque Note personnelle sont privées à cet appareil. '
                    'Les notes sont toujours affichées séparément du texte canonique afin d’éviter toute confusion.',
                  ),
                ),
              ),
              const SizedBox(height: 12),
              ListTile(
                leading: const Icon(Icons.bookmarks_outlined),
                title: const Text('Signets de passages'),
                subtitle: Text('${bookmarks.length} passage(s)'),
                trailing: const Icon(Icons.chevron_right),
                onTap: bookmarks.isEmpty
                    ? null
                    : () => Navigator.of(context).push(MaterialPageRoute(
                          builder: (_) => _PassageListScreen(
                            title: 'Signets de passages',
                            passageIds: bookmarks,
                          ),
                        )),
              ),
              const Divider(),
              Row(
                children: [
                  Text('Mes collections', style: Theme.of(context).textTheme.titleLarge),
                  const Spacer(),
                  FilledButton.icon(
                    onPressed: _createCollection,
                    icon: const Icon(Icons.add),
                    label: const Text('Créer'),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              if (collections.isEmpty)
                const Padding(
                  padding: EdgeInsets.all(24),
                  child: Text('Aucune collection. Créez-en une depuis cet écran ou depuis un passage.'),
                )
              else
                ...collections.map((collection) => Card(
                      child: ListTile(
                        leading: const Icon(Icons.folder_outlined),
                        title: Text(collection.name),
                        subtitle: Text('${collection.itemCount} passage(s)'),
                        trailing: const Icon(Icons.chevron_right),
                        onTap: () => Navigator.of(context).push(MaterialPageRoute(
                          builder: (_) => _CollectionDetailScreen(collection: collection),
                        )).then((_) => mounted ? setState(() {}) : null),
                      ),
                    )),
            ],
          ),
        ),
      ),
    );
  }
}

class _PassageListScreen extends StatelessWidget {
  const _PassageListScreen({required this.title, required this.passageIds});
  final String title;
  final List<int> passageIds;

  @override
  Widget build(BuildContext context) {
    final details = AppScope.of(context).repository.studyDetailsForPassageIds(passageIds);
    final items = passageIds.where(details.containsKey).map((id) => details[id]!).toList(growable: false);
    return Scaffold(
      appBar: AppBar(title: Text(title)),
      body: ListView.separated(
        itemCount: items.length,
        separatorBuilder: (_, __) => const Divider(height: 1),
        itemBuilder: (context, index) {
          final item = items[index];
          return ListTile(
            title: Text(item.source.title),
            subtitle: Text('${item.referenceLabel}\n${item.passage.text}', maxLines: 4, overflow: TextOverflow.ellipsis),
            isThreeLine: true,
            onTap: () => openStudyPassage(context, item),
          );
        },
      ),
    );
  }
}

class _CollectionDetailScreen extends StatefulWidget {
  const _CollectionDetailScreen({required this.collection});
  final PersonalCollection collection;

  @override
  State<_CollectionDetailScreen> createState() => _CollectionDetailScreenState();
}

class _CollectionDetailScreenState extends State<_CollectionDetailScreen> {
  Future<void> _addNote(StudyPassage item) async {
    final controller = TextEditingController();
    final note = await showDialog<String>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Note personnelle'),
        content: TextField(
          controller: controller,
          autofocus: true,
          minLines: 3,
          maxLines: 8,
          decoration: const InputDecoration(
            hintText: 'Votre note — distincte du texte du corpus',
          ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(dialogContext), child: const Text('Annuler')),
          FilledButton(onPressed: () => Navigator.pop(dialogContext, controller.text), child: const Text('Enregistrer')),
        ],
      ),
    );
    controller.dispose();
    if (note == null || note.trim().isEmpty || !mounted) return;
    AppScope.of(context).personalLibrary.addNote(item.passage.id, note);
    setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    final scope = AppScope.of(context);
    final ids = scope.personalLibrary.collectionPassageIds(widget.collection.id);
    final details = scope.repository.studyDetailsForPassageIds(ids);
    final items = ids.where(details.containsKey).map((id) => details[id]!).toList(growable: false);
    return Scaffold(
      appBar: AppBar(title: Text(widget.collection.name)),
      body: items.isEmpty
          ? const Center(child: Text('Cette collection ne contient encore aucun passage.'))
          : ListView.separated(
              itemCount: items.length,
              separatorBuilder: (_, __) => const Divider(height: 1),
              itemBuilder: (context, index) {
                final item = items[index];
                final notes = scope.personalLibrary.notesForPassage(item.passage.id);
                return Padding(
                  padding: const EdgeInsets.all(12),
                  child: Card(
                    child: Padding(
                      padding: const EdgeInsets.all(14),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          Text(item.source.title, style: Theme.of(context).textTheme.titleMedium),
                          Text(item.referenceLabel, style: Theme.of(context).textTheme.bodySmall),
                          const SizedBox(height: 10),
                          SelectableText(item.passage.text, maxLines: 8),
                          if (notes.isNotEmpty) ...[
                            const Divider(height: 24),
                            const Text('Notes personnelles', style: TextStyle(fontWeight: FontWeight.w700)),
                            ...notes.map((note) => Padding(
                                  padding: const EdgeInsets.only(top: 6),
                                  child: Text('• ${note.note}'),
                                )),
                          ],
                          const SizedBox(height: 8),
                          Wrap(
                            alignment: WrapAlignment.end,
                            children: [
                              TextButton.icon(
                                onPressed: () => _addNote(item),
                                icon: const Icon(Icons.note_add_outlined),
                                label: const Text('Note personnelle'),
                              ),
                              TextButton.icon(
                                onPressed: () => openStudyPassage(context, item),
                                icon: const Icon(Icons.open_in_new),
                                label: const Text('Ouvrir'),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ),
                );
              },
            ),
    );
  }
}
