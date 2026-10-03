import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:scrollable_positioned_list/scrollable_positioned_list.dart';

import '../app_scope.dart';
import '../models/models.dart';
import 'collection_picker.dart';
import 'similar_passages_screen.dart';

class BookReaderScreen extends StatefulWidget {
  const BookReaderScreen({
    super.key,
    required this.source,
    this.initialPassageId,
  });

  final CorpusSourceSummary source;
  final int? initialPassageId;

  @override
  State<BookReaderScreen> createState() => _BookReaderScreenState();
}

class _BookReaderScreenState extends State<BookReaderScreen> {
  final ItemScrollController _scrollController = ItemScrollController();
  final ItemPositionsListener _positions = ItemPositionsListener.create();
  late List<Passage> _passages;
  late List<BookChapterSummary> _chapters;
  bool _initialized = false;
  int _initialIndex = 0;
  int? _selectedChapterId;
  int _lastSaved = -1;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_initialized) return;
    _initialized = true;
    final scope = AppScope.of(context);
    _chapters = scope.repository.chaptersForBook(widget.source.id);
    _passages = scope.repository.passagesForBook(widget.source.id);
    final initialId = widget.initialPassageId;
    if (initialId != null) {
      final found = _passages.indexWhere((p) => p.id == initialId);
      if (found >= 0) _initialIndex = found;
    } else {
      _initialIndex = scope.personalLibrary.readingPosition(widget.source.id);
      if (_passages.isNotEmpty) {
        _initialIndex = _initialIndex.clamp(0, _passages.length - 1).toInt();
      }
    }
    _positions.itemPositions.addListener(_savePosition);
  }

  @override
  void dispose() {
    _positions.itemPositions.removeListener(_savePosition);
    super.dispose();
  }

  void _savePosition() {
    final visible = _positions.itemPositions.value
        .where((p) => p.itemTrailingEdge > 0 && p.itemLeadingEdge < 1)
        .toList();
    if (visible.isEmpty) return;
    visible.sort((a, b) => a.index.compareTo(b.index));
    final index = visible.first.index;
    if (index == _lastSaved) return;
    _lastSaved = index;
    AppScope.of(context).personalLibrary.setReadingPosition(widget.source.id, index);
  }

  void _jumpToChapter(int? chapterId) {
    if (chapterId == null) return;
    final chapter = _chapters.firstWhere((c) => c.id == chapterId);
    final index = _passages.indexWhere(
      (p) => p.sourcePageStart >= chapter.sourcePageStart && p.sourcePageStart <= chapter.sourcePageEnd,
    );
    if (index >= 0 && _scrollController.isAttached) {
      _scrollController.scrollTo(index: index, duration: const Duration(milliseconds: 350));
    }
    setState(() => _selectedChapterId = chapterId);
  }

  Future<void> _copy(Passage passage) async {
    final page = passage.sourcePageStart == passage.sourcePageEnd
        ? 'p. ${passage.sourcePageStart}'
        : 'pp. ${passage.sourcePageStart}-${passage.sourcePageEnd}';
    await Clipboard.setData(ClipboardData(text: '${passage.text.trim()}\n\n— ${widget.source.title}, $page'));
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Extrait et référence copiés.')));
  }

  @override
  Widget build(BuildContext context) {
    final scope = AppScope.of(context);
    final fontSize = scope.controller.fontSize;
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.source.title, maxLines: 1, overflow: TextOverflow.ellipsis),
      ),
      body: Column(
        children: [
          if (_chapters.isNotEmpty)
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
              child: DropdownButtonFormField<int>(
                value: _selectedChapterId,
                isExpanded: true,
                decoration: const InputDecoration(
                  labelText: 'Chapitre',
                  prefixIcon: Icon(Icons.account_tree_outlined),
                ),
                hint: const Text('Choisir un chapitre'),
                items: _chapters.map((chapter) => DropdownMenuItem(
                  value: chapter.id,
                  child: Text(chapter.title, overflow: TextOverflow.ellipsis),
                )).toList(),
                onChanged: _jumpToChapter,
              ),
            ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
            child: Row(
              children: [
                const Icon(Icons.text_fields, size: 20),
                Expanded(
                  child: Slider(
                    min: 14,
                    max: 28,
                    divisions: 14,
                    value: fontSize.clamp(14, 28).toDouble(),
                    onChanged: scope.controller.setFontSize,
                  ),
                ),
              ],
            ),
          ),
          const Divider(height: 1),
          Expanded(
            child: ScrollablePositionedList.builder(
              itemScrollController: _scrollController,
              itemPositionsListener: _positions,
              initialScrollIndex: _initialIndex,
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
                          SelectableText(passage.text, style: TextStyle(fontSize: fontSize, height: 1.55)),
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
                              IconButton(
                                tooltip: 'Copier cet extrait avec sa référence',
                                onPressed: () => _copy(passage),
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
