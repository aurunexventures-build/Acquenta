import 'dart:convert';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:contact_card_builder/screens/delete_account_screen.dart';
import 'package:contact_card_builder/services/auth_service.dart';
import 'package:contact_card_builder/services/storage_service.dart';
import 'package:contact_card_builder/services/sync_service.dart';
import 'package:contact_card_builder/providers/cards_provider.dart';
import 'package:contact_card_builder/providers/connections_provider.dart';

class DeleteUser extends Fake implements User {
  @override
  String get uid => 'alice';
  @override
  String get email => 'alice@example.com';
}

class DeleteAuth extends AuthService {
  bool signedIn = true;
  String? password;
  @override
  User? get currentUser => signedIn ? DeleteUser() : null;
  @override
  bool get usesPassword => true;
  @override
  Future<String?> getIdToken() async => 'fresh-token';
  @override
  Future<bool> reauthenticateForDeletion(String value) async {
    password = value;
    return true;
  }

  @override
  Future<void> signOut() async {
    signedIn = false;
    notifyListeners();
  }
}

void main() {
  setUp(() => SharedPreferences.setMockInitialValues({}));
  test(
    'local deletion removes account wallet, photos and alerts while preserving another account',
    () async {
      final storage = await StorageService.init();
      final prefs = await SharedPreferences.getInstance();
      for (final key in [
        'alice_user_contact_cards',
        'alice_saved_connections',
        'alice_wallet_deletions',
        'alice_has_completed_onboarding',
        'alice:photo-cache:one',
        'alice:photo-upload:one',
        'metcue_notifications_alice',
        'bob_saved_connections',
      ]) {
        await prefs.setString(key, 'data');
      }
      await storage.deleteAccountData('alice');
      expect(prefs.getKeys(), {'bob_saved_connections'});
    },
  );
  for (final success in [true, false]) {
    testWidgets(
      'deletion confirmation and server ${success ? 'success' : 'failure'} keep data consistent',
      (tester) async {
        final storage = await StorageService.init();
        await storage.activateAccount('alice');
        await storage.setOnboardingCompleted(true);
        final auth = DeleteAuth();
        final cards = CardsProvider(storage);
        final people = ConnectionsProvider(storage);
        int calls = 0;
        final api = SyncService(
          client: MockClient((request) async {
            calls++;
            expect(request.method, 'DELETE');
            expect(request.url.path, '/api/v1/account');
            expect(jsonDecode(request.body), {'confirmation': 'DELETE'});
            return http.Response(
              success ? '{"success":true}' : '{"error":"Please retry"}',
              success ? 200 : 503,
            );
          }),
        );
        addTearDown(auth.dispose);
        addTearDown(cards.dispose);
        addTearDown(people.dispose);
        await tester.pumpWidget(
          MultiProvider(
            providers: [
              ChangeNotifierProvider<AuthService>.value(value: auth),
              ChangeNotifierProvider.value(value: cards),
              ChangeNotifierProvider.value(value: people),
            ],
            child: MaterialApp(home: DeleteAccountScreen(syncService: api)),
          ),
        );
        final delete = find.byWidgetPredicate(
          (widget) => widget is FilledButton,
        );
        expect(tester.widget<FilledButton>(delete).onPressed, isNull);
        expect(calls, 0);
        await tester.enterText(find.byType(TextField), 'password');
        await tester.ensureVisible(find.byType(CheckboxListTile));
        await tester.tap(find.byType(CheckboxListTile));
        await tester.pumpAndSettle();
        await tester.ensureVisible(delete);
        await tester.tap(delete);
        await tester.pumpAndSettle();
        expect(calls, 1);
        expect(auth.password, 'password');
        expect(auth.signedIn, !success);
        expect(storage.hasCompletedOnboarding, !success);
        if (!success) {
          expect(
            find.textContaining('Deletion could not finish'),
            findsOneWidget,
          );
        }
        expect(tester.takeException(), isNull);
      },
    );
  }
  test(
    'deleted account response is distinct from a transient sync failure',
    () async {
      final service = SyncService(
        client: MockClient(
          (_) async => http.Response('{"error":"Deleted"}', 410),
        ),
      );
      final result = await service.sync(
        connections: [],
        cards: [],
        deleted: [],
        auth: DeleteAuth(),
      );
      expect(result.accountDeleted, isTrue);
      expect(result.success, isFalse);
      service.close();
    },
  );
}
