import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

abstract interface class NearbyCardTransport {
  Stream<Map<String, dynamic>> get events;
  Future<bool> available();
  Future<String> start(bool sending);
  Future<void> invite(String id);
  Future<void> accept(bool accept);
  Future<void> confirm();
  Future<void> send(String card);
  Future<void> saved();
  Future<void> decline();
  Future<void> stop();
  Future<void> dispose();
}

class NearbyCardService implements NearbyCardTransport {
  static bool get supported =>
      !kIsWeb && defaultTargetPlatform == TargetPlatform.iOS;
  final MethodChannel _channel;
  final _events = StreamController<Map<String, dynamic>>.broadcast();
  bool _disposed = false;
  NearbyCardService({MethodChannel? channel})
    : _channel = channel ?? const MethodChannel('acquenta/nearby') {
    if (supported) {
      _channel.setMethodCallHandler((call) async {
        if (!_disposed && call.method == 'event' && call.arguments is Map) {
          _events.add(Map<String, dynamic>.from(call.arguments as Map));
        }
      });
    }
  }
  @override
  Stream<Map<String, dynamic>> get events => _events.stream;
  @override
  Future<bool> available() async {
    if (!supported) return false;
    try {
      return await _channel.invokeMethod<bool>('available') ?? false;
    } catch (_) {
      return false;
    }
  }

  @override
  Future<String> start(bool sending) async =>
      await _channel.invokeMethod<String>('start', {
        'mode': sending ? 'send' : 'receive',
      }) ??
      'This iPhone';
  @override
  Future<void> invite(String id) => _channel.invokeMethod('invite', {'id': id});
  @override
  Future<void> accept(bool accept) =>
      _channel.invokeMethod('accept', {'accept': accept});
  @override
  Future<void> confirm() => _channel.invokeMethod('confirm');
  @override
  Future<void> send(String card) =>
      _channel.invokeMethod('send', {'card': card});
  @override
  Future<void> saved() => _channel.invokeMethod('saved');
  @override
  Future<void> decline() => _channel.invokeMethod('decline');
  @override
  Future<void> stop() async {
    if (supported) {
      try {
        await _channel.invokeMethod('stop');
      } catch (_) {}
    }
  }

  @override
  Future<void> dispose() async {
    if (_disposed) return;
    await stop();
    _disposed = true;
    if (supported) _channel.setMethodCallHandler(null);
    await _events.close();
  }
}
