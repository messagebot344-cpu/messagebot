import 'package:flutter/material.dart';

import 'collections_screen.dart';
import 'concordance_screen.dart';
import 'timeline_screen.dart';

class StudyScreen extends StatelessWidget {
  const StudyScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.all(20),
      children: [
        Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 980),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text(
                  'Étudier le corpus',
                  style: Theme.of(context).textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.w700),
                ),
                const SizedBox(height: 8),
                const Text(
                  'Explorer les mots, les périodes et vos propres collections sans générer ni reformuler le contenu des prédications.',
                ),
                const SizedBox(height: 20),
                Wrap(
                  spacing: 14,
                  runSpacing: 14,
                  children: [
                    _StudyCard(
                      icon: Icons.menu_book_outlined,
                      title: 'Concordance',
                      description: 'Retrouver un terme et toutes ses occurrences dans les prédications et les livres.',
                      onTap: () => Navigator.of(context).push(MaterialPageRoute(builder: (_) => const ConcordanceScreen())),
                    ),
                    _StudyCard(
                      icon: Icons.timeline_outlined,
                      title: 'Chronologie',
                      description: 'Observer les passages contenant un terme dans l’ordre chronologique des prédications.',
                      onTap: () => Navigator.of(context).push(MaterialPageRoute(builder: (_) => const TimelineScreen())),
                    ),
                    _StudyCard(
                      icon: Icons.folder_copy_outlined,
                      title: 'Collections',
                      description: 'Organiser vos passages, signets et notes personnelles uniquement sur cet appareil.',
                      onTap: () => Navigator.of(context).push(MaterialPageRoute(builder: (_) => const CollectionsScreen())),
                    ),
                  ],
                ),
                const SizedBox(height: 20),
                const Card(
                  child: Padding(
                    padding: EdgeInsets.all(16),
                    child: Text(
                      'Les fonctions d’étude mettent en relation des références existantes. Elles ne déclarent jamais ce que le corpus « veut dire » : le lecteur conserve l’interprétation.',
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

class _StudyCard extends StatelessWidget {
  const _StudyCard({required this.icon, required this.title, required this.description, required this.onTap});

  final IconData icon;
  final String title;
  final String description;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 290,
      child: Card(
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.all(18),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Icon(icon, size: 34, color: Theme.of(context).colorScheme.primary),
                const SizedBox(height: 14),
                Text(title, style: Theme.of(context).textTheme.titleLarge),
                const SizedBox(height: 8),
                Text(description),
                const SizedBox(height: 12),
                const Align(alignment: Alignment.centerRight, child: Icon(Icons.arrow_forward)),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
