import 'package:flutter/material.dart';

import '../app_scope.dart';

Future<void> addPassageToCollection(BuildContext context, int passageId) async {
  final scope = AppScope.of(context);
  var collections = scope.personalLibrary.collections();
  if (collections.isEmpty) {
    final name = await _askCollectionName(context);
    if (name == null || name.trim().isEmpty || !context.mounted) return;
    try {
      scope.personalLibrary.createCollection(name);
    } catch (_) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Ce nom de collection existe déjà.')),
        );
      }
      return;
    }
    collections = scope.personalLibrary.collections();
  }
  if (!context.mounted) return;
  final selected = await showDialog<int>(
    context: context,
    builder: (dialogContext) => AlertDialog(
      title: const Text('Ajouter à une collection'),
      content: SizedBox(
        width: 420,
        child: ListView(
          shrinkWrap: true,
          children: collections
              .map((collection) => ListTile(
                    leading: const Icon(Icons.folder_outlined),
                    title: Text(collection.name),
                    subtitle: Text('${collection.itemCount} passage(s)'),
                    onTap: () => Navigator.pop(dialogContext, collection.id),
                  ))
              .toList(),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(dialogContext),
          child: const Text('Annuler'),
        ),
      ],
    ),
  );
  if (selected == null || !context.mounted) return;
  scope.personalLibrary.addToCollection(selected, passageId);
  ScaffoldMessenger.of(context).showSnackBar(
    const SnackBar(content: Text('Passage ajouté à la collection.')),
  );
}

Future<String?> _askCollectionName(BuildContext context) async {
  final controller = TextEditingController();
  final value = await showDialog<String>(
    context: context,
    builder: (dialogContext) => AlertDialog(
      title: const Text('Nouvelle collection'),
      content: TextField(
        controller: controller,
        autofocus: true,
        decoration: const InputDecoration(labelText: 'Nom de la collection'),
        onSubmitted: (value) => Navigator.pop(dialogContext, value),
      ),
      actions: [
        TextButton(onPressed: () => Navigator.pop(dialogContext), child: const Text('Annuler')),
        FilledButton(onPressed: () => Navigator.pop(dialogContext, controller.text), child: const Text('Créer')),
      ],
    ),
  );
  controller.dispose();
  return value;
}
