import 'package:flutter/material.dart';

import '../app_scope.dart';

class SettingsScreen extends StatelessWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final scope = AppScope.of(context);
    final controller = scope.controller;
    final stats = scope.repository.getStats();
    return Scaffold(
      appBar: AppBar(title: const Text('Réglages et à propos')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Text('Apparence', style: Theme.of(context).textTheme.titleLarge),
          const SizedBox(height: 12),
          LayoutBuilder(builder: (context, constraints) {
            if (constraints.maxWidth < 520) {
              return DropdownButtonFormField<ThemeMode>(
                initialValue: controller.themeMode,
                isExpanded: true,
                decoration: const InputDecoration(labelText: 'Thème', prefixIcon: Icon(Icons.palette_outlined)),
                items: const [
                  DropdownMenuItem(value: ThemeMode.system, child: Text('Système')),
                  DropdownMenuItem(value: ThemeMode.light, child: Text('Clair')),
                  DropdownMenuItem(value: ThemeMode.dark, child: Text('Sombre')),
                ],
                onChanged: (value) { if (value != null) controller.setThemeMode(value); },
              );
            }
            return SegmentedButton<ThemeMode>(
              segments: const [
                ButtonSegment(value: ThemeMode.system, label: Text('Système'), icon: Icon(Icons.brightness_auto_outlined)),
                ButtonSegment(value: ThemeMode.light, label: Text('Clair'), icon: Icon(Icons.light_mode_outlined)),
                ButtonSegment(value: ThemeMode.dark, label: Text('Sombre'), icon: Icon(Icons.dark_mode_outlined)),
              ],
              selected: {controller.themeMode},
              onSelectionChanged: (values) => controller.setThemeMode(values.first),
            );
          }),
          const SizedBox(height: 20),
          Text('Taille du texte de lecture : ${controller.fontSize.round()} px'),
          Slider(min: 14, max: 28, divisions: 14, value: controller.fontSize.clamp(14, 28).toDouble(), onChanged: controller.setFontSize),
          const Divider(height: 32),
          Text('Confidentialité locale', style: Theme.of(context).textTheme.titleLarge),
          SwitchListTile(
            contentPadding: EdgeInsets.zero,
            title: const Text('Conserver l’historique de recherche'),
            subtitle: const Text('L’historique et les conversations restent uniquement sur cet appareil.'),
            value: controller.historyEnabled,
            onChanged: controller.setHistoryEnabled,
          ),
          ListTile(
            contentPadding: EdgeInsets.zero,
            leading: const Icon(Icons.delete_outline),
            title: const Text('Effacer l’historique de recherche'),
            onTap: () {
              scope.personalLibrary.clearSearchHistory();
              ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Historique effacé.')));
            },
          ),
          const Divider(height: 32),
          Text('Moteur documentaire V4', style: Theme.of(context).textTheme.titleLarge),
          const ListTile(
            contentPadding: EdgeInsets.zero,
            leading: Icon(Icons.rule_folder_outlined),
            title: Text('Recherche déterministe locale'),
            subtitle: Text('FTS5/BM25, citation exacte, proximité, variantes morphologiques et correspondances orthographiques. Aucun LLM, embedding neuronal ou LSA n’est chargé au runtime.'),
          ),
          const ListTile(
            contentPadding: EdgeInsets.zero,
            leading: Icon(Icons.cloud_off_outlined),
            title: Text('100 % hors ligne'),
            subtitle: Text('Le corpus, la recherche, les conversations et les données personnelles restent locaux.'),
          ),
          const Divider(height: 32),
          Text('Corpus', style: Theme.of(context).textTheme.titleLarge),
          _InfoRow(label: 'Prédications', value: '${stats.sermons}'),
          _InfoRow(label: 'Éditions', value: '${stats.editions}'),
          _InfoRow(label: 'Passages', value: '${stats.passages}'),
          _InfoRow(label: 'Pages source', value: '${stats.sourcePdfPages}'),
          const Divider(height: 32),
          Text('Avant-propos', style: Theme.of(context).textTheme.titleLarge),
          const Card(
            child: Padding(
              padding: EdgeInsets.all(18),
              child: SelectableText(
                'Ce logiciel est conçu par le frère Erly Rolvinst BASSOMBI\n'
                '242 069101357\n'
                'ebassombi@gmail.com',
              ),
            ),
          ),
          const SizedBox(height: 12),
          ListTile(
            contentPadding: EdgeInsets.zero,
            leading: const Icon(Icons.description_outlined),
            title: const Text('Licences des composants logiciels'),
            onTap: () => showLicensePage(context: context, applicationName: 'Message Bot', applicationVersion: '4.0.0'),
          ),
          const SizedBox(height: 20),
          Text(
            'Message Bot 4.0.0 • Corpus source version juin 2019 • Recherche V4 déterministe, hors ligne et non générative.',
            style: Theme.of(context).textTheme.bodySmall,
          ),
        ],
      ),
    );
  }
}

class _InfoRow extends StatelessWidget {
  const _InfoRow({required this.label, required this.value});
  final String label;
  final String value;

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.symmetric(vertical: 4),
        child: Row(children: [Expanded(child: Text(label)), Text(value, style: const TextStyle(fontWeight: FontWeight.w700))]),
      );
}
