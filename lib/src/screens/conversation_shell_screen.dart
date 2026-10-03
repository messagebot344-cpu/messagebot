import 'package:flutter/material.dart';

import 'collections_screen.dart';
import 'conversation_screen.dart';
import 'conversation_sidebar.dart';
import 'favorites_screen.dart';
import 'library_screen.dart';
import 'personal_search_screen.dart';
import 'settings_screen.dart';
import 'study_screen.dart';

class ConversationShellScreen extends StatefulWidget {
  const ConversationShellScreen({super.key});

  @override
  State<ConversationShellScreen> createState() => _ConversationShellScreenState();
}

class _ConversationShellScreenState extends State<ConversationShellScreen> {
  int _index = 0;

  static const _pages = <Widget>[
    ConversationScreen(),
    LibraryScreen(),
    StudyScreen(),
    CollectionsScreen(),
    FavoritesScreen(),
    PersonalSearchScreen(),
    SettingsScreen(),
  ];

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(builder: (context, constraints) {
      final wide = constraints.maxWidth >= 980;
      final content = IndexedStack(index: _index, children: _pages);
      if (wide) {
        return Scaffold(
          body: Row(children: [
            ConversationSidebar(selectedIndex: _index, onNavigate: (value) => setState(() => _index = value)),
            Expanded(child: content),
          ]),
        );
      }
      final bottomIndex = _index <= 2 ? _index : (_index == 4 ? 3 : 0);
      return Scaffold(
        appBar: AppBar(
          title: const Text('Message Bot'),
          actions: const [Padding(padding: EdgeInsets.only(right: 12), child: Center(child: Text('Hors ligne', style: TextStyle(fontSize: 12))))],
        ),
        drawer: Drawer(child: ConversationSidebar(inDrawer: true, selectedIndex: _index, onNavigate: (value) => setState(() => _index = value))),
        body: content,
        bottomNavigationBar: NavigationBar(
          selectedIndex: bottomIndex,
          onDestinationSelected: (value) => setState(() => _index = value == 3 ? 4 : value),
          destinations: const [
            NavigationDestination(icon: Icon(Icons.chat_bubble_outline), selectedIcon: Icon(Icons.chat_bubble), label: 'Recherche'),
            NavigationDestination(icon: Icon(Icons.library_books_outlined), selectedIcon: Icon(Icons.library_books), label: 'Bibliothèque'),
            NavigationDestination(icon: Icon(Icons.school_outlined), selectedIcon: Icon(Icons.school), label: 'Étudier'),
            NavigationDestination(icon: Icon(Icons.bookmark_border), selectedIcon: Icon(Icons.bookmark), label: 'Favoris'),
          ],
        ),
      );
    });
  }
}
