import 'dart:async';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../services/auth_service.dart';
import '../services/sync_service.dart';
import '../services/cloud_card_conversation_voice.dart';
import '../services/conversation_screen_awake.dart';
import 'conversation_listening_indicator.dart';
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
  final bool autoOrganise;
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
    this.autoOrganise = true,
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

  CloudCardConversationVoice? _voice;
  SyncService? _service;
  String? _voiceUid;
  final _awake = ConversationScreenAwake();
  bool _listening = false;
  String _status = '';
  Timer? _finishTimer;
  int _generation = 0;

  void _cancel() {
    _generation++;
    _awake.close();
    unawaited(_voice?.stop());
    if (mounted) setState(() => _listening = false);
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if ([
      AppLifecycleState.paused,
      AppLifecycleState.hidden,
      AppLifecycleState.detached,
    ].contains(state)) {
      _cancel();
    }
  }

  Future<void> _toggle() async {
    if (_listening) {
      await _voice?.finishListening();
      return;
    }
    final auth = context.read<AuthService?>();
    if (auth == null || !auth.isAuthenticated) {
      setState(() => _status = 'Sign in to use AI voice, or type instead.');
      return;
    }
    final uid = auth.currentUser?.uid;
    final generation = ++_generation;
    final before = widget.controller.text;
    bool valid() =>
        mounted && generation == _generation && auth.currentUser?.uid == uid;
    try {
      _service ??= SyncService();
      if (_voiceUid != uid) {
        await _voice?.dispose();
        _voice = null;
        _voiceUid = uid;
      }
      _voice ??= CloudCardConversationVoice(
        request: (path, body) {
          if (auth.currentUser?.uid != uid) throw StateError('Account changed');
          return _service!.request(path, body, auth);
        },
      );
      if (!await _voice!.initialize()) {
        throw StateError('Microphone unavailable');
      }
      if (!valid()) return;
      _awake.open();
      setState(() {
        _listening = true;
        _status = '';
      });
      await _voice!.listen(
        onResult: (text, finalResult) async {
          if (!finalResult || !valid()) return;
          _awake.close();
          setState(() => _listening = false);
          // A delayed recording must never replace something typed in the meantime.
          if (widget.controller.text != before || text.trim().isEmpty) return;
          final result = [
            if (before.trim().isNotEmpty) before.trim(),
            text.trim(),
          ].join(' ');
          widget.controller.value = TextEditingValue(
            text: result,
            selection: TextSelection.collapsed(offset: result.length),
          );
          widget.onChanged?.call(result);
          if (valid() && !widget.busy && widget.autoOrganise) {
            await widget.onMagic();
          }
        },
        onDone: () {},
        onError: (_) {
          if (!valid()) return;
          _cancel();
          setState(
            () => _status = 'Could not transcribe. Retry or type instead.',
          );
        },
      );
    } catch (_) {
      if (!valid()) return;
      _cancel();
      setState(() => _status = 'Voice unavailable. Retry or type instead.');
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _generation++;
    _finishTimer?.cancel();
    _awake.close();
    _voice?.dispose();
    _service?.close();
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
          if (_voice != null && _listening)
            ConversationListeningIndicator(source: _voice!),
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
              if (compact)
                IconButton(
                  tooltip: _listening ? 'Done speaking' : 'Speak with AI',
                  onPressed: widget.busy ? null : _toggle,
                  icon: widget.busy
                      ? const SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : _listening
                      ? const Icon(Icons.stop_circle_outlined)
                      : const AiMicrophoneIcon(),
                )
              else
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
        if (_voice != null && _listening)
          ConversationListeningIndicator(source: _voice!),
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
