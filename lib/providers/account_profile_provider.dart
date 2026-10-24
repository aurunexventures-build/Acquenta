import 'dart:async';
import '../services/text_safety.dart';
import 'package:flutter/material.dart';
import '../models/account_profile.dart';
import '../services/auth_service.dart';
import '../services/storage_service.dart';
import '../services/sync_service.dart';

class AccountProfileProvider extends ChangeNotifier {
  final StorageService storage;
  final SyncService _service;
  AccountProfile? _profile;
  Future<void> Function(AccountProfile)? onValidateText;
  AuthService? _auth;
  bool _syncing = false, _again = false, _disposed = false;
  String? status;
  AccountProfileProvider(this.storage, {SyncService? service})
    : _service = service ?? SyncService() {
    _profile = storage.loadAccountProfile();
  }
  AccountProfile? get profile => _profile;
  void clearForAccountSwitch() {
    _profile = null;
    status = null;
    notifyListeners();
  }

  Future<void> load(AuthService auth) async {
    _auth = auth;
    _profile = storage.loadAccountProfile();
    status = null;
    notifyListeners();
    await sync();
  }

  Future<void> save(AccountProfile value) async {
    value.validate();
    TextSafety.validateFields(value.toJson());
    final scope = storage.scope;
    await onValidateText?.call(value);
    if (scope != storage.scope) throw StateError('Account changed.');
    final updated = AccountProfile.fromJson({
      ...value.toJson(),
      'updatedAt': storage
          .nextVersion(_profile?.updatedAt)
          .toUtc()
          .toIso8601String(),
    });
    await storage.saveAccountProfile(updated, dirty: true);
    if (_disposed || scope != storage.scope) return;
    _profile = updated;
    status = 'Saved on this device.';
    notifyListeners();
    unawaited(sync());
  }

  Future<void> sync() async {
    final auth = _auth;
    if (auth == null || !auth.isAuthenticated || _disposed) return;
    if (_syncing) {
      _again = true;
      return;
    }
    _syncing = true;
    try {
      do {
        _again = false;
        final scope = storage.scope, uid = auth.currentUser?.uid;
        bool current() =>
            !_disposed &&
            scope == storage.scope &&
            uid == auth.currentUser?.uid;
        final remote = await _service.request(
          '/api/v1/profile',
          {},
          auth,
          method: 'GET',
        );
        if (!current()) return;
        if (remote['profile'] is Map) {
          final cloud = AccountProfile.fromJson(
            Map<String, dynamic>.from(remote['profile']),
          );
          if (_profile == null ||
              cloud.updatedAt.isAfter(_profile!.updatedAt)) {
            await storage.saveAccountProfile(cloud, dirty: false);
            if (!current()) return;
            _profile = cloud;
          }
        }
        final local = _profile;
        if (local != null && storage.profileNeedsSync) {
          final result = await _service.request('/api/v1/profile', {
            'profile': local.toJson(),
          }, auth);
          if (!current()) return;
          final saved = AccountProfile.fromJson(
            Map<String, dynamic>.from(result['profile']),
          );
          if (_profile?.updatedAt == local.updatedAt) {
            await storage.saveAccountProfile(saved, dirty: false);
            if (!current()) return;
            _profile = saved;
          } else {
            _again = true;
          }
        }
        if (current()) {
          status = 'Profile synced.';
          notifyListeners();
        }
      } while (_again && !_disposed);
    } catch (_) {
      if (!_disposed) {
        status = 'Saved locally. Profile sync will retry when online.';
        notifyListeners();
      }
    } finally {
      _syncing = false;
      // An account switch may have queued a new sync while the old request ended.
      if (_again && !_disposed) {
        _again = false;
        unawaited(sync());
      }
    }
  }

  @override
  void dispose() {
    _disposed = true;
    _service.close();
    super.dispose();
  }
}
