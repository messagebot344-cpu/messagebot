import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:scrollable_positioned_list/scrollable_positioned_list.dart';

import '../app_scope.dart';
import '../models/models.dart';
import 'collection_picker.dart';
import 'comparison_screen.dart';
import 'passage_target.dart';
import 'similar_passages_screen.dart';

class ReaderScreen extends StatefulWidget {
  const ReaderScreen({
    super.key,
    required this.sermon,
    required this.initialEditionId,
    this.initialPassageId,
    this.initialOrdinal,
    this.highlightStartOffset,
    this.highlightEndOffset,
  });

  final SermonSummary sermon;
  final String initialEditionId;
  final int? initialPassageId;
  final int? initialOrdinal;
  final int? highlightStartOffset;
  final int? highlightEndOffset;

  @override
  State<ReaderScreen> createState() => _ReaderScreenState();
}

class _ReaderScreenState extends State<ReaderScreen> {
  late List<EditionSummary> _editions;
  late EditionSummary _edition;
  late List<Passage> _passages;
  late int _initialOrdinal;
  int _generation = 0;
  int _lastSavedOrdinal = -1;
  bool _favorite = false;

  ItemPositionsListener _positionsListener = ItemPositionsListener.create();
  ItemScrollController _scrollController = ItemScrollController();

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_generation != 0) return;
    final scope = AppScope.of(context);
    _editions = scope.repository.editionsForSermon(widget.sermon.id);
    _edition = _editions.firstWhere(
      (e) => e.id == widget.initialEditionId,
      orElse: () => _editions.first,
    );
    _passages = scope.repository.passagesForEdition(_edition.id);
    final fallbackIndex =
        widget.initialOrdinal ?? scope.personalLibrary.readingPosition(_edition.id);
    _initialOrdinal = resolvePassageIndex(
      _passages,
      passageId: widget.initialPassageId,
      fallbackIndex: fallbackIndex,
    );
    _favorite = scope.personalLibrary.isFavorite(widget.sermon.code);
    _generation = 1;
    _positionsListener.itemPositions.addListener(_saveVisiblePosition);
  }

  @override
  void dispose() {
    _positionsListener.itemPositions.removeListener(_saveVisiblePosition);
    super.dispose();
  }

  void _saveVisiblePosition() {
    if (_passages.isEmpty) return;
    final positions = _positionsListener.itemPositions.value;
    if (positions.isEmpty) return;
    final visible = positions.where((p) => p.itemTrailingEdge > 0 && p.itemLeadingEdge < 1).toList();
    if (visible.isEmpty) return;
    visible.sort((a, b) => a.index.compareTo(b.index));
    final ordinal = visible.first.index;
    if (ordinal == _lastSavedOrdinal) return;
    _lastSavedOrdinal = ordinal;
    AppScope.of(context).personalLibrary.setReadingPosition(_edition.id, ordinal);
  }

  void _resetScrollControllers() {
    _positionsListener.itemPositions.removeListener(_saveVisiblePosition);
    _positionsListener = ItemPositionsListener.create();
    _positionsListener.itemPositions.addListener(_saveVisiblePosition);
    _scrollController = ItemScrollController();
  }

  void _switchEdition(String id) {
    final scope = AppScope.of(context);
    final next = _editions.firstWhere((e) => e.id == id);
    final passages = scope.repository.passagesForEdition(next.id);
    var position = scope.personalLibrary.readingPosition(next.id);
    if (passages.isNotEmpty) position = position.clamp(0, passages.length - 1).toInt();
    _resetScrollControllers();
    setState(() {
      _edition = next;
      _passages = passages;
      _initialOrdinal = position;
      _lastSavedOrdinal = -1;
      _generation++;
    });
  }

  Widget _passageText(BuildContext context, Passage passage, double fontSize) {
    final style = TextStyle(fontSize: fontSize, height: 1.55);
    final highlighted = widget.initialPassageId == passage.id &&
        hasValidHighlight(
          passage,
          startOffset: widget.highlightStartOffset,
          endOffset: widget.highlightEndOffset,
        );
    if (!highlighted) {
      return SelectableText(passage.text, style: style);
    }
    final start = widget.highlightStartOffset!;
    final end = widget.highlightEndOffset!;
    final scheme = Theme.of(context).colorScheme;
    return SelectableText.rich(
      TextSpan(
        style: style,
        children: [
          if (start > 0) TextSpan(text: passage.text.substring(0, start)),
          TextSpan(
            text: passage.text.substring(start, end),
            style: TextStyle(
              backgroundColor: scheme.tertiaryContainer,
              color: scheme.onTertiaryContainer,
              fontWeight: FontWeight.w700,
            ),
          ),
          if (end < passage.text.length)
            TextSpan(text: passage.text.substring(end)),
        ],
      ),
    );
  }

  Future<void> _toggleFavorite() async {
    final scope = AppScope.of(context);
    scope.personalLibrary.toggleFavorite(widget.sermon.code);
    if (!mounted) return;
    setState(() => _favorite = !_favorite);
  }

  Future<void> _copyPassage(Passage passage) async {
    final page = passage.sourcePageStart == passage.sourcePageEnd
        ? 'p. ${passage.sourcePageStart}'
        : 'pp. ${passage.sourcePageStart}-${passage.sourcePageEnd}';
    final value = '${passage.text.trim()}\n\n— ${widget.sermon.title}, ${widget.sermon.code}, $page';
    await Clipboard.setData(ClipboardData(text: value));
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Extrait et référence copiés.')),
    );
  }

  Future<void> _searchInSermon() async {
    final controller = TextEditingController();
    final query = await showDialog<String>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Rechercher dans cette prédication'),
        content: TextField(
          controller: controller,
          autofocus: true,
          decoration: const InputDecoration(labelText: 'Mot ou expression'),
          onSubmitted: (value) => Navigator.pop(dialogContext, value),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(dialogContext), child: const Text('Annuler')),
          FilledButton(onPressed: () => Navigator.pop(dialogContext, controller.text), child: const Text('Rechercher')),
        ],
      ),
    );
    controller.dispose();
    if (query == null || query.trim().isEmpty || !mounted) return;
    final terms = query.toLowerCase().trim().split(RegExp(r'\s+')).where((e) => e.isNotEmpty).toList();
    final start = (_lastSavedOrdinal >= 0 ? _lastSavedOrdinal + 1 : 0).clamp(0, _passages.length).toInt();
    int found = -1;
    for (var offset = 0; offset < _passages.length; offset++) {
      final index = (start + offset) % _passages.length;
      final text = _passages[index].text.toLowerCase();
      if (terms.every(text.contains)) {
        found = index;
        break;
      }
    }
    if (found >= 0 && _scrollController.isAttached) {
      await _scrollController.scrollTo(index: found, duration: const Duration(milliseconds: 350));
    } else if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Aucune occurrence trouvée dans cette édition.')));
    }
  }

  void _compareEditions(Passage passage) {
    if (_editions.length < 2) return;
    final other = _editions.firstWhere((edition) => edition.id != _edition.id);
    final otherPassages = AppScope.of(context).repository.passagesForEdition(other.id);
    if (otherPassages.isEmpty) return;
    final otherPassage = otherPassages[passage.ordinal.clamp(0, otherPassages.length - 1).toInt()];
    final details = AppScope.of(context).repository.studyDetailsForPassageIds([passage.id, otherPassage.id]);
    final a = details[passage.id];
    final b = details[otherPassage.id];
    if (a == null || b == null) return;
    Navigator.of(context).push(MaterialPageRoute(
      builder: (_) => ComparisonScreen(passageA: a, passageB: b),
    ));
  }

  @override
  Widget build(BuildContext context) {
    final scope = AppScope.of(context);
    final fontSize = scope.controller.fontSize;
    return Scaffold(
      appBar: AppBar(
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(widget.sermon.title, maxLines: 1, overflow: TextOverflow.ellipsis),
            Text(widget.sermon.code, style: Theme.of(context).textTheme.labelMedium),
          ],
        ),
        actions: [
          IconButton(
            tooltip: 'Rechercher dans cette prédication',
            onPressed: _searchInSermon,
            icon: const Icon(Icons.find_in_page_outlined),
          ),
          IconButton(
            tooltip: _favorite ? 'Retirer des favoris' : 'Ajouter aux favoris',
            onPressed: _toggleFavorite,
            icon: Icon(_favorite ? Icons.bookmark : Icons.bookmark_border),
          ),
        ],
      ),
      body: Column(
        children: [
          if (_editions.length > 1)
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
              child: DropdownButtonFormField<String>(
                initialValue: _edition.id,
                isExpanded: true,
                decoration: const InputDecoration(
                  labelText: 'Version du texte',
                  prefixIcon: Icon(Icons.layers_outlined),
                ),
                items: _editions.map((e) => DropdownMenuItem(
                  value: e.id,
                  child: Text('${e.label} • pages ${e.sourcePageStart}-${e.sourcePageEnd}', maxLines: 1, overflow: TextOverflow.ellipsis),
                )).toList(),
                onChanged: (value) {
                  if (value != null && value != _edition.id) _switchEdition(value);
                },
              ),
            ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            child: Row(
              children: [
                const Icon(Icons.text_fields, size: 20),
                const SizedBox(width: 8),
                Expanded(
                  child: Slider(
                    min: 14,
                    max: 28,
                    divisions: 14,
                    value: fontSize.clamp(14, 28).toDouble(),
                    label: '${fontSize.round()} px',
                    onChanged: scope.controller.setFontSize,
                  ),
                ),
              ],
            ),
          ),
          const Divider(height: 1),
          Expanded(
            child: _passages.isEmpty
                ? const Center(child: Text('Aucun texte disponible pour cette édition.'))
                : ScrollablePositionedList.builder(
                    key: ValueKey('reader-$_generation-${_edition.id}'),
                    itemScrollController: _scrollController,
                    initialScrollIndex: _initialOrdinal,
                    itemPositionsListener: _positionsListener,
                    itemCount: _passages.length,
                    itemBuilder: (context, index) {
                      final passage = _passages[index];
                      final pages = passage.sourcePageStart == passage.sourcePageEnd
                          ? 'Page source ${passage.sourcePageStart}'
                          : 'Pages source ${passage.sourcePageStart}–${passage.sourcePageEnd}';
                      return Center(
                        child: ConstrainedBox(
                          constraints: const BoxConstraints(maxWidth: 900),
                          child: Padding(
                            padding: const EdgeInsets.fromLTRB(20, 18, 20, 8),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.stretch,
                              children: [
                                _passageText(context, passage, fontSize),
                                const SizedBox(height: 8),
                                Wrap(
                                  alignment: WrapAlignment.end,
                                  crossAxisAlignment: WrapCrossAlignment.center,
                                  spacing: 2,
                                  children: [
                                    Text(pages, style: Theme.of(context).textTheme.labelMedium),
                                    IconButton(
                                      tooltip: 'Ajouter ce passage aux signets',
                                      onPressed: () {
                                        scope.personalLibrary.addPassageBookmark(passage.id);
                                        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Passage ajouté aux signets.')));
                                      },
                                      icon: const Icon(Icons.bookmark_add_outlined, size: 20),
                                    ),
                                    IconButton(
                                      tooltip: 'Ajouter à une collection',
                                      onPressed: () => addPassageToCollection(context, passage.id),
                                      icon: const Icon(Icons.create_new_folder_outlined, size: 20),
                                    ),
                                    IconButton(
                                      tooltip: 'Passages similaires',
                                      onPressed: () => Navigator.of(context).push(MaterialPageRoute(
                                        builder: (_) => SimilarPassagesScreen(passageId: passage.id),
                                      )),
                                      icon: const Icon(Icons.hub_outlined, size: 20),
                                    ),
                                    if (_editions.length > 1)
                                      IconButton(
                                        tooltip: 'Comparer les éditions',
                                        onPressed: () => _compareEditions(passage),
                                        icon: const Icon(Icons.compare_arrows, size: 20),
                                      ),
                                    IconButton(
                                      tooltip: 'Copier cet extrait avec sa référence',
                                      onPressed: () => _copyPassage(passage),
                                      icon: const Icon(Icons.copy_outlined, size: 20),
                                    ),
                                  ],
                                ),
                                const Divider(height: 24),
                              ],
                            ),
                          ),
                        ),
                      );
                    },
                  ),
          ),
        ],
      ),
    );
  }
}
