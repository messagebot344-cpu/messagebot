import 'package:flutter/material.dart';

import '../conversation/conversation_models.dart';

class ConversationFilterSheet extends StatefulWidget {
  const ConversationFilterSheet({
    super.key,
    required this.initialValue,
    required this.onApply,
  });

  final ConversationFilterSet initialValue;
  final ValueChanged<ConversationFilterSet> onApply;

  @override
  State<ConversationFilterSheet> createState() => _ConversationFilterSheetState();
}

class _ConversationFilterSheetState extends State<ConversationFilterSheet> {
  late final TextEditingController _subject;
  late final TextEditingController _yearMin;
  late final TextEditingController _yearMax;
  String? _sourceType;

  @override
  void initState() {
    super.initState();
    _subject = TextEditingController(text: widget.initialValue.subjectTerms.join(' '));
    _yearMin = TextEditingController(text: widget.initialValue.yearMin?.toString() ?? '');
    _yearMax = TextEditingController(text: widget.initialValue.yearMax?.toString() ?? '');
    _sourceType = widget.initialValue.sourceType;
  }

  @override
  void dispose() {
    _subject.dispose();
    _yearMin.dispose();
    _yearMax.dispose();
    super.dispose();
  }

  int? _yearOf(TextEditingController controller) {
    final value = int.tryParse(controller.text.trim());
    if (value == null || value < 1800 || value > 2200) return null;
    return value;
  }

  void _apply() {
    final terms = _subject.text
        .trim()
        .split(RegExp(r'\s+'))
        .where((value) => value.isNotEmpty)
        .toList(growable: false);
    widget.onApply(ConversationFilterSet(
      subjectTerms: terms,
      yearMin: _yearOf(_yearMin),
      yearMax: _yearOf(_yearMax),
      sourceType: _sourceType,
    ));
    Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: SingleChildScrollView(
        padding: EdgeInsets.fromLTRB(
          20,
          18,
          20,
          20 + MediaQuery.viewInsetsOf(context).bottom,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                Expanded(child: Text('Filtres de recherche', style: Theme.of(context).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w800))),
                IconButton(onPressed: () => Navigator.pop(context), icon: const Icon(Icons.close), tooltip: 'Fermer'),
              ],
            ),
            const SizedBox(height: 14),
            TextField(
              controller: _subject,
              decoration: const InputDecoration(
                labelText: 'Sujet',
                hintText: 'Ex. mariage foi guérison',
                prefixIcon: Icon(Icons.topic_outlined),
              ),
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _yearMin,
                    keyboardType: TextInputType.number,
                    decoration: const InputDecoration(labelText: 'De', hintText: '1960'),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: TextField(
                    controller: _yearMax,
                    keyboardType: TextInputType.number,
                    decoration: const InputDecoration(labelText: 'À', hintText: '1965'),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            DropdownButtonFormField<String?>(
              initialValue: _sourceType,
              isExpanded: true,
              decoration: const InputDecoration(labelText: 'Source', prefixIcon: Icon(Icons.source_outlined)),
              items: const [
                DropdownMenuItem<String?>(value: null, child: Text('Toutes les sources')),
                DropdownMenuItem<String?>(value: 'sermon', child: Text('Prédications')),
                DropdownMenuItem<String?>(value: 'book', child: Text('Livres')),
              ],
              onChanged: (value) => setState(() => _sourceType = value),
            ),
            const SizedBox(height: 18),
            FilledButton.icon(
              onPressed: _apply,
              icon: const Icon(Icons.check),
              label: const Text('Appliquer les filtres'),
            ),
          ],
        ),
      ),
    );
  }
}
