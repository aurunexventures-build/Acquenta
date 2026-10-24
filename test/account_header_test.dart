import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:contact_card_builder/providers/cards_provider.dart';
import 'package:contact_card_builder/providers/connections_provider.dart';
import 'package:contact_card_builder/providers/account_profile_provider.dart';
import 'package:contact_card_builder/services/auth_service.dart';
import 'package:contact_card_builder/services/storage_service.dart';
import 'package:contact_card_builder/screens/home_screen.dart';
import 'package:contact_card_builder/widgets/account_avatar.dart';

class HeaderInfo extends Fake implements UserInfo {
  @override
  String? get photoURL => 'https://example.com/provider-photo.png';
}

class HeaderUser extends Fake implements User {
  final String id, photo;
  HeaderUser(this.id, this.photo);
  @override
  String get uid => id;
  @override
  String? get displayName => 'Sam Patel';
  @override
  String? get photoURL => photo;
  @override
  List<UserInfo> get providerData => [HeaderInfo()];
}

class HeaderAuth extends AuthService {
  User? user = HeaderUser('sam', 'https://example.com/sam.png');
  @override
  User? get currentUser => user;
}

void main() {
  test(
    'account photo prefers current account and falls back to linked-provider metadata',
    () {
      final auth = HeaderAuth();
      expect(auth.accountPhotoUrl, 'https://example.com/sam.png');
      auth.user = HeaderUser('sam', '');
      expect(auth.accountPhotoUrl, 'https://example.com/provider-photo.png');
      auth.user = null;
      expect(auth.accountPhotoUrl, isEmpty);
      auth.dispose();
    },
  );
  testWidgets(
    'header stays right aligned and the avatar updates on account changes',
    (tester) async {
      SharedPreferences.setMockInitialValues({});
      final storage = await StorageService.init();
      final auth = HeaderAuth();
      final cards = CardsProvider(storage);
      final people = ConnectionsProvider(storage);
      final profile = AccountProfileProvider(storage);
      await tester.pumpWidget(
        MultiProvider(
          providers: [
            ChangeNotifierProvider<AuthService>.value(value: auth),
            ChangeNotifierProvider<CardsProvider>.value(value: cards),
            ChangeNotifierProvider<ConnectionsProvider>.value(value: people),
            ChangeNotifierProvider<AccountProfileProvider>.value(
              value: profile,
            ),
          ],
          child: const MaterialApp(home: HomeScreen()),
        ),
      );
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetDevicePixelRatio);
      addTearDown(tester.view.resetPhysicalSize);
      for (final width in [320.0, 390.0, 1280.0]) {
        tester.view.physicalSize = Size(width, 900);
        await tester.pumpAndSettle();
        final actions = tester.getRect(
          find.byKey(const ValueKey('header-account-actions')),
        );
        expect(actions.right, closeTo(width - (width >= 1000 ? 36 : 20), .1));
        final calendar = tester.getRect(find.byTooltip('Event'));
        final account = tester.getRect(find.byTooltip('Your account'));
        expect(calendar.center.dy, closeTo(account.center.dy, .1));
        expect(account.center.dx - calendar.center.dx, lessThanOrEqualTo(64));
        expect(tester.takeException(), isNull);
      }
      expect(
        tester.widget<AccountAvatar>(find.byType(AccountAvatar)).photoUrl,
        'https://example.com/sam.png',
      );
      auth.user = HeaderUser('other', 'https://example.com/other.png');
      auth.notifyListeners();
      await tester.pumpAndSettle();
      expect(
        tester.widget<AccountAvatar>(find.byType(AccountAvatar)).photoUrl,
        'https://example.com/other.png',
      );
      auth.user = null;
      auth.notifyListeners();
      await tester.pumpAndSettle();
      expect(
        tester.widget<AccountAvatar>(find.byType(AccountAvatar)).photoUrl,
        isEmpty,
      );
      expect(tester.takeException(), isNull);
    },
  );
}
