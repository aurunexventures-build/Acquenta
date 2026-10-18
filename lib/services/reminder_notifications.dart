import 'package:flutter/foundation.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:timezone/data/latest.dart' as tzdata;
import 'package:timezone/timezone.dart' as tz;
import '../models/saved_connection.dart';

abstract class ReminderNotificationBackend {
  bool get supported;
  Future<bool> requestPermission();
  Future<void> cancelAll();
  Future<void> schedule(int id, DateTime at);
}

class NativeReminderBackend implements ReminderNotificationBackend {
  final _plugin = FlutterLocalNotificationsPlugin();
  bool _ready = false;
  @override
  bool get supported =>
      !kIsWeb &&
      [
        TargetPlatform.android,
        TargetPlatform.iOS,
      ].contains(defaultTargetPlatform);
  Future<void> _init() async {
    if (_ready) return;
    tzdata.initializeTimeZones();
    await _plugin.initialize(
      const InitializationSettings(
        android: AndroidInitializationSettings('ic_notification'),
        iOS: DarwinInitializationSettings(
          requestAlertPermission: false,
          requestBadgePermission: false,
          requestSoundPermission: false,
        ),
      ),
    );
    _ready = true;
  }

  @override
  Future<bool> requestPermission() async {
    await _init();
    if (defaultTargetPlatform == TargetPlatform.android) {
      return await _plugin
              .resolvePlatformSpecificImplementation<
                AndroidFlutterLocalNotificationsPlugin
              >()
              ?.requestNotificationsPermission() ??
          false;
    }
    return await _plugin
            .resolvePlatformSpecificImplementation<
              IOSFlutterLocalNotificationsPlugin
            >()
            ?.requestPermissions(alert: true, badge: false, sound: true) ??
        false;
  }

  @override
  Future<void> cancelAll() async {
    await _init();
    await _plugin.cancelAll();
  }

  @override
  Future<void> schedule(int id, DateTime at) async {
    await _init();
    await _plugin.zonedSchedule(
      id,
      'Acquenta follow-up',
      'Open Acquenta to review your reminder.',
      tz.TZDateTime.from(at, tz.UTC),
      const NotificationDetails(
        android: AndroidNotificationDetails(
          'metcue_followups',
          'Follow-up reminders',
          channelDescription: 'Private reminders to reconnect',
          importance: Importance.defaultImportance,
          priority: Priority.defaultPriority,
          visibility: NotificationVisibility.private,
        ),
        iOS: DarwinNotificationDetails(presentAlert: true, presentSound: true),
      ),
      androidScheduleMode: AndroidScheduleMode.inexactAllowWhileIdle,
    );
  }
}

class ReminderNotifications {
  final ReminderNotificationBackend backend;
  ReminderNotifications({ReminderNotificationBackend? backend})
    : backend = backend ?? NativeReminderBackend();
  String _scope = 'guest';
  Future<void> _queue = Future.value();
  int _generation = 0;
  bool enabled = false;
  String status = '';
  bool get supported => backend.supported;
  static List<SavedConnection> eligible(
    List<SavedConnection> records,
    DateTime now,
  ) =>
      (records
              .where(
                (c) =>
                    c.followUpAt != null &&
                    !c.followUpCompleted &&
                    c.followUpAt!.isAfter(now),
              )
              .toList()
            ..sort((a, b) => a.followUpAt!.compareTo(b.followUpAt!)))
          .take(60)
          .toList();
  Future<void> refresh(String scope, List<SavedConnection> records) {
    _scope = scope;
    final generation = ++_generation;
    final snapshot = List<SavedConnection>.of(records);
    final result = _queue.then((_) async {
      if (generation != _generation || !supported) return;
      try {
        final prefs = await SharedPreferences.getInstance();
        if (generation != _generation) return;
        enabled = prefs.getBool('metcue_notifications_$scope') ?? false;
        await backend.cancelAll();
        if (generation != _generation) return;
        if (!enabled) {
          status = 'Device alerts are off.';
          return;
        }
        final pending = eligible(snapshot, DateTime.now());
        for (var i = 0; i < pending.length; i++) {
          if (generation != _generation) return;
          await backend.schedule(i + 1, pending[i].followUpAt!);
        }
        status =
            'Device alerts enabled for the next ${pending.length} reminders. Timing depends on device settings.';
      } catch (_) {
        status =
            'Device alerts unavailable. In-app reminders and calendar export still work.';
      }
    });
    _queue = result.catchError((_) {});
    return result;
  }

  Future<bool> setEnabled(
    bool value,
    String scope,
    List<SavedConnection> records,
  ) async {
    if (!supported) {
      status = 'Use calendar export for alerts on this device.';
      return false;
    }
    _scope = scope;
    final generation = ++_generation;
    try {
      if (value && !await backend.requestPermission()) {
        if (generation == _generation) {
          status =
              'Notifications were not allowed. You can enable them in device settings.';
        }
        return false;
      }
      if (generation != _generation || _scope != scope) return false;
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool('metcue_notifications_$scope', value);
      if (generation != _generation) return false;
      enabled = value;
      await refresh(scope, records);
      return true;
    } catch (_) {
      status = 'Could not enable device alerts. Use calendar export instead.';
      return false;
    }
  }
}
