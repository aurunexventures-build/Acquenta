import 'dart:async';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:contact_card_builder/models/account_profile.dart';
import 'package:contact_card_builder/providers/account_profile_provider.dart';
import 'package:contact_card_builder/services/auth_service.dart';
import 'package:contact_card_builder/services/storage_service.dart';
import 'package:contact_card_builder/services/sync_service.dart';

class _User extends Fake implements User {
  final String id;
  _User(this.id);
  @override
  String get uid => id;
}

class _Auth extends AuthService {
  String uid = 'alice';
  @override
  User get currentUser => _User(uid);
  @override
  bool get isAuthenticated => true;
}

class _Sync extends SyncService {
  final remote = <String, Map<String, dynamic>>{};
  Completer<Map<String, dynamic>>? heldGet, heldPost;
  bool offline = false;
  @override
  Future<Map<String, dynamic>> request(
    String path,
    Map<String, dynamic> body,
    AuthService auth, {
    String method = 'POST',
  }) async {
    if (offline) throw StateError('offline');
    final uid = auth.currentUser!.uid;
    if (method == 'GET') {
      if (heldGet != null) {
        final held = heldGet!;
        heldGet = null;
        return held.future;
      }
      return {'profile': remote[uid]};
    }
    final value = Map<String, dynamic>.from(body['profile']);
    remote[uid] = value;
    if (heldPost != null) {
      final held = heldPost!;
      heldPost = null;
      return held.future;
    }
    return {'profile': value};
  }
}

AccountProfile _profile(String name) => AccountProfile(
  firstName: name,
  emails: const ['sam@example.com'],
  updatedAt: DateTime(2026),
);

void main() {
  test('offline profile retries and downloads to a second device', () async {
    SharedPreferences.setMockInitialValues({});
    final storage = await StorageService.init();
    await storage.activateAccount('alice');
    final auth = _Auth(), api = _Sync()..offline = true;
    final source = AccountProfileProvider(storage, service: api);
    await source.load(auth);
    await source.save(_profile('Sam'));
    await Future<void>.delayed(Duration.zero);
    expect(storage.profileNeedsSync, isTrue);
    api.offline = false;
    await source.sync();
    expect(storage.profileNeedsSync, isFalse);
    expect(api.remote['alice']!['firstName'], 'Sam');
    SharedPreferences.setMockInitialValues({});
    final second = await StorageService.init();
    await second.activateAccount('alice');
    final receiver = AccountProfileProvider(second, service: api);
    await receiver.load(auth);
    expect(receiver.profile!.firstName, 'Sam');
    expect(second.loadAccountProfile()!.primaryEmail, 'sam@example.com');
    source.dispose();
    receiver.dispose();
    auth.dispose();
  });
  test(
    'a late response from another account cannot overwrite the active profile',
    () async {
      SharedPreferences.setMockInitialValues({});
      final storage = await StorageService.init();
      await storage.activateAccount('alice');
      final auth = _Auth(), api = _Sync();
      final held = Completer<Map<String, dynamic>>();
      api.heldGet = held;
      api.remote['bob'] = _profile('Bob').toJson();
      final provider = AccountProfileProvider(storage, service: api);
      final old = provider.load(auth);
      auth.uid = 'bob';
      await storage.activateAccount('bob');
      provider.clearForAccountSwitch();
      await provider.load(auth);
      held.complete({'profile': _profile('Alice').toJson()});
      await old;
      await Future<void>.delayed(Duration.zero);
      expect(provider.profile!.firstName, 'Bob');
      expect(storage.loadAccountProfile()!.firstName, 'Bob');
      provider.dispose();
      auth.dispose();
    },
  );
  test('editing during upload keeps the newer local revision', () async {
    SharedPreferences.setMockInitialValues({});
    final storage = await StorageService.init();
    await storage.activateAccount('alice');
    final auth = _Auth(), api = _Sync();
    final provider = AccountProfileProvider(storage, service: api);
    await provider.load(auth);
    final held = Completer<Map<String, dynamic>>();
    api.heldPost = held;
    await provider.save(_profile('First'));
    await Future<void>.delayed(Duration.zero);
    final first = api.remote['alice']!;
    await provider.save(_profile('Newest'));
    held.complete({'profile': first});
    await Future<void>.delayed(Duration.zero);
    expect(provider.profile!.firstName, 'Newest');
    expect(api.remote['alice']!['firstName'], 'Newest');
    expect(storage.profileNeedsSync, isFalse);
    provider.dispose();
    auth.dispose();
  });
}
