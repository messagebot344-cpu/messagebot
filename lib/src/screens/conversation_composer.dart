import 'package:flutter/material.dart';

class ConversationComposer extends StatefulWidget {
  const ConversationComposer({super.key, required this.onSend, required this.busy, this.centered = false});

  final Future<void> Function(String value) onSend;
  final bool busy;
  final bool centered;

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
    return ConstrainedBox(
      constraints: const BoxConstraints(maxWidth: 860),
      child: TextField(
        controller: _controller,
        enabled: !widget.busy,
        textInputAction: TextInputAction.search,
        onSubmitted: (_) => _submit(),
        minLines: 1,
        maxLines: 5,
        decoration: InputDecoration(
          hintText: 'Rechercher dans toute Sa Parole…',
          prefixIcon: const Icon(Icons.manage_search),
          suffixIcon: widget.busy
              ? const Padding(padding: EdgeInsets.all(14), child: SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2)))
              : IconButton(onPressed: _submit, icon: const Icon(Icons.arrow_upward_rounded), tooltip: 'Envoyer'),
        ),
      ),
    );
  }
}
