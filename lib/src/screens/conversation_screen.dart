import 'package:flutter/material.dart';

import '../app_scope.dart';
import '../conversation/conversation_controller.dart';
import '../search_v4/search_explanation.dart';
import 'conversation_composer.dart';
import 'conversation_result_card.dart';
import 'conversation_result_message.dart';

class ConversationScreen extends StatefulWidget {
  const ConversationScreen({super.key});

  @override
  State<ConversationScreen> createState() => _ConversationScreenState();
}

class _ConversationScreenState extends State<ConversationScreen> {
  final ScrollController _scrollController = ScrollController();
  ConversationController? _controller;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final next = AppScope.of(context).conversationController;
    if (!identical(next, _controller)) {
      _controller?.removeListener(_changed);
      _controller = next..addListener(_changed);
    }
  }

  @override
  void dispose() {
    _controller?.removeListener(_changed);
    _scrollController.dispose();
    super.dispose();
  }

  void _changed() {
    if (!mounted) return;
    setState(() {});
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted || !_scrollController.hasClients) return;
      if (_controller?.searching == false && _scrollController.position.maxScrollExtent > 0) {
        _scrollController.animateTo(
          _scrollController.position.maxScrollExtent,
          duration: const Duration(milliseconds: 260),
          curve: Curves.easeOut,
        );
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final controller = AppScope.of(context).conversationController;
    if (controller.turns.isEmpty) {
      return Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 860),
            child: Column(mainAxisSize: MainAxisSize.min, children: [
              Icon(Icons.menu_book_rounded, size: 78, color: Theme.of(context).colorScheme.primary),
              const SizedBox(height: 16),
              Text('Message Bot', style: Theme.of(context).textTheme.headlineMedium?.copyWith(fontWeight: FontWeight.w800)),
              const SizedBox(height: 8),
              const Text('Toute Sa Parole. Toujours avec vous. Hors ligne.', textAlign: TextAlign.center),
              const SizedBox(height: 12),
              const Wrap(alignment: WrapAlignment.center, spacing: 8, runSpacing: 8, children: [
                Chip(avatar: Icon(Icons.cloud_off_outlined, size: 18), label: Text('100 % hors ligne')),
                Chip(avatar: Icon(Icons.verified_outlined, size: 18), label: Text('Aucune IA générative')),
              ]),
              const SizedBox(height: 26),
              ConversationComposer(onSend: controller.send, busy: controller.searching, centered: true),
              const SizedBox(height: 12),
              Text(
                'Posez une question, recherchez une citation, un thème, un numéro de prédication ou appliquez un filtre comme « après 1960 ».',
                textAlign: TextAlign.center,
                style: Theme.of(context).textTheme.bodySmall,
              ),
            ]),
          ),
        ),
      );
    }

    final rows = _rows(controller.turns);
    return Column(children: [
      Expanded(
        child: ListView.builder(
          controller: _scrollController,
          padding: const EdgeInsets.fromLTRB(16, 18, 16, 24),
          itemCount: rows.length,
          itemBuilder: (context, index) => rows[index],
        ),
      ),
      SafeArea(
        top: false,
        child: Container(
          width: double.infinity,
          padding: const EdgeInsets.fromLTRB(16, 10, 16, 12),
          decoration: BoxDecoration(
            color: Theme.of(context).colorScheme.surface,
            border: Border(top: BorderSide(color: Theme.of(context).colorScheme.outlineVariant)),
          ),
          child: Center(child: ConversationComposer(onSend: controller.send, busy: controller.searching)),
        ),
      ),
    ]);
  }

  List<Widget> _rows(List<ConversationTurnView> turns) {
    final widgets = <Widget>[];
    for (final turn in turns) {
      widgets.add(Padding(
        padding: const EdgeInsets.only(bottom: 10),
        child: Align(
          alignment: Alignment.centerRight,
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 680),
            child: DecoratedBox(
              decoration: BoxDecoration(
                color: Theme.of(context).colorScheme.primary,
                borderRadius: BorderRadius.circular(18),
              ),
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                child: SelectableText(turn.record.query, style: TextStyle(color: Theme.of(context).colorScheme.onPrimary)),
              ),
            ),
          ),
        ),
      ));
      widgets.add(Padding(
        padding: const EdgeInsets.only(bottom: 10),
        child: ConversationResultMessageHeader(
          count: turn.hits.length,
          filters: turn.record.filters,
          fuzzySuggestions: turn.fuzzySuggestions,
        ),
      ));
      final topScore = turn.hits.isEmpty ? 0.0 : turn.hits.first.score;
      for (var i = 0; i < turn.hits.length; i++) {
        final hit = turn.hits[i];
        final passageId = hit.studyPassage.passage.id;
        final persisted = turn.record.hits.where((e) => e.passageId == passageId).firstOrNull;
        widgets.add(Padding(
          padding: const EdgeInsets.only(bottom: 10),
          child: ConversationResultCard(
            turnId: turn.record.id,
            query: turn.record.query,
            rank: i + 1,
            hit: hit,
            explanation: turn.explanations[passageId] ?? const SearchExplanationV4(),
            expanded: persisted?.expanded ?? false,
            topScore: topScore,
          ),
        ));
      }
      if (turn.hits.isEmpty) {
        widgets.add(const Padding(
          padding: EdgeInsets.only(bottom: 16),
          child: Card(child: Padding(padding: EdgeInsets.all(18), child: Text('Aucun passage suffisamment pertinent n’a été trouvé. Essayez une formulation plus précise.'))),
        ));
      }
    }
    return widgets;
  }
}

extension _FirstOrNull<E> on Iterable<E> {
  E? get firstOrNull {
    for (final value in this) {
      return value;
    }
    return null;
  }
}
