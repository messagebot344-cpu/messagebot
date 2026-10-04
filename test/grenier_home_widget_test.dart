import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:le_grenier_du_message/src/screens/grenier_home_screen.dart';
import 'package:le_grenier_du_message/src/theme/grenier_theme.dart';

Widget _app(VoidCallback onStart) => MaterialApp(
      theme: MessageBotTheme.light(),
      home: Scaffold(body: GrenierHomeScreen(onStartConversation: onStart)),
    );

void main() {
  testWidgets('mobile home matches the Grenier brand hierarchy', (tester) async {
    await tester.binding.setSurfaceSize(const Size(390, 844));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    var starts = 0;
    await tester.pumpWidget(_app(() => starts++));

    expect(find.text('Le Grenier du Message'), findsOneWidget);
    expect(find.text('V4 – IR Expert'), findsOneWidget);
    expect(
      find.text('Toute Sa Parole.\nToujours avec vous.\nHors ligne.'),
      findsOneWidget,
    );
    expect(find.text('Commencer une recherche'), findsOneWidget);
    expect(find.text('100% hors ligne'), findsOneWidget);
    expect(find.text('Aucune IA générative'), findsOneWidget);
    expect(tester.takeException(), isNull);

    await tester.tap(find.text('Commencer une recherche'));
    expect(starts, 1);
  });

  testWidgets('desktop home keeps the approved trust labels', (tester) async {
    await tester.binding.setSurfaceSize(const Size(1280, 800));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    await tester.pumpWidget(_app(() {}));

    expect(find.text('Le Grenier du Message'), findsOneWidget);
    expect(find.text('Texte canonique uniquement'), findsOneWidget);
    expect(find.byIcon(Icons.auto_stories_rounded), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}
