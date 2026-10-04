import 'package:flutter/material.dart';

import '../app_scope.dart';
import '../models/models.dart';
import 'passage_navigation.dart';

class SearchResultsScreen extends StatefulWidget {
  const SearchResultsScreen({super.key, required this.query});

  final String query;

  @override
  State<SearchResultsScreen> createState() => _SearchResultsScreenState();
}

class _SearchResultsScreenState extends State<SearchResultsScreen> {
  late final TextEditingController _controller;
  late Future<List<DocumentSearchHit>> _future;
  bool _initialized = false;
  static const int _fetchLimit = 50;
  int _visibleLimit = 10;

  @override
  void initState() {
    super.initState();
    _controller = TextEditingController(text: widget.query);
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_initialized) return;
    _initialized = true;
    _future = AppScope.of(context)
        .searchService
        .searchDocuments(_controller.text, limit: _fetchLimit);
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Future<void> _runSearch({bool resetLimit = true}) async {
    final query = _controller.text.trim();
    if (query.isEmpty) return;
    final scope = AppScope.of(context);
    if (scope.controller.historyEnabled) scope.personalLibrary.addSearchHistory(query);
    if (!mounted) return;
    setState(() {
      if (resetLimit) _visibleLimit = 10;
      _future = scope.searchService.searchDocuments(
        query,
        limit: _fetchLimit,
      );
    });
  }

  void _loadMore() {
    if (_visibleLimit >= _fetchLimit) return;
    setState(() {
      _visibleLimit =
          (_visibleLimit + 10).clamp(10, _fetchLimit).toInt();
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Résultats de recherche')),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(16),
            child: TextField(
              controller: _controller,
              onSubmitted: (_) => _runSearch(),
              textInputAction: TextInputAction.search,
              decoration: InputDecoration(
                labelText: 'Recherche',
                prefixIcon: const Icon(Icons.search),
                suffixIcon: IconButton(
                  onPressed: () => _runSearch(),
                  icon: const Icon(Icons.arrow_forward),
                  tooltip: 'Rechercher',
                ),
              ),
            ),
          ),
          Expanded(
            child: FutureBuilder<List<DocumentSearchHit>>(
              future: _future,
              builder: (context, snapshot) {
                if (snapshot.connectionState != ConnectionState.done) {
                  return const Center(child: CircularProgressIndicator());
                }
                if (snapshot.hasError) {
                  return Center(
                    child: Padding(
                      padding: const EdgeInsets.all(24),
                      child: Text('Erreur de recherche : ${snapshot.error}'),
                    ),
                  );
                }
                final allHits =
                    snapshot.data ?? const <DocumentSearchHit>[];
                final hits = allHits
                    .take(_visibleLimit)
                    .toList(growable: false);
                if (hits.isEmpty) {
                  return const Center(
                    child: Padding(
                      padding: EdgeInsets.all(24),
                      child: Text(
                        'Aucun passage suffisamment pertinent n’a été trouvé. Essayez une formulation différente ou des mots plus précis.',
                        textAlign: TextAlign.center,
                      ),
                    ),
                  );
                }
                final canLoadMore =
                    hits.length < allHits.length &&
                    _visibleLimit < _fetchLimit;
                return ListView.separated(
                  padding: const EdgeInsets.fromLTRB(12, 0, 12, 24),
                  itemCount: hits.length + 1,
                  separatorBuilder: (_, __) => const SizedBox(height: 10),
                  itemBuilder: (context, index) {
                    if (index == hits.length) {
                      return Padding(
                        padding: const EdgeInsets.symmetric(vertical: 8),
                        child: Center(
                          child: canLoadMore
                              ? OutlinedButton.icon(
                                  onPressed: _loadMore,
                                  icon: const Icon(Icons.expand_more),
                                  label: const Text('Afficher 10 résultats de plus'),
                                )
                              : Text(
                                  '${hits.length} résultat(s) affiché(s)',
                                  style: Theme.of(context).textTheme.bodySmall,
                                ),
                        ),
                      );
                    }
                    return _DocumentHitCard(hit: hits[index], rank: index + 1);
                  },
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}

class _DocumentHitCard extends StatelessWidget {
  const _DocumentHitCard({required this.hit, required this.rank});

  final DocumentSearchHit hit;
  final int rank;

  @override
  Widget build(BuildContext context) {
    final item = hit.studyPassage;
    final passage = item.passage;
    final pageLabel = passage.sourcePageStart == passage.sourcePageEnd
        ? 'page source ${passage.sourcePageStart}'
        : 'pages source ${passage.sourcePageStart}–${passage.sourcePageEnd}';
    final snippet = passage.text.replaceAll(RegExp(r'\s+'), ' ').trim();
    final shortSnippet = snippet.length > 720 ? '${snippet.substring(0, 720)}…' : snippet;
    final sourceLine = item.sermon != null
        ? '${item.sermon!.code} • $pageLabel${item.edition?.isPrimary == false ? ' • édition alternative' : ''}'
        : '${item.chapterTitle ?? 'Livre'} • $pageLabel';
    return Card(
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: () => openStudyPassage(
          context,
          item,
          highlightStartOffset: hit.highlightStartOffset,
          highlightEndOffset: hit.highlightEndOffset,
        ),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  CircleAvatar(radius: 16, child: Text('$rank')),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(item.source.title, style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w700)),
                        const SizedBox(height: 2),
                        Text(sourceLine),
                      ],
                    ),
                  ),
                  if (item.source.type == CorpusSourceType.book)
                    const Padding(
                      padding: EdgeInsets.only(left: 8),
                      child: Chip(label: Text('Livre')),
                    ),
                ],
              ),
              const SizedBox(height: 14),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Theme.of(context).colorScheme.primaryContainer.withValues(alpha: 0.45),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: SelectableText(hit.highlightSentence, style: const TextStyle(fontWeight: FontWeight.w600)),
              ),
              const SizedBox(height: 12),
              SelectableText(shortSnippet, maxLines: 8),
              const SizedBox(height: 8),
              Align(
                alignment: Alignment.centerRight,
                child: TextButton.icon(
                  onPressed: () => openStudyPassage(
          context,
          item,
          highlightStartOffset: hit.highlightStartOffset,
          highlightEndOffset: hit.highlightEndOffset,
        ),
                  icon: const Icon(Icons.open_in_new),
                  label: const Text('Ouvrir au passage'),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
