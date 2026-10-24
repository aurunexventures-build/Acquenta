import 'dart:async';
import 'package:flutter/widgets.dart';
import 'package:wakelock_plus/wakelock_plus.dart';

/// Keep only an open foreground conversation awake; restore normal auto-lock on exit.
class ConversationScreenAwake with WidgetsBindingObserver {
  final Future<void> Function(bool) setEnabled;
  ConversationScreenAwake({Future<void> Function(bool)? setEnabled})
    : setEnabled =
          setEnabled ?? ((enabled) => WakelockPlus.toggle(enable: enabled));
  Future<void> _pending = Future.value();
  bool _open = false;
  void _toggle(bool enabled) {
    _pending = _pending
        .then((_) => setEnabled(enabled))
        .catchError((Object _) {});
  }

  void open() {
    _open = true;
    WidgetsBinding.instance.addObserver(this);
    _toggle(true);
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (!_open) return;
    if (state == AppLifecycleState.resumed) _toggle(true);
    if ([
      AppLifecycleState.paused,
      AppLifecycleState.hidden,
      AppLifecycleState.detached,
    ].contains(state)) {
      _toggle(false);
    }
  }

  void close() {
    _open = false;
    WidgetsBinding.instance.removeObserver(this);
    _toggle(false);
  }

  Future<void> get settled => _pending;
}
