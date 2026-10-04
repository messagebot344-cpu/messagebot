import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:le_grenier_du_message/src/conversation/conversation_models.dart';
import 'package:le_grenier_du_message/src/screens/conversation_filter_sheet.dart';
import 'package:le_grenier_du_message/src/screens/conversation_result_message.dart';
import 'package:le_grenier_du_message/src/screens/conversation_screen.dart';
import 'package:le_grenier_du_message/src/theme/grenier_theme.dart';

Widget _app(Widget child) => MaterialApp(
      theme: MessageBotTheme.light(),
      home: Scaffold(body: child),
    );

void main() {
  testWidgets('documentary response exposes real filter controls', (tester) async {
    var addCalls = 0;
    var subjectClears = 0;
    await tester.pumpWidget(_app(ConversationResultMessageHeader(
      count: 37,
      filters: const ConversationFilterSet(
        subjectTerms: ['mariage'],
        yearMin: 1960,
        yearMax: 1965,
        sourceType: 'sermon',
      ),
      onAddFilter: () => addCalls++,
      onClearSubject: () => subjectClears++,
    )));

    expect(find.text('Le Grenier du Message'), findsOneWidget);
    expect(find.text('37 passages pertinents trouvés'), findsOneWidget);
    expect(find.text('Ajouter un filtre'), findsOneWidget);
    expect(find.textContaining('Sujet'), findsOneWidget);
    expect(find.textContaining('Période'), findsOneWidget);
    expect(find.textContaining('Source'), findsOneWidget);

    await tester.tap(find.text('Ajouter un filtre'));
    expect(addCalls, 1);
    await tester.tap(find.byTooltip('Retirer le filtre Sujet'));
    expect(subjectClears, 1);
  });

  testWidgets('filter sheet applies subject period and source', (tester) async {
    ConversationFilterSet? applied;
    await tester.pumpWidget(_app(
      ConversationFilterSheet(
        initialValue: const ConversationFilterSet(),
        onApply: (value) => applied = value,
      ),
    ));

    await tester.enterText(find.byKey(const Key('filter-subject')), 'mariage');
    await tester.enterText(find.byKey(const Key('filter-year-min')), '1960');
    await tester.enterText(find.byKey(const Key('filter-year-max')), '1965');
    await tester.tap(find.byKey(const Key('filter-source-sermon')));
    await tester.tap(find.text('Appliquer'));

    expect(applied?.subjectTerms, ['mariage']);
    expect(applied?.yearMin, 1960);
    expect(applied?.yearMax, 1965);
    expect(applied?.sourceType, 'sermon');
  });

  testWidgets('conversation results use a lazy list on a long turn', (tester) async {
    await tester.binding.setSurfaceSize(const Size(390, 700));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    await tester.pumpWidget(_app(CustomScrollView(
      slivers: [
        LazyDocumentaryResults(
          itemCount: 120,
          itemBuilder: (context, index) => SizedBox(
            height: 72,
            child: Text('Résultat ${index + 1}', key: Key('result-rank-${index + 1}')),
          ),
        ),
      ],
    )));

    expect(find.byKey(const Key('result-rank-120')), findsNothing);
    await tester.scrollUntilVisible(
      find.byKey(const Key('result-rank-120')),
      600,
      scrollable: find.byType(Scrollable).first,
    );
    expect(find.byKey(const Key('result-rank-120')), findsOneWidget);
  });
}
