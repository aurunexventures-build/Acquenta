import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:contact_card_builder/main.dart';
import 'package:contact_card_builder/services/storage_service.dart';
import 'package:contact_card_builder/screens/card_detail_screen.dart';
import 'package:contact_card_builder/screens/connection_detail_screen.dart';

void main() {
  testWidgets(
    'compact wallet actions and repeated rotation retain the selected tab',
    (tester) async {
      SharedPreferences.setMockInitialValues({});
      final storage = await StorageService.init();
      await storage.setOnboardingCompleted(true);
      await storage.addDemoIdentityCardsOnce();
      await storage.addDemoConnectionsOnce();
      tester.view.devicePixelRatio = 1;
      tester.view.physicalSize = const Size(390, 844);
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      await tester.pumpWidget(
        ContactCardBuilderApp(storageService: storage, requireSignIn: false),
      );
      await tester.pumpAndSettle();
      expect(find.byTooltip('Account & privacy'), findsNothing);
      expect(find.byTooltip('Follow-ups'), findsNothing);
      expect(find.byTooltip('Event'), findsOneWidget);
      expect(find.byIcon(Icons.event_outlined), findsOneWidget);
      expect(find.text('Create a card'), findsNothing);
      expect(find.text('One you.\nMany possibilities.'), findsNothing);
      expect(tester.getRect(find.text('My cards')).top, lessThan(170));
      expect(
        tester.getRect(find.byTooltip('Create a card')).left,
        greaterThan(250),
      );
      expect(
        tester.getRect(find.byTooltip('Receive a card')).top,
        lessThan(300),
      );

      for (final tab in [0, 1]) {
        await tester.tap(find.byType(NavigationDestination).at(tab));
        await tester.pumpAndSettle();
        // Exercise an existing scroll offset as the viewport changes shape.
        await tester.drag(
          find.byType(SingleChildScrollView).first,
          const Offset(0, -350),
        );
        await tester.pumpAndSettle();
        for (final size in [
          const Size(844, 390),
          const Size(390, 844),
          const Size(1100, 430),
          const Size(320, 568),
          const Size(1440, 900),
          const Size(390, 844),
        ]) {
          tester.view.physicalSize = size;
          await tester.pumpAndSettle();
          expect(tester.takeException(), isNull, reason: 'tab $tab at $size');
          final nav = find.byType(NavigationBar);
          if (nav.evaluate().isNotEmpty) {
            expect(tester.widget<NavigationBar>(nav).selectedIndex, tab);
          }
          expect(find.byTooltip('Receive a card'), findsOneWidget);
        }
      }
      final cards = await storage.loadCards();
      final people = await storage.loadConnections();
      final navigator = tester.state<NavigatorState>(
        find.byType(Navigator).first,
      );
      for (final screen in <Widget>[
        CardDetailScreen(cardId: cards.first.id),
        ConnectionDetailScreen(connectionId: people.first.id),
      ]) {
        navigator.push(MaterialPageRoute<void>(builder: (_) => screen));
        await tester.pumpAndSettle();
        expect(
          tester.takeException(),
          isNull,
          reason: '${screen.runtimeType} on open',
        );
        for (final size in [
          const Size(844, 390),
          const Size(320, 568),
          const Size(390, 844),
        ]) {
          tester.view.physicalSize = size;
          await tester.pumpAndSettle();
          expect(
            tester.takeException(),
            isNull,
            reason: '${screen.runtimeType} at $size',
          );
        }
        navigator.pop();
        await tester.pumpAndSettle();
      }
      await tester.tap(find.byTooltip('Your account'));
      await tester.pumpAndSettle();
      expect(find.text('Notifications & follow-ups'), findsOneWidget);
      expect(find.text('Sync, account & privacy'), findsOneWidget);
      await tester.tap(find.text('Notifications & follow-ups'));
      await tester.pumpAndSettle();
      expect(find.text('Follow-ups'), findsOneWidget);
      expect(tester.takeException(), isNull);
    },
  );
}
