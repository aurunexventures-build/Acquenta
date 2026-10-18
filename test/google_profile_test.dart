import 'dart:convert';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:contact_card_builder/models/account_profile.dart';
import 'package:contact_card_builder/providers/account_profile_provider.dart';
import 'package:contact_card_builder/screens/account_profile_screen.dart';
import 'package:contact_card_builder/services/auth_service.dart';
import 'package:contact_card_builder/services/photo_service.dart';
import 'package:contact_card_builder/services/storage_service.dart';
import 'package:contact_card_builder/widgets/card_text_field.dart';

class GoogleInfo extends Fake implements UserInfo {
  @override
  String get providerId => 'google.com';
  @override
  String? get displayName => 'Sam Patel';
  @override
  String? get email => 'sam@example.com';
  @override
  String? get phoneNumber => null;
  @override
  String? get photoURL => 'https://lh3.googleusercontent.com/photo';
}

class GoogleUser extends Fake implements User {
  @override
  String get uid => 'google-user';
  @override
  String? get displayName => 'Sam Patel';
  @override
  String? get email => 'sam@example.com';
  @override
  String? get phoneNumber => null;
  @override
  String? get photoURL => 'https://lh3.googleusercontent.com/photo';
  @override
  List<UserInfo> get providerData => [GoogleInfo()];
}

class GoogleAuth extends AuthService {
  User? user = GoogleUser();
  @override
  User? get currentUser => user;
}

Finder field(String label) => find.descendant(
  of: find.byWidgetPredicate((w) => w is CardTextField && w.label == label),
  matching: find.byType(TextFormField),
);
void main() {
  test(
    'restored Google identity has defaults and cannot leak after sign-out',
    () {
      final auth = GoogleAuth();
      expect(auth.googleProfileDefaults['firstName'], 'Sam Patel');
      expect(auth.googleProfileDefaults['email'], 'sam@example.com');
      expect(auth.googleProfileDefaults['phone'], '');
      auth.user = null;
      expect(auth.googleProfileDefaults, isEmpty);
      auth.dispose();
    },
  );
  for (final saved in [false, true]) {
    testWidgets('Google prefill respects saved profile: $saved', (
      tester,
    ) async {
      tester.view.physicalSize = const Size(900, 1600);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      SharedPreferences.setMockInitialValues({});
      final storage = await StorageService.init();
      if (saved) {
        await storage.saveAccountProfile(
          AccountProfile(
            firstName: 'Chosen',
            lastName: 'Name',
            emails: ['chosen@example.com'],
            updatedAt: DateTime(2026),
          ),
          dirty: false,
        );
      }
      final auth = GoogleAuth();
      final profile = AccountProfileProvider(storage);
      await tester.pumpWidget(
        MultiProvider(
          providers: [
            ChangeNotifierProvider<AuthService>.value(value: auth),
            ChangeNotifierProvider<AccountProfileProvider>.value(
              value: profile,
            ),
          ],
          child: const MaterialApp(home: AccountProfileScreen(setup: true)),
        ),
      );
      await tester.pumpAndSettle();
      expect(
        tester.widget<TextFormField>(field('First name *')).controller!.text,
        saved ? 'Chosen' : 'Sam Patel',
      );
      expect(
        tester
            .widget<TextFormField>(field('Last name (optional)'))
            .controller!
            .text,
        saved ? 'Name' : '',
      );
      final email = tester
          .widgetList<TextField>(find.byType(TextField))
          .firstWhere(
            (w) => w.decoration?.labelText == 'Primary contact email',
          );
      expect(
        email.controller!.text,
        saved ? 'chosen@example.com' : 'sam@example.com',
      );
      await tester.pumpWidget(const SizedBox());
      auth.dispose();
      profile.dispose();
    });
  }
  test(
    'Google portrait becomes a supported local photo; failures are optional',
    () async {
      final png = base64Decode(
        'iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAQAAAC1HAwCAAAAC0lEQVR42mP8/x8AAwMCAO+a9d8AAAAASUVORK5CYII=',
      );
      final client = MockClient(
        (request) async => http.Response.bytes(png, 200),
      );
      final photo = await PhotoService.importGooglePortrait(
        'https://lh3.googleusercontent.com/photo',
        client: client,
      );
      expect(photo, startsWith('data:image/png;base64,'));
      expect(
        await PhotoService.importGooglePortrait(
          'https://untrusted.example/photo',
          client: client,
        ),
        isNull,
      );
      expect(
        await PhotoService.importGooglePortrait(
          'https://lh3.googleusercontent.com/photo',
          client: MockClient((_) async => http.Response('missing', 404)),
        ),
        isNull,
      );
      expect(
        await PhotoService.importGooglePortrait(
          'https://lh3.googleusercontent.com/photo',
          client: MockClient((_) async => http.Response('invalid image', 200)),
        ),
        isNull,
      );
    },
  );
}
