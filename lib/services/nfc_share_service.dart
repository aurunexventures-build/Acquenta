import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

/// Android foreground HCE contact sharing. No online link or persistent card copy.
class NfcShareService {
  static const _channel = MethodChannel('metcue/nfc');
  static bool get supportedPlatform =>
      !kIsWeb && defaultTargetPlatform == TargetPlatform.android;
  Future<String> availability() async {
    if (!supportedPlatform) return 'unsupported';
    try {
      return await _channel.invokeMethod<String>('availability') ??
          'unsupported';
    } catch (_) {
      return 'unsupported';
    }
  }

  Future<String?> receive() async {
    if (!supportedPlatform) return null;
    final available = await _channel.invokeMethod<String>('readerAvailability');
    if (available != 'available') return null;
    return await _channel.invokeMethod<String>('receive');
  }

  Future<void> stopReceiving() async {
    if (supportedPlatform) {
      try {
        await _channel.invokeMethod<void>('stopReceive');
      } catch (_) {}
    }
  }

  Future<void> start(String vcard) async {
    await _channel.invokeMethod<void>('start', {'vcard': vcard});
  }

  Future<void> stop() async {
    if (supportedPlatform) {
      try {
        await _channel.invokeMethod<void>('stop');
      } catch (_) {}
    }
  }
}
