import 'package:flutter/material.dart';
import 'package:contact_card_builder/models/account_profile.dart';
import 'package:contact_card_builder/models/contact_card.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:contact_card_builder/screens/onboarding_card_builder_screen.dart';
import 'package:contact_card_builder/services/storage_service.dart';
import 'package:contact_card_builder/widgets/interactive_card_view.dart';

void main() {
  testWidgets('small phone keeps focused setup field above keyboard', (
    tester,
  ) async {
    SharedPreferences.setMockInitialValues({});
    final storage = await StorageService.init();
    tester.view.physicalSize = const Size(360, 640);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    addTearDown(tester.view.resetViewInsets);
    await tester.pumpWidget(
      MaterialApp(home: OnboardingCardBuilderScreen(storageService: storage)),
    );
    expect(find.byType(InteractiveCardView), findsNothing);
    final name = find.byType(TextField).first;
    await tester.ensureVisible(name);
    await tester.tap(name);
    tester.view.viewInsets = const FakeViewPadding(bottom: 320);
    await tester.pumpAndSettle();
    expect(find.byType(InteractiveCardView), findsNothing);
    await tester.enterText(name, 'Mobile keyboard check');
    await tester.pumpAndSettle();
    expect(tester.getRect(name).bottom, lessThanOrEqualTo(320));
    expect(tester.takeException(), isNull);
    tester.view.resetViewInsets();
    await tester.pumpAndSettle();
    expect(find.byType(InteractiveCardView), findsNothing);
  });
  testWidgets('manual tag entry and Add stay above the phone keyboard', (
    tester,
  ) async {
    SharedPreferences.setMockInitialValues({});
    final storage = await StorageService.init();
    await storage.saveAccountProfile(
      AccountProfile(
        firstName: 'Sam',
        role: 'Designer',
        intro: 'I design products.',
        updatedAt: DateTime(2026),
      ),
      dirty: false,
    );
    tester.view.physicalSize = const Size(393, 852);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    addTearDown(tester.view.resetViewInsets);
    await tester.pumpWidget(
      MaterialApp(home: OnboardingCardBuilderScreen(storageService: storage)),
    );
    await tester.enterText(find.byType(TextFormField).first, 'Work');
    await tester.tap(find.byType(DropdownButtonFormField<CardCategory>));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Professional').last);
    await tester.pumpAndSettle();
    await tester.tap(find.text('Next'));
    await tester.pumpAndSettle();
    final manual = find.byKey(const ValueKey('manual-skill-tags'));
    await tester.ensureVisible(manual);
    await tester.enterText(
      manual,
      List.generate(11, (i) => 'Skill $i').join(', '),
    );
    await tester.tap(find.text('Add tags'));
    await tester.pumpAndSettle();
    await tester.ensureVisible(manual);
    await tester.tap(manual);
    tester.view.viewInsets = const FakeViewPadding(bottom: 340);
    await tester.pumpAndSettle();
    expect(find.text('Next'), findsNothing);
    expect(tester.getRect(manual).bottom, lessThanOrEqualTo(512));
    expect(
      tester.getRect(find.widgetWithText(OutlinedButton, 'Add tags')).bottom,
      lessThanOrEqualTo(512),
    );
    await tester.enterText(manual, 'New specialty');
    await tester.testTextInput.receiveAction(TextInputAction.done);
    await tester.pumpAndSettle();
    expect(tester.widget<TextField>(manual).focusNode!.hasFocus, isFalse);
    expect(find.text('New specialty'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}
