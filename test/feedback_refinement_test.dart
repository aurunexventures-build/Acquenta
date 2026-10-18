import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:contact_card_builder/main.dart';
import 'package:contact_card_builder/models/contact_card.dart';
import 'package:contact_card_builder/providers/cards_provider.dart';
import 'package:contact_card_builder/providers/connections_provider.dart';
import 'package:contact_card_builder/screens/card_detail_screen.dart';
import 'package:contact_card_builder/screens/smart_search_screen.dart';
import 'package:contact_card_builder/services/auth_service.dart';
import 'package:contact_card_builder/services/storage_service.dart';
import 'package:contact_card_builder/services/sync_service.dart';

class _User extends Fake implements User {
  @override
  String get uid => 'test';
}

class _Auth extends AuthService {
  @override
  User? get currentUser => _User();
}

class _Organise extends SyncService {
  @override
  Future<Map<String, dynamic>> request(
    String path,
    Map<String, dynamic> body,
    AuthService auth, {
    String method = 'POST',
  }) async => {'text': 'developer'};
}

void main() {
  setUp(() => SharedPreferences.setMockInitialValues({}));
  testWidgets(
    'returning from recall shows the retained wallet on the first frame',
    (tester) async {
      final storage = await StorageService.init();
      await storage.setOnboardingCompleted(true);
      await storage.addDemoIdentityCardsOnce();
      tester.view.physicalSize = const Size(390, 844);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      await tester.pumpWidget(
        ContactCardBuilderApp(storageService: storage, requireSignIn: false),
      );
      await tester.pumpAndSettle();
      final wallet = tester.element(
        find.byKey(const PageStorageKey('wallet-tab-0')),
      );
      await tester.tap(find.byType(NavigationDestination).at(2));
      await tester.pumpAndSettle();
      await tester.enterText(find.byType(TextField), 'developer');
      await tester.pumpAndSettle();
      await tester.tap(find.byType(NavigationDestination).at(0));
      await tester.pump();
      expect(find.text('My cards'), findsOneWidget);
      expect(
        tester.element(find.byKey(const PageStorageKey('wallet-tab-0'))),
        same(wallet),
      );
      expect(tester.takeException(), isNull);
      await tester.pumpAndSettle();
    },
  );
  testWidgets(
    'sixth existing card is visibly locked, cannot open and its message disappears',
    (tester) async {
      final storage = await StorageService.init();
      await storage.setOnboardingCompleted(true);
      await storage.saveCards(
        List.generate(
          6,
          (i) => ContactCard(
            id: 'card-$i',
            title: 'Card $i',
            fullName: 'Person $i',
            createdAt: DateTime(2026),
            updatedAt: DateTime(2026),
          ),
        ),
      );
      tester.view.physicalSize = const Size(390, 844);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      await tester.pumpWidget(
        ContactCardBuilderApp(storageService: storage, requireSignIn: false),
      );
      await tester.pumpAndSettle();
      expect(
        find.text('5/5 active cards · Free plan · 1 locked'),
        findsOneWidget,
      );
      final locked = find.byKey(const ValueKey('wallet-card-card-5'));
      await tester.ensureVisible(locked);
      await tester.tap(find.text('Person 5'));
      await tester.pumpAndSettle();
      expect(find.byType(CardDetailScreen), findsNothing);
      expect(find.byType(SnackBar), findsOneWidget);
      await tester.pump(const Duration(seconds: 4));
      await tester.pumpAndSettle();
      expect(find.byType(SnackBar), findsNothing);
      expect((await storage.loadCards()).length, 6);
      final cards = tester.element(locked).read<CardsProvider>();
      expect(cards.isCardLocked('card-5'), isTrue);
      await cards.deleteCard('card-0');
      expect(cards.isCardLocked('card-5'), isFalse);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets('AI tidy feedback expires even when Undo is available', (
    tester,
  ) async {
    final storage = await StorageService.init();
    final people = ConnectionsProvider(storage);
    await people.loadConnections();
    final auth = _Auth();
    addTearDown(people.dispose);
    addTearDown(auth.dispose);
    tester.view.physicalSize = const Size(320, 700);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await tester.pumpWidget(
      MultiProvider(
        providers: [
          ChangeNotifierProvider.value(value: people),
          ChangeNotifierProvider<AuthService>.value(value: auth),
        ],
        child: MaterialApp(
          home: SmartSearchScreen(serviceFactory: () => _Organise()),
        ),
      ),
    );
    await tester.enterText(find.byType(TextField), 'I met a developer');
    await tester.pumpAndSettle();
    final controls = find.byKey(const ValueKey('recall-controls-row'));
    expect(controls, findsOneWidget);
    expect(
      tester.getCenter(find.text('Speak')).dy,
      closeTo(tester.getCenter(find.text('AI tidy')).dy, 1),
    );
    expect(
      tester.getCenter(find.text('Matches')).dy,
      closeTo(tester.getCenter(find.text('AI tidy')).dy, 1),
    );
    await tester.tap(find.text('AI tidy'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));
    expect(find.text('Search wording tidied.'), findsOneWidget);
    expect(tester.widget<SnackBar>(find.byType(SnackBar)).persist, isFalse);
    await tester.pump(const Duration(seconds: 4));
    await tester.pumpAndSettle();
    expect(find.text('Search wording tidied.'), findsNothing);
    expect(tester.takeException(), isNull);
  });
}
