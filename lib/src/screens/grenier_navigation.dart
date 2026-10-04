import 'package:flutter/material.dart';

import '../conversation/conversation_models.dart';
import '../theme/grenier_tokens.dart';

enum GrenierDestination {
  home,
  library,
  conversations,
  collections,
  notes,
  highlights,
  concordance,
  timeline,
  compare,
  scripture,
  settings,
}

extension GrenierDestinationPresentation on GrenierDestination {
  String get label => switch (this) {
        GrenierDestination.home => 'Accueil',
        GrenierDestination.library => 'Bibliothèque',
        GrenierDestination.conversations => 'Conversations',
        GrenierDestination.collections => 'Collections',
        GrenierDestination.notes => 'Notes',
        GrenierDestination.highlights => 'Surlignages',
        GrenierDestination.concordance => 'Concordance',
        GrenierDestination.timeline => 'Chronologie',
        GrenierDestination.compare => 'Comparer',
        GrenierDestination.scripture => 'Références bibliques',
        GrenierDestination.settings => 'Réglages',
      };

  IconData get icon => switch (this) {
        GrenierDestination.home => Icons.home_outlined,
        GrenierDestination.library => Icons.library_books_outlined,
        GrenierDestination.conversations => Icons.chat_bubble_outline,
        GrenierDestination.collections => Icons.folder_copy_outlined,
        GrenierDestination.notes => Icons.note_alt_outlined,
        GrenierDestination.highlights => Icons.border_color_outlined,
        GrenierDestination.concordance => Icons.format_list_numbered_rounded,
        GrenierDestination.timeline => Icons.timeline_rounded,
        GrenierDestination.compare => Icons.compare_arrows_rounded,
        GrenierDestination.scripture => Icons.menu_book_outlined,
        GrenierDestination.settings => Icons.settings_outlined,
      };
}

class GrenierDesktopSidebar extends StatelessWidget {
  const GrenierDesktopSidebar({
    super.key,
    required this.selected,
    required this.onSelect,
    required this.onNewConversation,
    required this.recentConversations,
    required this.onOpenConversation,
    this.selectedConversationId,
    this.onTogglePin,
    this.onDeleteConversation,
  });

  final GrenierDestination selected;
  final ValueChanged<GrenierDestination> onSelect;
  final VoidCallback onNewConversation;
  final List<ConversationSummary> recentConversations;
  final ValueChanged<int> onOpenConversation;
  final int? selectedConversationId;
  final void Function(ConversationSummary value)? onTogglePin;
  final ValueChanged<int>? onDeleteConversation;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: GrenierPalette.navy,
      child: SizedBox(
        width: 270,
        child: SafeArea(
          top: false,
          child: Column(
            children: [
              const Padding(
                padding: EdgeInsets.fromLTRB(16, 16, 16, 12),
                child: Row(
                  children: [
                    Icon(Icons.menu_book_rounded, color: Colors.white, size: 26),
                    SizedBox(width: 10),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(GrenierBrand.name, maxLines: 1, overflow: TextOverflow.ellipsis, style: TextStyle(color: Colors.white, fontWeight: FontWeight.w800, fontSize: 15)),
                          Text(GrenierBrand.versionLabel, style: TextStyle(color: Colors.white60, fontSize: 11)),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 12),
                child: FilledButton.icon(
                  style: FilledButton.styleFrom(
                    minimumSize: const Size.fromHeight(46),
                    backgroundColor: Colors.white,
                    foregroundColor: GrenierPalette.navy,
                  ),
                  onPressed: onNewConversation,
                  icon: const Icon(Icons.add),
                  label: const Text('+ Nouvelle conversation'),
                ),
              ),
              const SizedBox(height: 10),
              Expanded(
                child: ListView(
                  padding: EdgeInsets.zero,
                  children: [
                    ...GrenierDestination.values.map(
                      (destination) => _DestinationTile(
                        destination: destination,
                        selected: selected == destination,
                        onTap: () => onSelect(destination),
                      ),
                    ),
                    const Padding(
                      padding: EdgeInsets.fromLTRB(14, 10, 14, 6),
                      child: Divider(color: Colors.white24),
                    ),
                    const Padding(
                      padding: EdgeInsets.fromLTRB(16, 4, 16, 6),
                      child: Align(
                        alignment: Alignment.centerLeft,
                        child: Text(
                          'Conversations récentes',
                          style: TextStyle(color: Colors.white70, fontWeight: FontWeight.w600, fontSize: 12),
                        ),
                      ),
                    ),
                    if (recentConversations.isEmpty)
                      const Padding(
                        padding: EdgeInsets.all(16),
                        child: Text('Aucune conversation', style: TextStyle(color: Colors.white54)),
                      )
                    else
                      ...recentConversations.map((summary) => ListTile(
                            dense: true,
                            selected: summary.id == selectedConversationId,
                            selectedTileColor: Colors.white.withValues(alpha: 0.09),
                            leading: Icon(
                              summary.pinned ? Icons.push_pin : Icons.chat_bubble_outline,
                              size: 17,
                              color: Colors.white60,
                            ),
                            title: Text(
                              summary.title,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(color: Colors.white, fontSize: 12.5),
                            ),
                            onTap: () => onOpenConversation(summary.id),
                            trailing: onTogglePin == null && onDeleteConversation == null
                                ? null
                                : PopupMenuButton<String>(
                                    iconColor: Colors.white54,
                                    tooltip: 'Actions de conversation',
                                    onSelected: (value) {
                                      if (value == 'pin') onTogglePin?.call(summary);
                                      if (value == 'delete') onDeleteConversation?.call(summary.id);
                                    },
                                    itemBuilder: (_) => [
                                      PopupMenuItem(
                                        value: 'pin',
                                        child: Text(summary.pinned ? 'Désépingler' : 'Épingler'),
                                      ),
                                      if (onDeleteConversation != null)
                                        const PopupMenuItem(value: 'delete', child: Text('Supprimer')),
                                    ],
                                  ),
                          )),
                  ],
                ),
              ),
              const Padding(
                padding: EdgeInsets.fromLTRB(16, 8, 16, 14),
                child: Row(
                  children: [
                    Icon(Icons.cloud_off_outlined, size: 15, color: Colors.white60),
                    SizedBox(width: 6),
                    Expanded(
                      child: Text(
                        GrenierBrand.offlineLabel,
                        style: TextStyle(color: Colors.white60, fontSize: 10.5),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _DestinationTile extends StatelessWidget {
  const _DestinationTile({required this.destination, required this.selected, required this.onTap});

  final GrenierDestination destination;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return ListTile(
      dense: true,
      minTileHeight: 40,
      leading: Icon(destination.icon, color: selected ? Colors.white : Colors.white70, size: 20),
      title: Text(
        destination.label,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        style: TextStyle(color: selected ? Colors.white : Colors.white70, fontWeight: selected ? FontWeight.w700 : FontWeight.w400, fontSize: 13),
      ),
      selected: selected,
      selectedTileColor: GrenierPalette.navyRaised,
      onTap: onTap,
    );
  }
}

class GrenierMobileNavigation extends StatelessWidget {
  const GrenierMobileNavigation({super.key, required this.selected, required this.onSelect});

  final GrenierDestination selected;
  final ValueChanged<GrenierDestination> onSelect;

  static const primary = <GrenierDestination>[
    GrenierDestination.home,
    GrenierDestination.library,
    GrenierDestination.conversations,
    GrenierDestination.settings,
  ];

  @override
  Widget build(BuildContext context) {
    var selectedIndex = primary.indexOf(selected);
    if (selectedIndex < 0) selectedIndex = 0;
    return NavigationBar(
      selectedIndex: selectedIndex,
      onDestinationSelected: (index) => onSelect(primary[index]),
      destinations: [
        for (final destination in primary)
          NavigationDestination(
            icon: Icon(destination.icon),
            selectedIcon: Icon(destination.icon),
            label: destination.label,
          ),
      ],
    );
  }
}

class GrenierDrawerNavigation extends StatelessWidget {
  const GrenierDrawerNavigation({
    super.key,
    required this.selected,
    required this.onSelect,
    required this.onNewConversation,
  });

  final GrenierDestination selected;
  final ValueChanged<GrenierDestination> onSelect;
  final VoidCallback onNewConversation;

  @override
  Widget build(BuildContext context) {
    return Drawer(
      child: SafeArea(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(12, 12, 12, 20),
          children: [
            const ListTile(
              leading: Icon(Icons.menu_book_rounded),
              title: Text(GrenierBrand.name, style: TextStyle(fontWeight: FontWeight.w800)),
              subtitle: Text(GrenierBrand.versionLabel),
            ),
            const SizedBox(height: 8),
            FilledButton.icon(onPressed: onNewConversation, icon: const Icon(Icons.add), label: const Text('Nouvelle conversation')),
            const SizedBox(height: 12),
            for (final destination in GrenierDestination.values)
              ListTile(
                leading: Icon(destination.icon),
                title: Text(destination.label),
                selected: selected == destination,
                onTap: () => onSelect(destination),
              ),
          ],
        ),
      ),
    );
  }
}
