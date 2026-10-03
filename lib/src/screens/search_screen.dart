import 'package:flutter/material.dart';

import '../app_scope.dart';
import 'search_results_screen.dart';

class SearchScreen extends StatefulWidget {
  const SearchScreen({super.key});

  @override
  State<SearchScreen> createState() => _SearchScreenState();
}

class _SearchScreenState extends State<SearchScreen> {
  final TextEditingController _controller = TextEditingController();

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Future<void> _search(String raw) async {
    final query = raw.trim();
    if (query.isEmpty) return;
    final scope = AppScope.of(context);
    if (scope.controller.historyEnabled) {
      scope.personalLibrary.addSearchHistory(query);
    }
    if (!mounted) return;
    await Navigator.of(context).push(
      MaterialPageRoute(builder: (_) => SearchResultsScreen(query: query)),
    );
    if (mounted) setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    final scope = AppScope.of(context);
    final history = scope.controller.historyEnabled
        ? scope.personalLibrary.searchHistory
        : const <String>[];
    return ListView(
      padding: const EdgeInsets.all(20),
      children: [
        Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 920),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text(
                  'Rechercher dans le corpus',
                  style: Theme.of(context).textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.w700),
                ),
                const SizedBox(height: 8),
                const Text(
                  'Titre, numéro, citation exacte, mots-clés ou question en français. '
                  'Le moteur classe uniquement des passages existants : il ne rédige aucune réponse.',
                ),
                const SizedBox(height: 20),
                TextField(
                  controller: _controller,
                  autofocus: true,
                  textInputAction: TextInputAction.search,
                  onSubmitted: _search,
                  decoration: InputDecoration(
                    hintText: 'Ex. Que dit-il au sujet de la foi ?',
                    prefixIcon: const Icon(Icons.manage_search),
                    suffixIcon: IconButton(
                      tooltip: 'Rechercher',
                      onPressed: () => _search(_controller.text),
                      icon: const Icon(Icons.arrow_forward),
                    ),
                  ),
                ),
                const SizedBox(height: 12),
                const Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    Chip(label: Text('Tout le corpus')),
                    Chip(label: Text('Prédications')),
                    Chip(label: Text('Livres')),
                    Chip(label: Text('100 % hors ligne')),
                  ],
                ),
                if (history.isNotEmpty) ...[
                  const SizedBox(height: 28),
                  Row(
                    children: [
                      Text('Recherches récentes', style: Theme.of(context).textTheme.titleMedium),
                      const Spacer(),
                      TextButton(
                        onPressed: () {
                          scope.personalLibrary.clearSearchHistory();
                          setState(() {});
                        },
                        child: const Text('Effacer'),
                      ),
                    ],
                  ),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: history.take(12).map((query) => ActionChip(
                      label: Text(query, overflow: TextOverflow.ellipsis),
                      onPressed: () {
                        _controller.text = query;
                        _search(query);
                      },
                    )).toList(),
                  ),
                ],
                const SizedBox(height: 24),
                Card(
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Icon(Icons.verified_outlined, color: Theme.of(context).colorScheme.primary),
                        const SizedBox(width: 12),
                        const Expanded(
                          child: Text(
                            'Fidélité absolue : chaque résultat ouvre le texte canonique et sa page source. '
                            'Les scores sémantiques servent uniquement au classement.',
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}
