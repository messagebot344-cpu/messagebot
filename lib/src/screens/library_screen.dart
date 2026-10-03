import 'package:flutter/material.dart';

import '../app_scope.dart';
import '../models/models.dart';
import 'book_reader_screen.dart';
import 'reader_screen.dart';

class LibraryScreen extends StatefulWidget {
  const LibraryScreen({super.key});

  @override
  State<LibraryScreen> createState() => _LibraryScreenState();
}

class _LibraryScreenState extends State<LibraryScreen> {
  final _filter = TextEditingController();
  String _query = '';
  CorpusSourceType _type = CorpusSourceType.sermon;

  @override
  void dispose() {
    _filter.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final scope = AppScope.of(context);
    final sermons = _type == CorpusSourceType.sermon
        ? scope.repository.listSermons(filter: _query)
        : const <SermonSummary>[];
    final books = _type == CorpusSourceType.book
        ? scope.repository.listBookSources(filter: _query)
        : const <CorpusSourceSummary>[];
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
          child: Column(
            children: [
              SegmentedButton<CorpusSourceType>(
                segments: const [
                  ButtonSegment(value: CorpusSourceType.sermon, label: Text('Prédications'), icon: Icon(Icons.record_voice_over_outlined)),
                  ButtonSegment(value: CorpusSourceType.book, label: Text('Livres / Exposés'), icon: Icon(Icons.menu_book_outlined)),
                ],
                selected: {_type},
                onSelectionChanged: (values) => setState(() => _type = values.first),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: _filter,
                onChanged: (value) => setState(() => _query = value),
                decoration: InputDecoration(
                  labelText: _type == CorpusSourceType.sermon ? 'Filtrer par titre ou numéro' : 'Filtrer les livres',
                  prefixIcon: const Icon(Icons.filter_alt_outlined),
                ),
              ),
            ],
          ),
        ),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 6),
          child: Align(
            alignment: Alignment.centerLeft,
            child: Text(_type == CorpusSourceType.sermon
                ? '${sermons.length} prédication(s)'
                : '${books.length} livre(s) / exposé(s)'),
          ),
        ),
        Expanded(
          child: _type == CorpusSourceType.sermon
              ? (sermons.isEmpty
                  ? const Center(child: Text('Aucune prédication correspondante.'))
                  : ListView.separated(
                      itemCount: sermons.length,
                      separatorBuilder: (_, __) => const Divider(height: 1),
                      itemBuilder: (context, index) => _SermonTile(sermon: sermons[index]),
                    ))
              : (books.isEmpty
                  ? const Center(child: Text('Aucun livre correspondant.'))
                  : ListView.separated(
                      itemCount: books.length,
                      separatorBuilder: (_, __) => const Divider(height: 1),
                      itemBuilder: (context, index) => _BookTile(source: books[index]),
                    )),
        ),
      ],
    );
  }
}

class _SermonTile extends StatefulWidget {
  const _SermonTile({required this.sermon});
  final SermonSummary sermon;

  @override
  State<_SermonTile> createState() => _SermonTileState();
}

class _SermonTileState extends State<_SermonTile> {
  @override
  Widget build(BuildContext context) {
    final scope = AppScope.of(context);
    final favorite = scope.personalLibrary.isFavorite(widget.sermon.code);
    return ListTile(
      leading: CircleAvatar(child: Text(widget.sermon.code.substring(0, 2))),
      title: Text(widget.sermon.title, maxLines: 2, overflow: TextOverflow.ellipsis),
      subtitle: Text(
        '${widget.sermon.code} • ${widget.sermon.year}'
        '${widget.sermon.editionCount > 1 ? ' • ${widget.sermon.editionCount} éditions' : ''}',
      ),
      trailing: IconButton(
        tooltip: favorite ? 'Retirer des favoris' : 'Ajouter aux favoris',
        icon: Icon(favorite ? Icons.bookmark : Icons.bookmark_border),
        onPressed: () {
          scope.personalLibrary.toggleFavorite(widget.sermon.code);
          setState(() {});
        },
      ),
      onTap: () => Navigator.of(context).push(MaterialPageRoute(
        builder: (_) => ReaderScreen(
          sermon: widget.sermon,
          initialEditionId: widget.sermon.primaryEditionId,
        ),
      )),
    );
  }
}

class _BookTile extends StatefulWidget {
  const _BookTile({required this.source});
  final CorpusSourceSummary source;

  @override
  State<_BookTile> createState() => _BookTileState();
}

class _BookTileState extends State<_BookTile> {
  @override
  Widget build(BuildContext context) {
    final scope = AppScope.of(context);
    final favorite = scope.personalLibrary.isFavorite(widget.source.id);
    final chapters = scope.repository.chaptersForBook(widget.source.id);
    return ListTile(
      leading: const CircleAvatar(child: Icon(Icons.menu_book_outlined)),
      title: Text(widget.source.title),
      subtitle: Text('${chapters.length} chapitre(s) • texte séparé des prédications'),
      trailing: IconButton(
        tooltip: favorite ? 'Retirer des favoris' : 'Ajouter aux favoris',
        icon: Icon(favorite ? Icons.bookmark : Icons.bookmark_border),
        onPressed: () {
          scope.personalLibrary.toggleFavorite(widget.source.id);
          setState(() {});
        },
      ),
      onTap: () => Navigator.of(context).push(MaterialPageRoute(
        builder: (_) => BookReaderScreen(source: widget.source),
      )),
    );
  }
}
