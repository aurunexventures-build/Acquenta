import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../services/auth_service.dart';
import '../services/sync_service.dart';
import 'ai_voice_composer.dart';
import 'ai_microphone_icon.dart';

/// A card field with dictation and fact-preserving AI cleanup beside its label.
class CardTextField extends StatefulWidget {
  final TextEditingController? controller;
  final String initialValue, label, hint;
  final bool required;
  final bool voiceEnabled;
  final bool showCounter;
  final int maxLines;
  final int? maxLength;
  final TextInputType? keyboardType;
  final ValueChanged<String>? onChanged;
  final FormFieldSetter<String>? onSaved;
  final Future<String> Function(String)? organise;
  final Widget? trailing;
  const CardTextField({
    super.key,
    this.controller,
    this.initialValue = '',
    required this.label,
    this.hint = '',
    this.required = false,
    this.voiceEnabled = false,
    this.showCounter = true,
    this.maxLines = 1,
    this.maxLength,
    this.keyboardType,
    this.onChanged,
    this.onSaved,
    this.organise,
    this.trailing,
  });
  @override
  State<CardTextField> createState() => _CardTextFieldState();
}

class _CardTextFieldState extends State<CardTextField> {
  late final _owned = TextEditingController(text: widget.initialValue);
  TextEditingController get _controller => widget.controller ?? _owned;
  Future<String> _organise(String original) async {
    if (widget.organise != null) return widget.organise!(original);
    final auth = context.read<AuthService?>();
    if (auth == null || !auth.isAuthenticated) throw StateError('Sign in');
    final user = auth.currentUser?.uid;
    final service = SyncService();
    try {
      final result = await service.request('/api/v1/text/organise', {
        'purpose': 'card',
        'field': widget.label,
        'text': original,
      }, auth);
      final text = result['text'];
      if (!mounted ||
          user != auth.currentUser?.uid ||
          text is! String ||
          text.trim().isEmpty ||
          text.length > (widget.maxLength ?? 6000)) {
        throw const FormatException();
      }
      return text.trim();
    } finally {
      service.close();
    }
  }

  Future<void> _voiceDraft() async {
    final original = _controller.text;
    final auth = context.read<AuthService?>();
    final user = auth?.currentUser?.uid;
    final draft = await showDialog<String>(
      context: context,
      barrierDismissible: false,
      builder: (_) => AiVoiceComposer(
        initialText: original,
        title: widget.label,
        organise: _organise,
        maxLength: 3000,
      ),
    );
    if (!mounted ||
        draft == null ||
        _controller.text != original ||
        user != auth?.currentUser?.uid) {
      return;
    }
    _controller.text = draft;
    widget.onChanged?.call(draft);
    final messenger = ScaffoldMessenger.maybeOf(context);
    messenger?.clearSnackBars();
    messenger?.showSnackBar(
      SnackBar(
        persist: false,
        duration: const Duration(seconds: 3),
        content: const Text('Wording updated.'),
        action: SnackBarAction(
          label: 'Undo',
          onPressed: () {
            if (mounted && _controller.text == draft) {
              _controller.text = original;
              widget.onChanged?.call(original);
            }
          },
        ),
      ),
    );
  }

  @override
  void dispose() {
    _owned.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(bottom: 12),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            Expanded(
              child: Text(
                widget.label,
                style: Theme.of(context).textTheme.labelLarge,
              ),
            ),
          ],
        ),
        TextFormField(
          controller: _controller,
          maxLines: widget.maxLines,
          maxLength: widget.maxLength,
          keyboardType: widget.keyboardType,
          onChanged: widget.onChanged,
          onSaved: widget.onSaved,
          scrollPadding: const EdgeInsets.only(top: 40, bottom: 96),
          validator: widget.required
              ? (value) => value == null || value.trim().isEmpty
                    ? 'This field is required.'
                    : null
              : null,
          decoration: InputDecoration(
            counterText: widget.showCounter ? null : '',
            hintText: widget.hint,
            border: const OutlineInputBorder(),
            suffixIcon:
                widget.trailing ??
                (widget.voiceEnabled
                    ? IconButton(
                        tooltip: 'Speak with AI',
                        onPressed: _voiceDraft,
                        icon: const AiMicrophoneIcon(),
                      )
                    : null),
            contentPadding: const EdgeInsets.symmetric(
              horizontal: 14,
              vertical: 14,
            ),
          ),
        ),
      ],
    ),
  );
}
