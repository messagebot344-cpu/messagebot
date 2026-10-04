import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:le_grenier_du_message/src/conversation/conversation_models.dart';
import 'package:le_grenier_du_message/src/screens/grenier_navigation.dart';
import 'package:le_grenier_du_message/src/screens/grenier_top_banner.dart';
import 'package:le_grenier_du_message/src/theme/grenier_theme.dart';

Widget _app(Widget child) => MaterialApp(
      theme: MessageBotTheme.light(),
      home: Scaffold(body: child),
    );

void main() {
  testWidgets('desktop navigation exposes the approved destinations', (tester) async {
    final values = <GrenierDestination>[];
    await tester.pumpWidget(_app(Row(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        GrenierDesktopSidebar(
          selected: GrenierDestination.conversations,
          onSelect: values.add,
          onNewConversation: () {},
          recentConversations: const [
            ConversationSummary(
              id: 1,
              title: 'Mariage après 1960',
              createdAt: 1,
              updatedAt: 1,
              pinned: false,
            ),
          ],
          onOpenConversation: (_) {},
        ),
        const Expanded(child: GrenierTopBanner()),
      ],
    )));

    expect(find.text('Le Grenier du Message'), findsWidgets);
    expect(find.text('V4 – IR Expert'), findsOneWidget);
    expect(find.text('+ Nouvelle conversation'), findsOneWidget);
    for (final label in const [
      'Accueil',
      'Bibliothèque',
      'Conversations',
      'Collections',
      'Notes',
      'Concordance',
      'Chronologie',
      'Comparer',
      'Références bibliques',
      'Réglages',
    ]) {
      expect(find.text(label), findsOneWidget);
    }
    expect(find.text('Mariage après 1960'), findsOneWidget);
    expect(find.text('100% hors ligne'), findsOneWidget);
  });

  testWidgets('mobile navigation has four primary destinations', (tester) async {
    await tester.binding.setSurfaceSize(const Size(390, 844));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    await tester.pumpWidget(_app(GrenierMobileNavigation(
      selected: GrenierDestination.home,
      onSelect: (_) {},
    )));

    for (final label in const [
      'Accueil',
      'Bibliothèque',
      'Conversations',
      'Réglages',
    ]) {
      expect(find.text(label), findsOneWidget);
    }
    expect(find.text('Collections'), findsNothing);
  });

  testWidgets('advanced drawer exposes secondary destinations without overflow', (tester) async {
    await tester.binding.setSurfaceSize(const Size(360, 800));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    await tester.pumpWidget(_app(
      GrenierNavigationDrawer(
        selected: GrenierDestination.home,
        onSelect: (_) {},
        onNewConversation: () {},
        recentConversations: const [
          ConversationSummary(
            id: 7,
            title:
                'Une conversation extrêmement longue qui doit rester lisible sans dépasser',
            createdAt: 1,
            updatedAt: 2,
            pinned: false,
          ),
        ],
        onOpenConversation: (_) {},
      ),
    ));

    for (final label in const [
      'Collections',
      'Notes',
      'Concordance',
      'Chronologie',
      'Comparer',
      'Références bibliques',
    ]) {
      expect(find.text(label), findsOneWidget);
    }
    expect(tester.takeException(), isNull);
  });
}
