import 'package:flutter/material.dart';

import '../conversation/conversation_models.dart';
import '../theme/grenier_tokens.dart';

enum GrenierDestination {
  home,
  library,
  conversations,
  collections,
  notes,
  concordance,
  timeline,
  compare,
  scripture,
  settings,
}

extension GrenierDestinationUi on GrenierDestination {
  String get label => switch (this) {
        GrenierDestination.home => 'Accueil',
        GrenierDestination.library => 'Bibliothèque',
        GrenierDestination.conversations => 'Conversations',
        GrenierDestination.collections => 'Collections',
        GrenierDestination.notes => 'Notes',
        GrenierDestination.concordance => 'Concordance',
        GrenierDestination.timeline => 'Chronologie',
        GrenierDestination.compare => 'Comparer',
        GrenierDestination.scripture => 'Références bibliques',
        GrenierDestination.settings => 'Réglages',
      };

  IconData get icon => switch (this) {
        GrenierDestination.home => Icons.home_outlined,
        GrenierDestination.library => Icons.menu_book_outlined,
        GrenierDestination.conversations => Icons.chat_bubble_outline,
        GrenierDestination.collections => Icons.folder_outlined,
        GrenierDestination.notes => Icons.note_alt_outlined,
        GrenierDestination.concordance => Icons.manage_search_outlined,
        GrenierDestination.timeline => Icons.timeline_outlined,
        GrenierDestination.compare => Icons.compare_outlined,
        GrenierDestination.scripture => Icons.auto_stories_outlined,
        GrenierDestination.settings => Icons.settings_outlined,
      };
}

const _primaryMobileDestinations = <GrenierDestination>[
  GrenierDestination.home,
  GrenierDestination.library,
  GrenierDestination.conversations,
  GrenierDestination.settings,
];

class GrenierDesktopSidebar extends StatelessWidget {
  const GrenierDesktopSidebar({
    super.key,
    required this.selected,
    required this.onSelect,
    required this.onNewConversation,
    required this.recentConversations,
    required this.onOpenConversation,
    this.onConversationSearch,
  });

  final GrenierDestination selected;
  final ValueChanged<GrenierDestination> onSelect;
  final VoidCallback onNewConversation;
  final List<ConversationSummary> recentConversations;
  final ValueChanged<int> onOpenConversation;
  final ValueChanged<String>? onConversationSearch;

  @override
  Widget build(BuildContext context) {
    return _NavigationSurface(
      selected: selected,
      onSelect: onSelect,
      onNewConversation: onNewConversation,
      recentConversations: recentConversations,
      onOpenConversation: onOpenConversation,
      onConversationSearch: onConversationSearch,
      width: 270,
    );
  }
}

class GrenierNavigationDrawer extends StatelessWidget {
  const GrenierNavigationDrawer({
    super.key,
    required this.selected,
    required this.onSelect,
    required this.onNewConversation,
    required this.recentConversations,
    required this.onOpenConversation,
    this.onConversationSearch,
  });

  final GrenierDestination selected;
  final ValueChanged<GrenierDestination> onSelect;
  final VoidCallback onNewConversation;
  final List<ConversationSummary> recentConversations;
  final ValueChanged<int> onOpenConversation;
  final ValueChanged<String>? onConversationSearch;

  @override
  Widget build(BuildContext context) {
    return _NavigationSurface(
      selected: selected,
      onSelect: (value) {
        onSelect(value);
        if (Navigator.of(context).canPop()) Navigator.of(context).pop();
      },
      onNewConversation: () {
        onNewConversation();
        if (Navigator.of(context).canPop()) Navigator.of(context).pop();
      },
      recentConversations: recentConversations,
      onOpenConversation: (id) {
        onOpenConversation(id);
        if (Navigator.of(context).canPop()) Navigator.of(context).pop();
      },
      onConversationSearch: onConversationSearch,
      width: 300,
    );
  }
}

class GrenierMobileNavigation extends StatelessWidget {
  const GrenierMobileNavigation({
    super.key,
    required this.selected,
    required this.onSelect,
  });

  final GrenierDestination selected;
  final ValueChanged<GrenierDestination> onSelect;

  @override
  Widget build(BuildContext context) {
    final index = _primaryMobileDestinations.contains(selected)
        ? _primaryMobileDestinations.indexOf(selected)
        : 0;
    return NavigationBar(
      selectedIndex: index,
      onDestinationSelected: (value) => onSelect(_primaryMobileDestinations[value]),
      destinations: [
        for (final destination in _primaryMobileDestinations)
          NavigationDestination(
            icon: Icon(destination.icon),
            selectedIcon: Icon(_selectedIcon(destination)),
            label: destination.label,
          ),
      ],
    );
  }

  IconData _selectedIcon(GrenierDestination destination) => switch (destination) {
        GrenierDestination.home => Icons.home,
        GrenierDestination.library => Icons.menu_book,
        GrenierDestination.conversations => Icons.chat_bubble,
        GrenierDestination.settings => Icons.settings,
        _ => destination.icon,
      };
}

class _NavigationSurface extends StatelessWidget {
  const _NavigationSurface({
    required this.selected,
    required this.onSelect,
    required this.onNewConversation,
    required this.recentConversations,
    required this.onOpenConversation,
    required this.width,
    this.onConversationSearch,
  });

  final GrenierDestination selected;
  final ValueChanged<GrenierDestination> onSelect;
  final VoidCallback onNewConversation;
  final List<ConversationSummary> recentConversations;
  final ValueChanged<int> onOpenConversation;
  final ValueChanged<String>? onConversationSearch;
  final double width;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: GrenierPalette.navy,
      child: SafeArea(
        child: SizedBox(
          width: width,
          child: Column(
            children: [
              const Padding(
                padding: EdgeInsets.fromLTRB(16, 16, 16, 10),
                child: Row(
                  children: [
                    Icon(Icons.auto_stories_rounded, color: Color(0xFFD7A94B), size: 30),
                    SizedBox(width: 10),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            GrenierBrand.name,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(color: Colors.white, fontWeight: FontWeight.w800),
                          ),
                          Text(GrenierBrand.versionLabel, style: TextStyle(color: Colors.white60, fontSize: 12)),
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
                    backgroundColor: GrenierPalette.actionBlue,
                    foregroundColor: Colors.white,
                  ),
                  onPressed: onNewConversation,
                  icon: const Icon(Icons.add),
                  label: const Text('+ Nouvelle conversation'),
                ),
              ),
              const SizedBox(height: 8),
              for (final destination in GrenierDestination.values)
                if (destination != GrenierDestination.settings)
                  _DestinationTile(
                    destination: destination,
                    selected: selected == destination,
                    onTap: () => onSelect(destination),
                  ),
              const Divider(color: Colors.white24, height: 16),
              if (onConversationSearch != null)
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 12),
                  child: TextField(
                    onChanged: onConversationSearch,
                    style: const TextStyle(color: Colors.white),
                    decoration: const InputDecoration(
                      hintText: 'Rechercher une conversation',
                      hintStyle: TextStyle(color: Colors.white54),
                      prefixIcon: Icon(Icons.search, color: Colors.white70),
                      isDense: true,
                    ),
                  ),
                ),
              const Padding(
                padding: EdgeInsets.fromLTRB(16, 10, 16, 5),
                child: Align(
                  alignment: Alignment.centerLeft,
                  child: Text(
                    'CONVERSATIONS RÉCENTES',
                    style: TextStyle(color: Colors.white54, fontSize: 10, fontWeight: FontWeight.w700),
                  ),
                ),
              ),
              Expanded(
                child: recentConversations.isEmpty
                    ? const Center(
                        child: Padding(
                          padding: EdgeInsets.all(16),
                          child: Text('Aucune conversation', style: TextStyle(color: Colors.white54)),
                        ),
                      )
                    : ListView.builder(
                        itemCount: recentConversations.length,
                        itemBuilder: (context, index) {
                          final item = recentConversations[index];
                          return ListTile(
                            dense: true,
                            leading: Icon(
                              item.pinned ? Icons.push_pin_outlined : Icons.chat_outlined,
                              size: 17,
                              color: Colors.white54,
                            ),
                            title: Text(
                              item.title,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(color: Colors.white, fontSize: 12.5),
                            ),
                            onTap: () => onOpenConversation(item.id),
                          );
                        },
                      ),
              ),
              _DestinationTile(
                destination: GrenierDestination.settings,
                selected: selected == GrenierDestination.settings,
                onTap: () => onSelect(GrenierDestination.settings),
              ),
              const Padding(
                padding: EdgeInsets.fromLTRB(16, 6, 16, 12),
                child: Row(
                  children: [
                    Icon(Icons.lock_outline, size: 15, color: Colors.white54),
                    SizedBox(width: 6),
                    Expanded(
                      child: Text(
                        '${GrenierBrand.offlineLabel} • ${GrenierBrand.noAiLabel}',
                        maxLines: 2,
                        style: TextStyle(color: Colors.white54, fontSize: 10.5),
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
  const _DestinationTile({
    required this.destination,
    required this.selected,
    required this.onTap,
  });

  final GrenierDestination destination;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return ListTile(
      dense: true,
      minTileHeight: 40,
      selected: selected,
      selectedTileColor: Colors.white.withValues(alpha: 0.12),
      leading: Icon(destination.icon, color: selected ? Colors.white : Colors.white70, size: 20),
      title: Text(
        destination.label,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        style: TextStyle(
          color: selected ? Colors.white : Colors.white70,
          fontSize: 13,
          fontWeight: selected ? FontWeight.w700 : FontWeight.w400,
        ),
      ),
      onTap: onTap,
    );
  }
}
