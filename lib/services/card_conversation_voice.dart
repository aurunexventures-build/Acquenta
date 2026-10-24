import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:flutter_tts/flutter_tts.dart';
import 'package:speech_to_text/speech_to_text.dart';

abstract class CardConversationVoice {
  Future<bool> initialize();
  Future<void> speak(String text);
  Future<void> listen({
    required void Function(String text, bool finalResult) onResult,
    required VoidCallback onDone,
    required void Function(String message) onError,
  });
  Future<void> stop();
  Future<void> dispose();
}

/// Select only English male voices; never substitute a female default.
Map<String, String>? preferredCardVoice(
  Iterable<dynamic> voices, {
  bool browser = false,
}) {
  final candidates = voices
      .whereType<Map>()
      .map(
        (voice) => voice.map(
          (key, value) => MapEntry(key.toString(), value.toString()),
        ),
      )
      .where(
        (voice) =>
            (voice['gender']?.toLowerCase() == 'male' ||
                (browser &&
                    voice['gender'] == null &&
                    (RegExp(
                          r'\bmale\b',
                          caseSensitive: false,
                        ).hasMatch(voice['name'] ?? '') ||
                        RegExp(
                          r'^(Daniel|Alex|Fred)(?: \(|$)',
                          caseSensitive: false,
                        ).hasMatch(voice['name'] ?? '')))) &&
            (voice['locale'] ?? '').toLowerCase().startsWith('en-'),
      )
      .toList();
  int score(Map<String, String> voice) {
    final quality = switch (voice['quality']) {
      'premium' => 200,
      'enhanced' => 100,
      _ => 0,
    };
    return quality + (voice['locale'] == 'en-GB' ? 10 : 0);
  }

  candidates.sort((a, b) => score(b).compareTo(score(a)));
  return candidates.isEmpty ? null : candidates.first;
}

class MaleVoiceUnavailable implements Exception {}

/// One owned speech session per conversation; speech output finishes before input starts.
class DeviceCardConversationVoice implements CardConversationVoice {
  final SpeechToText _speech = SpeechToText();
  final FlutterTts _tts = FlutterTts();
  Completer<void>? _utterance;
  bool _hasMaleVoice = false;
  VoidCallback? _onDone;
  void Function(String)? _onError;
  int _generation = 0;
  bool _disposed = false, _listening = false, _ready = false;

  @override
  Future<bool> initialize() async {
    if (_disposed) return false;
    if (_ready) return true;
    try {
      await _tts.awaitSpeakCompletion(false);
      _tts.setCompletionHandler(_finishSpeech);
      _tts.setCancelHandler(_finishSpeech);
      _tts.setErrorHandler((message) => _finishSpeech(StateError(message)));
      if (!kIsWeb && defaultTargetPlatform == TargetPlatform.iOS) {
        await _tts.setSharedInstance(true);
        await _tts.setIosAudioCategory(
          IosTextToSpeechAudioCategory.playback,
          [IosTextToSpeechAudioCategoryOptions.duckOthers],
          IosTextToSpeechAudioMode.spokenAudio,
        );
      }
      Map<String, String>? voice;
      for (var attempt = 0; attempt < (kIsWeb ? 6 : 1); attempt++) {
        if (_disposed) return false;
        final voices = await _tts.getVoices;
        voice = preferredCardVoice(
          voices is List ? voices : const [],
          browser: kIsWeb,
        );
        if (voice != null || !kIsWeb) break;
        // Browsers populate their voice list asynchronously after page load.
        if (attempt < 5) {
          await Future<void>.delayed(const Duration(milliseconds: 150));
        }
      }
      if (voice != null) {
        await _tts.setVoice({
          'name': voice['name']!,
          'locale': voice['locale']!,
          if (voice['identifier'] != null) 'identifier': voice['identifier']!,
        });
        await _tts.setSpeechRate(kIsWeb ? 0.95 : 0.46);
        await _tts.setPitch(1.0);
        _hasMaleVoice = true;
      }
      if (_disposed) return false;
      _ready = await _speech.initialize(
        onStatus: (status) {
          if (_disposed || !_listening) return;
          if (status == 'done' || status == 'notListening') {
            _listening = false;
            _onDone?.call();
          }
        },
        onError: (error) {
          if (_disposed || !_listening) return;
          _listening = false;
          _onError?.call(error.errorMsg);
        },
      );
      if (_disposed) {
        await stop();
        return false;
      }
      return _ready;
    } catch (_) {
      return false;
    }
  }

  void _finishSpeech([Object? error]) {
    final utterance = _utterance;
    _utterance = null;
    if (utterance == null || utterance.isCompleted) return;
    if (error == null) {
      utterance.complete();
    } else {
      utterance.completeError(error);
    }
  }

  @override
  Future<void> speak(String text) async {
    // Browser conversations show replies as text; microphone input stays available.
    if (_disposed || kIsWeb) return;
    if (!_hasMaleVoice) throw MaleVoiceUnavailable();
    _finishSpeech();
    final completion = Completer<void>();
    _utterance = completion;
    try {
      await Future.wait([
        _tts.speak(text).then<void>((_) {}),
        completion.future,
      ], eagerError: true).timeout(Duration(seconds: 30 + text.length ~/ 8));
    } finally {
      if (identical(_utterance, completion)) _finishSpeech();
    }
  }

  @override
  Future<void> listen({
    required void Function(String, bool) onResult,
    required VoidCallback onDone,
    required void Function(String) onError,
  }) async {
    if (_disposed || !_ready) throw StateError('Voice unavailable');
    final generation = ++_generation;
    _onDone = onDone;
    _onError = onError;
    _listening = true;
    await _speech.listen(
      onResult: (result) {
        if (!_disposed && generation == _generation) {
          onResult(result.recognizedWords, result.finalResult);
        }
      },
      listenOptions: SpeechListenOptions(
        listenMode: ListenMode.dictation,
        partialResults: true,
        cancelOnError: true,
        pauseFor: const Duration(seconds: 8),
        listenFor: const Duration(seconds: 90),
      ),
    );
  }

  @override
  Future<void> stop() async {
    _generation++;
    _finishSpeech();
    _listening = false;
    _onDone = null;
    _onError = null;
    await Future.wait([
      _speech.cancel().catchError((_) {}),
      _tts.stop().then<void>((_) {}).catchError((_) {}),
    ]);
  }

  @override
  Future<void> dispose() async {
    _disposed = true;
    await stop();
  }
}

/// Allows a recording to be submitted immediately rather than cancelled.
abstract interface class FinishingCardConversationVoice {
  Future<void> finishListening();
}
