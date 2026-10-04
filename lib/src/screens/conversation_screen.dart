import 'package:flutter/material.dart';

import '../app_scope.dart';
import '../conversation/conversation_controller.dart';
import '../search_v4/search_explanation.dart';
import '../theme/grenier_tokens.dart';
import 'conversation_composer.dart';
import 'conversation_filter_sheet.dart';
import 'conversation_result_card.dart';
import 'conversation_result_message.dart';
import 'result_details_panel.dart';

class ConversationScreen extends StatefulWidget {
  const ConversationScreen({super.key});

  @override
  State<ConversationScreen> createState() => _ConversationScreenState();
}

class _ConversationScreenState extends State<ConversationScreen> {
  final ScrollController _scrollController = ScrollController();
  ConversationController? _controller;
  ResultSelection? _selection;

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

  Future<void> _showDetails(ResultSelection selection) async {
    final wide = MediaQuery.sizeOf(context).width >= GrenierBreakpoints.desktopWide;
    if (wide) {
      setState(() => _selection = selection);
      return;
    }
    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      builder: (sheetContext) => FractionallySizedBox(
        heightFactor: 0.92,
        child: ResultDetailsPanel(
          selection: selection,
          onClose: () => Navigator.of(sheetContext).pop(),
        ),
      ),
    );
  }

  Future<void> _showFilterSheet() async {
    final controller = AppScope.of(context).conversationController;
    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (_) => ConversationFilterSheet(
        initialValue: controller.activeFilters,
        onApply: controller.setActiveFilters,
      ),
    );
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
              const Icon(Icons.menu_book_rounded, size: 72, color: GrenierPalette.actionBlue),
              const SizedBox(height: 16),
              Text(
                GrenierBrand.name,
                style: Theme.of(context).textTheme.headlineMedium?.copyWith(fontWeight: FontWeight.w800),
              ),
              const SizedBox(height: 4),
              const Text(GrenierBrand.versionLabel),
              const SizedBox(height: 8),
              const Text(GrenierBrand.tagline, textAlign: TextAlign.center),
              const SizedBox(height: 12),
              const Wrap(alignment: WrapAlignment.center, spacing: 8, runSpacing: 8, children: [
                Chip(avatar: Icon(Icons.cloud_off_outlined, size: 18), label: Text(GrenierBrand.offlineLabel)),
                Chip(avatar: Icon(Icons.verified_outlined, size: 18), label: Text(GrenierBrand.noAiLabel)),
                Chip(avatar: Icon(Icons.menu_book_outlined, size: 18), label: Text(GrenierBrand.canonicalOnlyLabel)),
              ]),
              const SizedBox(height: 26),
              ConversationComposer(
                onSend: controller.send,
                busy: controller.searching,
                centered: true,
                filters: controller.activeFilters,
              ),
              const SizedBox(height: 10),
              TextButton.icon(
                onPressed: _showFilterSheet,
                icon: const Icon(Icons.tune),
                label: const Text('Ajouter un filtre'),
              ),
              const SizedBox(height: 6),
              Text(
                'Posez une question, recherchez une citation, un thème, un numéro de prédication ou appliquez des filtres.',
                textAlign: TextAlign.center,
                style: Theme.of(context).textTheme.bodySmall,
              ),
            ]),
          ),
        ),
      );
    }

    final workspace = Column(children: [
      Expanded(
        child: CustomScrollView(
          controller: _scrollController,
          slivers: _buildTurnSlivers(controller),
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
          child: Center(
            child: ConversationComposer(
              onSend: controller.send,
              busy: controller.searching,
              filters: controller.activeFilters,
            ),
          ),
        ),
      ),
    ]);

    return LayoutBuilder(
      builder: (context, constraints) {
        final showDetails = constraints.maxWidth >= GrenierBreakpoints.desktopWide && _selection != null;
        return Row(
          children: [
            Expanded(child: workspace),
            if (showDetails)
              Container(
                width: 330,
                decoration: BoxDecoration(
                  border: Border(left: BorderSide(color: Theme.of(context).colorScheme.outlineVariant)),
                ),
                child: ResultDetailsPanel(
                  selection: _selection!,
                  onClose: () => setState(() => _selection = null),
                ),
              ),
          ],
        );
      },
    );
  }

  List<Widget> _buildTurnSlivers(ConversationController controller) {
    final slivers = <Widget>[];
    final turns = controller.turns;

    for (var turnIndex = 0; turnIndex < turns.length; turnIndex++) {
      final turn = turns[turnIndex];
      final latest = turnIndex == turns.length - 1;

      slivers.add(SliverPadding(
        padding: const EdgeInsets.fromLTRB(16, 18, 16, 10),
        sliver: SliverToBoxAdapter(
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
                  child: SelectableText(
                    turn.record.query,
                    style: TextStyle(color: Theme.of(context).colorScheme.onPrimary),
                  ),
                ),
              ),
            ),
          ),
        ),
      ));

      slivers.add(SliverPadding(
        padding: const EdgeInsets.fromLTRB(16, 0, 16, 10),
        sliver: SliverToBoxAdapter(
          child: ConversationResultMessageHeader(
            count: turn.hits.length,
            filters: turn.record.filters,
            fuzzySuggestions: turn.fuzzySuggestions,
            onAddFilter: latest ? _showFilterSheet : null,
            onRemoveSubject: latest ? controller.clearSubjectFilter : null,
            onRemovePeriod: latest ? controller.clearPeriodFilter : null,
            onRemoveSource: latest ? controller.clearSourceFilter : null,
          ),
        ),
      ));

      if (turn.hits.isEmpty) {
        slivers.add(const SliverPadding(
          padding: EdgeInsets.fromLTRB(16, 0, 16, 16),
          sliver: SliverToBoxAdapter(
            child: Card(
              child: Padding(
                padding: EdgeInsets.all(18),
                child: Text('Aucun passage suffisamment pertinent n’a été trouvé. Essayez une formulation plus précise.'),
              ),
            ),
          ),
        ));
        continue;
      }

      final topScore = turn.hits.first.score;
      slivers.add(SliverPadding(
        padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
        sliver: SliverList(
          delegate: SliverChildBuilderDelegate(
            (context, index) {
              final hit = turn.hits[index];
              final passageId = hit.studyPassage.passage.id;
              final persisted = turn.record.hits.where((e) => e.passageId == passageId).firstOrNull;
              return Padding(
                padding: const EdgeInsets.only(bottom: 10),
                child: ConversationResultCard(
                  turnId: turn.record.id,
                  query: turn.record.query,
                  filters: turn.record.filters,
                  rank: index + 1,
                  hit: hit,
                  explanation: turn.explanations[passageId] ?? const SearchExplanationV4(),
                  expanded: persisted?.expanded ?? false,
                  topScore: topScore,
                  onSelected: _showDetails,
                ),
              );
            },
            childCount: turn.hits.length,
          ),
        ),
      ));
    }

    slivers.add(const SliverToBoxAdapter(child: SizedBox(height: 14)));
    return slivers;
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
