import 'dart:async';
import 'package:flutter/material.dart';
import 'package:speech_to_text/speech_to_text.dart';
import 'recall_wireframe.dart';
import 'ai_microphone_icon.dart';

/// Shared dictation controls: original text stays editable; AI runs after speech ends.
class VoiceMagicBar extends StatefulWidget {
  final TextEditingController controller;
  final Future<void> Function() onMagic;
  final ValueChanged<String>? onChanged;
  final bool busy;
  final String magicLabel;
  final bool compact;
  final bool merged, autoStart;
  final Widget? trailing;
  const VoiceMagicBar({
    super.key,
    required this.controller,
    required this.onMagic,
    this.onChanged,
    this.busy = false,
    this.magicLabel = 'Organise with AI',
    this.compact = false,
    this.merged = false,
    this.autoStart = false,
    this.trailing,
  });
  @override
  State<VoiceMagicBar> createState() => _VoiceMagicBarState();
}

class _VoiceMagicBarState extends State<VoiceMagicBar>
    with WidgetsBindingObserver {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    if (widget.autoStart) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) _toggle();
      });
    }
  }

  @override
  void didChangeMetrics() {
    if (mounted) setState(() {});
  }

  final _speech = SpeechToText();
  bool _listening = false;
  String _prefix = '', _status = '';
  Timer? _finishTimer;
  int _generation = 0;
  void _finish() {
    if (!mounted || !_listening) return;
    setState(() => _listening = false);
    final generation = _generation;
    _finishTimer?.cancel();
    _finishTimer = Timer(const Duration(milliseconds: 500), () async {
      if (mounted &&
          generation == _generation &&
          !widget.busy &&
          widget.controller.text.trim().isNotEmpty) {
        await widget.onMagic();
      }
    });
  }

  Future<void> _toggle() async {
    if (_listening) {
      await _speech.stop();
      _finish();
      return;
    }
    _finishTimer?.cancel();
    _generation++;
    try {
      final ready = await _speech.initialize(
        onStatus: (status) {
          if (status == 'done' || status == 'notListening') _finish();
        },
        onError: (_) {
          _generation++;
          _finishTimer?.cancel();
          if (mounted) {
            setState(() {
              _listening = false;
              _status = 'Voice unavailable. You can type instead.';
            });
          }
        },
      );
      if (!mounted) return;
      if (!ready) {
        setState(
          () =>
              _status = 'Allow microphone and speech access, or type instead.',
        );
        return;
      }
      _prefix = widget.controller.text.trim();
      setState(() {
        _listening = true;
        _status = '';
      });
      await _speech.listen(
        onResult: (result) {
          if (!mounted) return;
          final text = [
            if (_prefix.isNotEmpty) _prefix,
            result.recognizedWords,
          ].join(' ');
          widget.controller.value = TextEditingValue(
            text: text,
            selection: TextSelection.collapsed(offset: text.length),
          );
          widget.onChanged?.call(text);
        },
        listenOptions: SpeechListenOptions(
          listenMode: ListenMode.dictation,
          pauseFor: const Duration(seconds: 5),
        ),
      );
    } catch (_) {
      _generation++;
      if (mounted) {
        setState(() {
          _listening = false;
          _status = 'Voice unavailable. You can type instead.';
        });
      }
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _generation++;
    _finishTimer?.cancel();
    if (_listening && _speech.isAvailable) unawaited(_speech.cancel());
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final compact = widget.compact || View.of(context).viewInsets.bottom > 0;
    final magic = SizedBox(
      width: 30,
      height: 30,
      child: RecallWireframe(thinking: widget.busy || _listening),
    );
    if (widget.trailing != null) {
      final style = TextButton.styleFrom(
        padding: const EdgeInsets.symmetric(horizontal: 4),
        minimumSize: const Size(0, 44),
        textStyle: Theme.of(
          context,
        ).textTheme.labelSmall?.copyWith(fontSize: 11),
      );
      return Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            key: const ValueKey('recall-controls-row'),
            children: [
              Expanded(
                child: TextButton.icon(
                  style: style,
                  onPressed: widget.busy ? null : _toggle,
                  icon: Icon(
                    _listening
                        ? Icons.stop_circle_outlined
                        : Icons.mic_none_rounded,
                    size: 17,
                  ),
                  label: Text(_listening ? 'Stop' : 'Speak', maxLines: 1),
                ),
              ),
              Expanded(
                child: Tooltip(
                  message: widget.magicLabel,
                  child: TextButton.icon(
                    style: style,
                    onPressed: widget.busy || _listening
                        ? null
                        : () async {
                            _finishTimer?.cancel();
                            await widget.onMagic();
                          },
                    icon: const Icon(Icons.auto_awesome, size: 17),
                    label: Text(
                      widget.busy ? 'Tidying…' : 'AI tidy',
                      maxLines: 1,
                    ),
                  ),
                ),
              ),
              Expanded(child: widget.trailing!),
            ],
          ),
          if (_status.isNotEmpty)
            Text(
              _status,
              style: TextStyle(
                color: Theme.of(context).colorScheme.error,
                fontSize: 11,
              ),
            ),
        ],
      );
    }
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Wrap(
          spacing: 8,
          runSpacing: 4,
          crossAxisAlignment: WrapCrossAlignment.center,
          children: [
            if (widget.merged) ...[
              FilledButton.icon(
                onPressed: widget.busy ? null : _toggle,
                icon: _listening
                    ? const Icon(Icons.stop_circle_outlined)
                    : const AiMicrophoneIcon(),
                label: Text(
                  widget.busy
                      ? 'Organising…'
                      : _listening
                      ? 'Done speaking'
                      : 'Speak with AI',
                ),
              ),
            ] else if (compact) ...[
              IconButton(
                tooltip: _listening ? 'Done speaking' : 'Speak',
                onPressed: widget.busy ? null : _toggle,
                icon: Icon(
                  _listening
                      ? Icons.stop_circle_outlined
                      : Icons.mic_none_rounded,
                ),
              ),
              IconButton(
                tooltip: widget.magicLabel,
                onPressed: widget.busy || _listening
                    ? null
                    : () async {
                        _finishTimer?.cancel();
                        await widget.onMagic();
                      },
                icon: magic,
              ),
            ] else ...[
              OutlinedButton.icon(
                onPressed: widget.busy ? null : _toggle,
                icon: Icon(
                  _listening
                      ? Icons.stop_circle_outlined
                      : Icons.mic_none_rounded,
                ),
                label: Text(_listening ? 'Done speaking' : 'Speak'),
              ),
              FilledButton.icon(
                onPressed: widget.busy || _listening
                    ? null
                    : () async {
                        _finishTimer?.cancel();
                        await widget.onMagic();
                      },
                icon: magic,
                label: Text(widget.busy ? 'Organising…' : widget.magicLabel),
              ),
            ],
          ],
        ),
        if (_listening && !compact)
          const Text('Listening… AI will organise your words when you finish.'),
        if (_status.isNotEmpty)
          Text(
            _status,
            style: TextStyle(color: Theme.of(context).colorScheme.error),
          ),
      ],
    );
  }
}
