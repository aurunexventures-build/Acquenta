import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:contact_card_builder/main.dart';
import 'package:contact_card_builder/models/contact_card.dart';
import 'package:contact_card_builder/services/storage_service.dart';

void main() {
  testWidgets(
    'wallet menu edits appearance without changing identity or primary status',
    (tester) async {
      tester.view.physicalSize = const Size(393, 1000);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      SharedPreferences.setMockInitialValues({});
      final storage = await StorageService.init();
      await storage.saveCards([
        ContactCard(
          id: 'styled',
          fullName: 'Sam Patel',
          role: 'Architect',
          isDefault: true,
          createdAt: DateTime(2026),
          updatedAt: DateTime(2026),
        ),
      ]);
      await storage.setOnboardingCompleted(true);
      await tester.pumpWidget(
        ContactCardBuilderApp(storageService: storage, requireSignIn: false),
      );
      await tester.pumpAndSettle();
      expect(find.text('One you.\nMany possibilities.'), findsNothing);
      await tester.tap(find.byTooltip('Card options'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Customize card'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Linen'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Evergreen'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Save appearance'));
      await tester.pumpAndSettle();
      final saved = (await storage.loadCards()).single;
      expect(saved.cardFinish, 'linen');
      expect(saved.themeColorHex, '#234B42');
      expect(saved.role, 'Architect');
      expect(saved.isDefault, isTrue);
      await tester.tap(find.text('Connections').last);
      await tester.pumpAndSettle();
      expect(find.text('BEYOND THE FIRST HELLO'), findsOneWidget);
      expect(tester.takeException(), isNull);
    },
  );
}
