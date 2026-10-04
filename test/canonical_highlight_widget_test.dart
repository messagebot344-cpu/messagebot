import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:le_grenier_du_message/src/screens/canonical_highlight_text.dart';
import 'package:le_grenier_du_message/src/theme/grenier_theme.dart';

void main() {
  testWidgets('canonical highlight preserves exact displayed text', (tester) async {
    const source = 'Le mari aime l’amour de l’Église, exactement.';
    await tester.pumpWidget(MaterialApp(
      theme: MessageBotTheme.light(),
      home: const Scaffold(
        body: CanonicalHighlightText(
          text: source,
          terms: ['mari', 'amour', 'eglise'],
        ),
      ),
    ));

    final widget = tester.widget<SelectableText>(find.byType(SelectableText));
    expect(widget.textSpan?.toPlainText(), source);
  });

  testWidgets('dark highlight remains distinct from foreground', (tester) async {
    await tester.pumpWidget(MaterialApp(
      theme: MessageBotTheme.dark(),
      darkTheme: MessageBotTheme.dark(),
      themeMode: ThemeMode.dark,
      home: const Scaffold(
        body: CanonicalHighlightText(
          text: 'La foi demeure.',
          terms: ['foi'],
        ),
      ),
    ));

    final widget = tester.widget<SelectableText>(find.byType(SelectableText));
    final root = widget.textSpan!;
    final highlighted = root.children!
        .whereType<TextSpan>()
        .firstWhere((span) => span.style?.backgroundColor != null);
    expect(highlighted.text, 'foi');
    expect(highlighted.style!.backgroundColor, isNot(highlighted.style!.color));
  });
}
