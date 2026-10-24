import 'package:flutter/material.dart';
import 'voice_magic_bar.dart';

/// Speech and AI produce a draft here. The destination field changes only on Use.
class AiVoiceComposer extends StatefulWidget {
  final String initialText, title, applyLabel;
  final int maxLength;
  final Future<String> Function(String) organise;
  const AiVoiceComposer({
    super.key,
    required this.initialText,
    required this.title,
    required this.organise,
    this.applyLabel = 'Use this wording',
    this.maxLength = 3000,
  });
  @override
  State<AiVoiceComposer> createState() => _AiVoiceComposerState();
}

class _AiVoiceComposerState extends State<AiVoiceComposer> {
  late final _text = TextEditingController(text: widget.initialText);
  bool _busy = false, _reviewed = false;
  String? _error;
  Future<void> _organise() async {
    if (_busy || _text.text.trim().isEmpty) return;
    final original = _text.text;
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      final result = await widget.organise(original);
      if (!mounted || _text.text != original) return;
      setState(() {
        _text.text = result;
        _reviewed = true;
      });
    } catch (_) {
      if (mounted) {
        setState(
          () => _error =
              'Could not organise this yet. Your draft is kept. Try again or edit it yourself.',
        );
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  void dispose() {
    _text.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => PopScope(
    canPop: !_busy,
    child: Dialog(
      insetPadding: const EdgeInsets.all(16),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 480),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Flexible(
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(20),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Text(
                      widget.title,
                      style: Theme.of(context).textTheme.titleLarge,
                    ),
                    const SizedBox(height: 8),
                    const Text(
                      'Speak freely. Review the AI draft before adding it.',
                    ),
                    const SizedBox(height: 12),
                    TextField(
                      controller: _text,
                      minLines: 3,
                      maxLines: 6,
                      maxLength: widget.maxLength,
                      readOnly: _busy,
                      onChanged: (_) => setState(() {}),
                      scrollPadding: const EdgeInsets.only(top: 32, bottom: 96),
                      decoration: InputDecoration(
                        hintText: 'Speak or type your draft…',
                        border: const OutlineInputBorder(),
                        suffixIcon: VoiceMagicBar(
                          controller: _text,
                          onMagic: _organise,
                          busy: _busy,
                          merged: true,
                          compact: true,
                          autoStart: true,
                          onChanged: (_) => setState(() => _reviewed = false),
                        ),
                      ),
                    ),
                    TextButton(
                      onPressed: _busy ? null : _organise,
                      child: const Text('Organise typed text'),
                    ),
                    if (_error != null)
                      Text(
                        _error!,
                        style: TextStyle(
                          color: Theme.of(context).colorScheme.error,
                        ),
                      ),
                  ],
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.all(12),
              child: Wrap(
                spacing: 8,
                children: [
                  TextButton(
                    onPressed: _busy ? null : () => Navigator.pop(context),
                    child: const Text('Cancel'),
                  ),
                  FilledButton(
                    onPressed: _busy || !_reviewed
                        ? null
                        : () => Navigator.pop(context, _text.text.trim()),
                    child: Text(widget.applyLabel),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    ),
  );
}
