import 'conversation_audio_activity.dart';
import 'dart:async';
import 'dart:convert';
import 'recording_file_io.dart'
    if (dart.library.js_interop) 'recording_file_web.dart'
    as recordings;
import 'package:audioplayers/audioplayers.dart';
import 'package:flutter/foundation.dart';
import 'package:record/record.dart';
import 'card_conversation_voice.dart';

/// A recorded turn ends after a brief 1.2-second silence, before transcription.
class SpeechTurnSilence {
  DateTime? lastSpeech;
  void update(double decibels, DateTime now) {
    if (decibels > -42) lastSpeech = now;
  }

  bool finished(DateTime now) =>
      lastSpeech != null &&
      now.difference(lastSpeech!) >= const Duration(milliseconds: 1200);
}

/// The API key remains on the backend. Audio files are removed after upload/cancel.
class CloudCardConversationVoice
    implements
        CardConversationVoice,
        ConversationAudioActivitySource,
        FinishingCardConversationVoice {
  final Future<Map<String, dynamic>> Function(String, Map<String, dynamic>)
  request;
  CloudCardConversationVoice({
    required this.request,
    this.maxRecordingDuration = const Duration(seconds: 90),
  });
  final Duration maxRecordingDuration;
  Future<void> Function()? _finishRecording;
  @override
  Future<void> finishListening() async {
    await _finishRecording?.call();
  }

  @override
  final ValueNotifier<ConversationAudioActivity> activity =
      ValueNotifier<ConversationAudioActivity>(
        const ConversationAudioActivity(ConversationAudioPhase.idle),
      );
  void _activity(ConversationAudioPhase phase, [double level = 0]) {
    if (!_disposed) activity.value = ConversationAudioActivity(phase, level);
  }

  final _recorder = AudioRecorder();
  final _player = AudioPlayer();
  final _cache = <String, Uint8List>{};
  final _pendingAudio = <String, Future<Uint8List>>{};
  Future<Uint8List> _audioFor(String text) async {
    final cached = _cache[text];
    if (cached != null) return cached;
    final pending = _pendingAudio[text];
    if (pending != null) return pending;
    final future = () async {
      final result = await request('/api/v1/speech/speak', {'text': text});
      final audio = base64Decode(result['audio'] as String);
      if (!_disposed) {
        if (_cache.length >= 12) _cache.remove(_cache.keys.first);
        _cache[text] = audio;
      }
      return audio;
    }();
    _pendingAudio[text] = future;
    try {
      return await future;
    } finally {
      if (identical(_pendingAudio[text], future)) _pendingAudio.remove(text);
    }
  }

  Future<void> prepareQuestions(List<String> questions) async {
    if (_disposed || kIsWeb) return;
    await Future.wait(
      questions.map((question) async {
        try {
          await _audioFor(question);
        } catch (_) {
          /* Normal playback can retry. */
        }
      }),
    );
  }

  StreamSubscription<Amplitude>? _amplitude;
  StreamSubscription<void>? _completed;
  Timer? _deadline;
  Completer<void>? _playback;
  int _generation = 0;
  bool _disposed = false, _recording = false;

  @override
  Future<bool> initialize() async {
    if (_disposed) return false;
    try {
      _completed ??= _player.onPlayerComplete.listen((_) => _finishPlayback());
      return await _recorder.hasPermission();
    } catch (_) {
      return false;
    }
  }

  void _finishPlayback() {
    final pending = _playback;
    _playback = null;
    if (pending != null && !pending.isCompleted) pending.complete();
  }

  @override
  Future<void> speak(String text) async {
    if (kIsWeb) return;
    final turn = _generation;
    // Groq speech supports 200 characters per request; split without losing words.
    final chunks = <String>[];
    var remaining = text.trim();
    while (remaining.isNotEmpty) {
      var end = remaining.length > 190
          ? remaining.lastIndexOf(' ', 190)
          : remaining.length;
      if (end <= 0) end = remaining.length > 190 ? 190 : remaining.length;
      chunks.add(remaining.substring(0, end));
      remaining = remaining.substring(end).trimLeft();
    }
    for (final chunk in chunks) {
      if (_disposed || turn != _generation) return;
      final audio = await _audioFor(chunk);
      if (_disposed || turn != _generation) return;
      final completion = Completer<void>();
      _playback = completion;
      try {
        await _player.play(BytesSource(audio, mimeType: 'audio/wav'));
        await completion.future.timeout(const Duration(seconds: 45));
      } finally {
        if (identical(_playback, completion)) _finishPlayback();
      }
    }
  }

  @override
  Future<void> listen({
    required void Function(String, bool) onResult,
    required VoidCallback onDone,
    required void Function(String) onError,
  }) async {
    final turn = ++_generation;
    if (_disposed) return;
    final path = recordings.recordingPath();
    await _recorder.start(
      RecordConfig(
        encoder: kIsWeb ? AudioEncoder.wav : AudioEncoder.aacLc,
        bitRate: 32000,
        sampleRate: 16000,
        numChannels: 1,
      ),
      path: path,
    );
    if (_disposed || turn != _generation) {
      await _recorder.cancel();
      return;
    }
    _recording = true;
    _activity(ConversationAudioPhase.listening);
    final silence = SpeechTurnSilence();
    var finishing = false;
    Future<void> finish() async {
      if (finishing || turn != _generation || _disposed) return;
      finishing = true;
      _finishRecording = null;
      _activity(ConversationAudioPhase.transcribing);
      _deadline?.cancel();
      await _amplitude?.cancel();
      _amplitude = null;
      try {
        final recorded = await _recorder.stop();
        _recording = false;
        final audio = await recordings.readAndDeleteRecording(recorded ?? path);
        if (_disposed || turn != _generation) return;
        if (silence.lastSpeech == null) throw StateError('No speech heard');
        final result = await request('/api/v1/speech/transcribe', {
          'audio': base64Encode(audio),
          if (kIsWeb) 'mimeType': 'audio/wav',
        });
        if (_disposed || turn != _generation) return;
        _activity(ConversationAudioPhase.idle);
        onResult(result['text'] as String, true);
        // The final result commits immediately: the silence wait already happened.
      } catch (_) {
        if (!_disposed && turn == _generation) {
          _activity(ConversationAudioPhase.idle);
          onError('Could not hear that reply. Try again or type.');
        }
      }
    }

    _finishRecording = finish;
    _amplitude = _recorder
        .onAmplitudeChanged(const Duration(milliseconds: 200))
        .listen(
          (value) {
            if (_disposed || turn != _generation || finishing) return;
            _activity(
              ConversationAudioPhase.listening,
              ((value.current + 55) / 35).clamp(0.0, 1.0),
            );
            final now = DateTime.now();
            silence.update(value.current, now);
            if (silence.finished(now)) unawaited(finish());
          },
          onError: (_) {
            if (turn == _generation) onError('Recording interrupted.');
          },
        );
    _deadline = Timer(
      kIsWeb && maxRecordingDuration.inSeconds > 20
          ? const Duration(seconds: 20)
          : maxRecordingDuration,
      () => unawaited(finish()),
    );
  }

  @override
  Future<void> stop() async {
    _generation++;
    _finishRecording = null;
    _activity(ConversationAudioPhase.idle);
    _deadline?.cancel();
    _finishPlayback();
    await _amplitude?.cancel();
    _amplitude = null;
    if (_recording) {
      _recording = false;
      await _recorder.cancel();
    }
    await _player.stop();
  }

  @override
  Future<void> dispose() async {
    if (_disposed) return;
    _disposed = true;
    await stop();
    await _completed?.cancel();
    await _player.dispose();
    await _recorder.dispose();
    _cache.clear();
    activity.dispose();
  }
}
