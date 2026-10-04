import 'package:flutter/material.dart';

import '../app_scope.dart';
import '../models/models.dart';
import '../search_v4/canonical_sentence_locator.dart';
import 'passage_navigation.dart';

class ConcordanceScreen extends StatefulWidget {
  const ConcordanceScreen({super.key});

  @override
  State<ConcordanceScreen> createState() => _ConcordanceScreenState();
}

class _ConcordanceScreenState extends State<ConcordanceScreen> {
  final TextEditingController _controller = TextEditingController();
  List<TermStat> _terms = const [];
  List<StudyPassage> _occurrences = const [];
  String? _selectedTerm;
  CorpusSourceType? _sourceType;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _lookupTerms(String value) {
    setState(() {
      _terms = AppScope.of(context).studyEngine.concordance.searchTerms(value, limit: 80);
      _occurrences = const [];
      _selectedTerm = null;
    });
  }

  void _openTerm(String term) {
    final results = AppScope.of(context).studyEngine.concordance.occurrences(
      term,
      limit: 200,
      sourceType: _sourceType,
    );
    setState(() {
      _selectedTerm = term;
      _occurrences = results;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Concordance')),
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 1100),
          child: Column(
            children: [
              Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  children: [
                    TextField(
                      controller: _controller,
                      onChanged: _lookupTerms,
                      decoration: const InputDecoration(
                        labelText: 'Mot ou expression',
                        prefixIcon: Icon(Icons.menu_book_outlined),
                      ),
                    ),
                    const SizedBox(height: 10),
                    SegmentedButton<CorpusSourceType?>(
                      segments: const [
                        ButtonSegment(value: null, label: Text('Tout')),
                        ButtonSegment(value: CorpusSourceType.sermon, label: Text('Prédications')),
                        ButtonSegment(value: CorpusSourceType.book, label: Text('Livres')),
                      ],
                      selected: {_sourceType},
                      onSelectionChanged: (value) {
                        setState(() => _sourceType = value.first);
                        if (_selectedTerm != null) _openTerm(_selectedTerm!);
                      },
                    ),
                  ],
                ),
              ),
              Expanded(
                child: _selectedTerm == null
                    ? _TermList(terms: _terms, onTap: _openTerm)
                    : _OccurrenceList(
                        term: _selectedTerm!,
                        occurrences: _occurrences,
                        onBack: () => setState(() {
                          _selectedTerm = null;
                          _occurrences = const [];
                        }),
                      ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _TermList extends StatelessWidget {
  const _TermList({required this.terms, required this.onTap});
  final List<TermStat> terms;
  final ValueChanged<String> onTap;

  @override
  Widget build(BuildContext context) {
    if (terms.isEmpty) {
      return const Center(child: Text('Saisissez un terme pour parcourir la concordance.'));
    }
    return ListView.separated(
      itemCount: terms.length,
      separatorBuilder: (_, __) => const Divider(height: 1),
      itemBuilder: (context, index) {
        final term = terms[index];
        return ListTile(
          title: Text(term.term),
          subtitle: Text('${term.totalOccurrences} occurrence(s) • ${term.documentCount} passage(s)'),
          trailing: const Icon(Icons.chevron_right),
          onTap: () => onTap(term.term),
        );
      },
    );
  }
}

class _OccurrenceList extends StatelessWidget {
  const _OccurrenceList({required this.term, required this.occurrences, required this.onBack});
  final String term;
  final List<StudyPassage> occurrences;
  final VoidCallback onBack;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        ListTile(
          leading: IconButton(onPressed: onBack, icon: const Icon(Icons.arrow_back)),
          title: Text('« $term »'),
          subtitle: Text('${occurrences.length} passage(s) affiché(s)'),
        ),
        const Divider(height: 1),
        Expanded(
          child: occurrences.isEmpty
              ? const Center(child: Text('Aucune occurrence dans ce filtre.'))
              : ListView.separated(
                  itemCount: occurrences.length,
                  separatorBuilder: (_, __) => const Divider(height: 1),
                  itemBuilder: (context, index) {
                    final item = occurrences[index];
                    final sentence = const CanonicalSentenceLocator().locate(
                      item.passage.id,
                      item.passage.text,
                      term,
                    );
                    final validSentence = sentence != null &&
                        sentence.startOffset >= 0 &&
                        sentence.endOffset <= item.passage.text.length &&
                        sentence.startOffset < sentence.endOffset;
                    final snippet = (validSentence
                            ? item.passage.text.substring(
                                sentence.startOffset,
                                sentence.endOffset,
                              )
                            : item.passage.text)
                        .replaceAll(RegExp(r'\s+'), ' ')
                        .trim();
                    return ListTile(
                      title: Text(item.source.title, maxLines: 1, overflow: TextOverflow.ellipsis),
                      subtitle: Text('${item.referenceLabel}\n$snippet', maxLines: 4, overflow: TextOverflow.ellipsis),
                      isThreeLine: true,
                      onTap: () => openStudyPassage(
                        context,
                        item,
                        highlightStartOffset:
                            validSentence ? sentence.startOffset : null,
                        highlightEndOffset:
                            validSentence ? sentence.endOffset : null,
                      ),
                    );
                  },
                ),
        ),
      ],
    );
  }
}
