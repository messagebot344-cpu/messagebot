import 'package:flutter/material.dart';

import '../app_scope.dart';
import '../conversation/conversation_models.dart';
import '../theme/grenier_theme.dart';

class ConversationSidebar extends StatelessWidget {
  const ConversationSidebar({super.key, required this.selectedIndex, required this.onNavigate, this.inDrawer = false});

  final int selectedIndex;
  final ValueChanged<int> onNavigate;
  final bool inDrawer;

  @override
  Widget build(BuildContext context) {
    final controller = AppScope.of(context).conversationController;
    return Material(
      color: MessageBotTheme.navy,
      child: SafeArea(
        child: SizedBox(
          width: 292,
          child: Column(children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(14, 12, 14, 8),
              child: Row(children: [
                const Icon(Icons.menu_book_rounded, color: Colors.white),
                const SizedBox(width: 9),
                const Expanded(child: Text('Message Bot', style: TextStyle(color: Colors.white, fontWeight: FontWeight.w800, fontSize: 18))),
                if (inDrawer) IconButton(onPressed: () => Navigator.pop(context), icon: const Icon(Icons.close, color: Colors.white)),
              ]),
            ),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 12),
              child: FilledButton.icon(
                style: FilledButton.styleFrom(minimumSize: const Size.fromHeight(44), backgroundColor: Colors.white, foregroundColor: MessageBotTheme.navy),
                onPressed: () {
                  controller.startNewConversation();
                  onNavigate(0);
                  if (inDrawer) Navigator.pop(context);
                },
                icon: const Icon(Icons.add),
                label: const Text('Nouvelle conversation'),
              ),
            ),
            const SizedBox(height: 8),
            _NavTile(icon: Icons.chat_bubble_outline, label: 'Accueil / Recherche', selected: selectedIndex == 0, onTap: () => _go(context, 0)),
            _NavTile(icon: Icons.library_books_outlined, label: 'Bibliothèque', selected: selectedIndex == 1, onTap: () => _go(context, 1)),
            _NavTile(icon: Icons.school_outlined, label: 'Étudier', selected: selectedIndex == 2, onTap: () => _go(context, 2)),
            _NavTile(icon: Icons.folder_copy_outlined, label: 'Collections', selected: selectedIndex == 3, onTap: () => _go(context, 3)),
            _NavTile(icon: Icons.bookmark_border, label: 'Favoris', selected: selectedIndex == 4, onTap: () => _go(context, 4)),
            _NavTile(icon: Icons.note_alt_outlined, label: 'Notes', selected: selectedIndex == 5, onTap: () => _go(context, 5)),
            const Padding(padding: EdgeInsets.symmetric(horizontal: 14, vertical: 8), child: Divider(color: Colors.white24)),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 14),
              child: TextField(
                onChanged: controller.setConversationSearch,
                style: const TextStyle(color: Colors.white),
                decoration: const InputDecoration(
                  hintText: 'Rechercher une conversation',
                  hintStyle: TextStyle(color: Colors.white60),
                  prefixIcon: Icon(Icons.search, color: Colors.white70),
                  isDense: true,
                ),
              ),
            ),
            const Padding(
              padding: EdgeInsets.fromLTRB(16, 12, 16, 6),
              child: Align(alignment: Alignment.centerLeft, child: Text('Conversations', style: TextStyle(color: Colors.white70, fontWeight: FontWeight.w600))),
            ),
            Expanded(
              child: AnimatedBuilder(
                animation: controller,
                builder: (context, _) {
                  final values = controller.conversations;
                  if (values.isEmpty) return const Center(child: Padding(padding: EdgeInsets.all(16), child: Text('Aucune conversation', style: TextStyle(color: Colors.white54))));
                  return ListView.builder(
                    itemCount: values.length,
                    itemBuilder: (context, index) => _ConversationTile(
                      summary: values[index],
                      selected: values[index].id == controller.conversationId,
                      onOpen: () {
                        controller.loadConversation(values[index].id);
                        onNavigate(0);
                        if (inDrawer) Navigator.pop(context);
                      },
                    ),
                  );
                },
              ),
            ),
            _NavTile(icon: Icons.settings_outlined, label: 'Réglages', selected: selectedIndex == 6, onTap: () => _go(context, 6)),
            const Padding(
              padding: EdgeInsets.fromLTRB(16, 6, 16, 14),
              child: Row(children: [
                Icon(Icons.cloud_off_outlined, size: 16, color: Colors.white60),
                SizedBox(width: 6),
                Expanded(child: Text('100 % hors ligne • Aucune IA générative', style: TextStyle(color: Colors.white60, fontSize: 11))),
              ]),
            ),
          ]),
        ),
      ),
    );
  }

  void _go(BuildContext context, int value) {
    onNavigate(value);
    if (inDrawer) Navigator.pop(context);
  }
}

class _NavTile extends StatelessWidget {
  const _NavTile({required this.icon, required this.label, required this.selected, required this.onTap});
  final IconData icon;
  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => ListTile(
        dense: true,
        leading: Icon(icon, color: selected ? Colors.white : Colors.white70),
        title: Text(label, style: TextStyle(color: selected ? Colors.white : Colors.white70, fontWeight: selected ? FontWeight.w700 : FontWeight.w400)),
        selected: selected,
        selectedTileColor: Colors.white.withValues(alpha: 0.10),
        onTap: onTap,
      );
}

class _ConversationTile extends StatelessWidget {
  const _ConversationTile({required this.summary, required this.selected, required this.onOpen});
  final ConversationSummary summary;
  final bool selected;
  final VoidCallback onOpen;

  @override
  Widget build(BuildContext context) {
    final controller = AppScope.of(context).conversationController;
    return ListTile(
      dense: true,
      selected: selected,
      selectedTileColor: Colors.white.withValues(alpha: 0.10),
      leading: Icon(summary.pinned ? Icons.push_pin : Icons.chat_bubble_outline, size: 18, color: Colors.white60),
      title: Text(summary.title, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(color: Colors.white, fontSize: 13)),
      onTap: onOpen,
      trailing: PopupMenuButton<String>(
        iconColor: Colors.white60,
        onSelected: (value) {
          if (value == 'pin') controller.togglePin(summary.id, !summary.pinned);
          if (value == 'delete') controller.deleteConversation(summary.id);
        },
        itemBuilder: (_) => [
          PopupMenuItem(value: 'pin', child: Text(summary.pinned ? 'Désépingler' : 'Épingler')),
          const PopupMenuItem(value: 'delete', child: Text('Supprimer')),
        ],
      ),
    );
  }
}
