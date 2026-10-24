import 'dart:async';
import 'package:flutter/material.dart';
import '../services/card_conversation_voice.dart';
import '../services/cloud_card_conversation_voice.dart';
import '../services/conversation_audio_activity.dart';
import '../services/conversation_screen_awake.dart';
import 'conversation_listening_indicator.dart';
import 'ai_microphone_icon.dart';

/// A single Groq recording becomes an editable, fact-preserving search query.
class VoicePeopleSearchField extends StatefulWidget {
  final TextEditingController controller;
  final ValueChanged<String> onChanged;
  final Future<String> Function(String) organise;
  final Future<Map<String, dynamic>> Function(String, Map<String, dynamic>)
  request;
  final CardConversationVoice? voice;
  final bool voiceEnabled;
  const VoicePeopleSearchField({
    super.key,
    required this.controller,
    required this.onChanged,
    required this.organise,
    required this.request,
    this.voice,
    this.voiceEnabled = true,
  });
  @override
  State<VoicePeopleSearchField> createState() => _VoicePeopleSearchFieldState();
}

class _VoicePeopleSearchFieldState extends State<VoicePeopleSearchField>
    with WidgetsBindingObserver {
  CardConversationVoice? _voice;
  final _awake = ConversationScreenAwake();
  int _generation = 0;
  bool _listening = false, _working = false;
  String? _error;
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _voice = widget.voice;
  }

  void _cancel() {
    _generation++;
    _awake.close();
    unawaited(_voice?.stop());
    if (mounted) {
      setState(() {
        _listening = false;
        _working = false;
      });
    }
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
    if (_working) return;
    if (_listening) {
      if (_voice is FinishingCardConversationVoice) {
        await (_voice as FinishingCardConversationVoice).finishListening();
      } else {
        _cancel();
      }
      return;
    }
    final generation = ++_generation;
    setState(() {
      _working = true;
      _error = null;
    });
    try {
      _voice ??= CloudCardConversationVoice(
        request: widget.request,
        maxRecordingDuration: const Duration(seconds: 20),
      );
      if (!await _voice!.initialize()) {
        throw StateError('Microphone unavailable');
      }
      if (!mounted || generation != _generation) return;
      _awake.open();
      setState(() {
        _working = false;
        _listening = true;
      });
      await _voice!.listen(
        onResult: (text, finalResult) {
          if (finalResult) unawaited(_interpret(text, generation));
        },
        onDone: () {},
        onError: (_) => _failed(generation),
      );
    } catch (_) {
      _failed(generation);
    }
  }

  void _failed(int generation) {
    if (!mounted || generation != _generation) return;
    _cancel();
    setState(
      () => _error =
          'Could not transcribe that. Check microphone access, retry or type instead.',
    );
  }

  Future<void> _interpret(String transcript, int generation) async {
    if (!mounted || generation != _generation) return;
    _awake.close();
    final raw = transcript.trim();
    widget.controller.text = raw;
    widget.onChanged(raw);
    setState(() {
      _listening = false;
      _working = true;
    });
    try {
      final query = await widget.organise(raw);
      if (!mounted ||
          generation != _generation ||
          widget.controller.text != raw) {
        return;
      }
      widget.controller.text = query;
      widget.onChanged(query);
    } catch (_) {
      if (mounted && generation == _generation) {
        setState(
          () => _error =
              'AI cleanup is unavailable. Your transcribed words are kept.',
        );
      }
    } finally {
      if (mounted && generation == _generation) {
        setState(() => _working = false);
      }
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _generation++;
    _awake.close();
    unawaited(_voice?.dispose());
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.stretch,
    children: [
      TextField(
        key: const ValueKey('familiar-face-search'),
        controller: widget.controller,
        style: const TextStyle(color: Color(0xFF202128), fontSize: 14),
        onChanged: (value) {
          if (_listening || _working) _cancel();
          setState(() => _error = null);
          widget.onChanged(value);
        },
        decoration: InputDecoration(
          hintText: 'Find a familiar face…',
          prefixIcon: const Icon(
            Icons.search_rounded,
            color: Color(0xFF2563EB),
          ),
          filled: true,
          fillColor: Colors.white,
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(14),
            borderSide: BorderSide.none,
          ),
          suffixIcon: IconButton(
            tooltip: widget.voiceEnabled
                ? (_listening
                      ? 'Finish spoken search'
                      : 'Speak to find a familiar face')
                : 'Sign in to use voice search',
            onPressed: !widget.voiceEnabled || _working ? null : _toggle,
            icon: _working
                ? const SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : _listening
                ? const Icon(
                    Icons.stop_circle_outlined,
                    color: Color(0xFF2563EB),
                  )
                : const AiMicrophoneIcon(),
          ),
        ),
      ),
      if (_voice is ConversationAudioActivitySource)
        ConversationListeningIndicator(
          source: _voice as ConversationAudioActivitySource,
        ),
      if (_working)
        const Padding(
          padding: EdgeInsets.only(top: 6),
          child: Text('Understanding your search…'),
        ),
      if (_error != null)
        Text(
          _error!,
          style: TextStyle(color: Theme.of(context).colorScheme.error),
        ),
    ],
  );
}
