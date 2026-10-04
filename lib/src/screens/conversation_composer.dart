import 'package:flutter/material.dart';

import '../conversation/conversation_models.dart';

class ConversationComposer extends StatefulWidget {
  const ConversationComposer({
    super.key,
    required this.onSend,
    required this.busy,
    this.centered = false,
    this.filters = const ConversationFilterSet(),
  });

  final Future<void> Function(String value) onSend;
  final bool busy;
  final bool centered;
  final ConversationFilterSet filters;

  @override
  State<ConversationComposer> createState() => _ConversationComposerState();
}

class _ConversationComposerState extends State<ConversationComposer> {
  final _controller = TextEditingController();

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    final value = _controller.text.trim();
    if (value.isEmpty || widget.busy) return;
    _controller.clear();
    await widget.onSend(value);
  }

  @override
  Widget build(BuildContext context) {
    final field = TextField(
      controller: _controller,
      enabled: !widget.busy,
      textInputAction: TextInputAction.search,
      onSubmitted: (_) => _submit(),
      minLines: 1,
      maxLines: 5,
      decoration: InputDecoration(
        hintText: 'Posez votre question sur le Message…',
        prefixIcon: const Icon(Icons.manage_search),
        suffixIcon: widget.busy
            ? const Padding(
                padding: EdgeInsets.all(14),
                child: SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2)),
              )
            : IconButton(
                onPressed: _submit,
                icon: const Icon(Icons.arrow_upward_rounded),
                tooltip: 'Envoyer',
              ),
      ),
    );

    return ConstrainedBox(
      constraints: const BoxConstraints(maxWidth: 860),
      child: Column(
        crossAxisAlignment: widget.centered ? CrossAxisAlignment.center : CrossAxisAlignment.stretch,
        children: [
          if (!widget.filters.isEmpty) ...[
            Wrap(
              alignment: widget.centered ? WrapAlignment.center : WrapAlignment.start,
              spacing: 6,
              runSpacing: 6,
              children: [
                if (widget.filters.subjectTerms.isNotEmpty)
                  Chip(label: Text('Sujet : ${widget.filters.subjectTerms.join(' ')}')),
                if (widget.filters.yearMin != null || widget.filters.yearMax != null)
                  Chip(label: Text('Période : ${widget.filters.yearMin ?? '…'}–${widget.filters.yearMax ?? '…'}')),
                if (widget.filters.sourceType != null)
                  Chip(label: Text('Source : ${widget.filters.sourceType == 'book' ? 'livres' : 'prédications'}')),
              ],
            ),
            const SizedBox(height: 8),
          ],
          field,
        ],
      ),
    );
  }
}
