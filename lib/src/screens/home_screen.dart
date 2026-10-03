import 'package:flutter/material.dart';

import '../app_scope.dart';
import 'search_results_screen.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  final _controller = TextEditingController();

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Future<void> _search(String value) async {
    final query = value.trim();
    if (query.isEmpty) return;
    final scope = AppScope.of(context);
    if (scope.controller.historyEnabled) scope.personalLibrary.addSearchHistory(query);
    if (!mounted) return;
    await Navigator.of(context).push(
      MaterialPageRoute(builder: (_) => SearchResultsScreen(query: query)),
    );
    if (mounted) setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    final scope = AppScope.of(context);
    final stats = scope.repository.getStats();
    final history = scope.controller.historyEnabled ? scope.personalLibrary.searchHistory : const <String>[];
    return ListView(
      padding: const EdgeInsets.all(20),
      children: [
        Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 900),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const SizedBox(height: 16),
                Icon(
                  Icons.menu_book_rounded,
                  size: 72,
                  color: Theme.of(context).colorScheme.primary,
                ),
                const SizedBox(height: 16),
                Text(
                  'Message Bot',
                  textAlign: TextAlign.center,
                  style: Theme.of(context).textTheme.headlineMedium?.copyWith(fontWeight: FontWeight.w700),
                ),
                const SizedBox(height: 8),
                const Text(
                  'Recherchez un titre, un numéro, quelques mots ou posez une question en français. Les résultats restent des extraits exacts du corpus.',
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 28),
                TextField(
                  controller: _controller,
                  autofocus: false,
                  textInputAction: TextInputAction.search,
                  onSubmitted: _search,
                  decoration: InputDecoration(
                    hintText: 'Ex. Que dit-il au sujet de la foi ?',
                    prefixIcon: const Icon(Icons.search),
                    suffixIcon: IconButton(
                      tooltip: 'Rechercher',
                      onPressed: () => _search(_controller.text),
                      icon: const Icon(Icons.arrow_forward),
                    ),
                  ),
                ),
                const SizedBox(height: 20),
                Wrap(
                  spacing: 10,
                  runSpacing: 10,
                  alignment: WrapAlignment.center,
                  children: [
                    _StatChip(label: '${stats.sermons} prédications', icon: Icons.library_books_outlined),
                    _StatChip(label: '${stats.editions} éditions', icon: Icons.layers_outlined),
                    _StatChip(label: '${stats.passages} passages', icon: Icons.segment),
                    const _StatChip(label: '100 % hors ligne', icon: Icons.cloud_off_outlined),
                  ],
                ),
                if (scope.controller.historyEnabled && history.isNotEmpty) ...[
                  const SizedBox(height: 30),
                  Row(
                    children: [
                      Text('Recherches récentes', style: Theme.of(context).textTheme.titleMedium),
                      const Spacer(),
                      TextButton(
                        onPressed: () async {
                          scope.personalLibrary.clearSearchHistory();
                          if (mounted) setState(() {});
                        },
                        child: const Text('Effacer'),
                      ),
                    ],
                  ),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: history.take(10).map((q) {
                      return ActionChip(
                        label: Text(q, overflow: TextOverflow.ellipsis),
                        onPressed: () {
                          _controller.text = q;
                          _search(q);
                        },
                      );
                    }).toList(),
                  ),
                ],
                const SizedBox(height: 28),
                Card(
                  child: Padding(
                    padding: const EdgeInsets.all(18),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Icon(Icons.verified_outlined),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Text(
                            'La recherche hybride combine un index lexical local et un modèle sémantique local non génératif. Elle ne rédige pas de réponse : elle classe des passages déjà présents dans le corpus.',
                            style: Theme.of(context).textTheme.bodyMedium,
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

class _StatChip extends StatelessWidget {
  const _StatChip({required this.label, required this.icon});
  final String label;
  final IconData icon;

  @override
  Widget build(BuildContext context) {
    return Chip(avatar: Icon(icon, size: 18), label: Text(label));
  }
}
