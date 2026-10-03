import 'package:flutter/material.dart';

import '../app_scope.dart';
import '../models/models.dart';
import 'book_reader_screen.dart';
import 'reader_screen.dart';

class FavoritesScreen extends StatefulWidget {
  const FavoritesScreen({super.key});

  @override
  State<FavoritesScreen> createState() => _FavoritesScreenState();
}

class _FavoritesScreenState extends State<FavoritesScreen> {
  @override
  Widget build(BuildContext context) {
    final scope = AppScope.of(context);
    final keys = scope.personalLibrary.favoriteCodes;
    final sermonCodes = keys.where((key) => !key.startsWith('book:')).toList(growable: false);
    final sermons = scope.repository.sermonsByCodes(sermonCodes);
    final books = keys
        .where((key) => key.startsWith('book:'))
        .map(scope.repository.sourceById)
        .whereType<CorpusSourceSummary>()
        .toList(growable: false);
    if (sermons.isEmpty && books.isEmpty) {
      return const Center(
        child: Padding(
          padding: EdgeInsets.all(24),
          child: Text(
            'Aucun favori pour le moment.\nAjoutez une prédication ou un livre depuis la bibliothèque ou le lecteur.',
            textAlign: TextAlign.center,
          ),
        ),
      );
    }
    final count = sermons.length + books.length;
    return ListView.separated(
      itemCount: count,
      separatorBuilder: (_, __) => const Divider(height: 1),
      itemBuilder: (context, index) {
        if (index < sermons.length) {
          final sermon = sermons[index];
          return ListTile(
            leading: const Icon(Icons.bookmark),
            title: Text(sermon.title),
            subtitle: Text('${sermon.code} • ${sermon.year}'),
            trailing: IconButton(
              tooltip: 'Retirer des favoris',
              icon: const Icon(Icons.close),
              onPressed: () {
                scope.personalLibrary.toggleFavorite(sermon.code);
                setState(() {});
              },
            ),
            onTap: () => Navigator.of(context).push(MaterialPageRoute(
              builder: (_) => ReaderScreen(sermon: sermon, initialEditionId: sermon.primaryEditionId),
            )),
          );
        }
        final source = books[index - sermons.length];
        return ListTile(
          leading: const Icon(Icons.menu_book_outlined),
          title: Text(source.title),
          subtitle: const Text('Livre / exposé'),
          trailing: IconButton(
            tooltip: 'Retirer des favoris',
            icon: const Icon(Icons.close),
            onPressed: () {
              scope.personalLibrary.toggleFavorite(source.id);
              setState(() {});
            },
          ),
          onTap: () => Navigator.of(context).push(MaterialPageRoute(
            builder: (_) => BookReaderScreen(source: source),
          )),
        );
      },
    );
  }
}
