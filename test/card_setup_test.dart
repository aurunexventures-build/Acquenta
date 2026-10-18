import 'package:flutter/material.dart';
import 'package:contact_card_builder/widgets/card_text_field.dart';
import 'package:contact_card_builder/models/contact_card.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:contact_card_builder/screens/onboarding_card_builder_screen.dart';
import 'package:contact_card_builder/services/storage_service.dart';
import 'package:contact_card_builder/widgets/interactive_card_view.dart';

void main() {
  testWidgets(
    'identity is required, skills are profession neutral and preview is last',
    (tester) async {
      SharedPreferences.setMockInitialValues({});
      final storage = await StorageService.init();
      tester.view.physicalSize = const Size(360, 780);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      await tester.pumpWidget(
        MaterialApp(home: OnboardingCardBuilderScreen(storageService: storage)),
      );
      expect(find.byType(InteractiveCardView), findsNothing);
      final voiceFields = tester
          .widgetList<CardTextField>(find.byType(CardTextField))
          .where((f) => f.voiceEnabled)
          .toList();
      expect(voiceFields.map((f) => f.label), ['One-line Pitch / Headline *']);
      await tester.tap(find.text('Next'));
      await tester.pumpAndSettle();
      expect(find.text('This field is required.'), findsNWidgets(4));
      await tester.ensureVisible(
        find.byType(DropdownButtonFormField<CardCategory>),
      );
      await tester.tap(find.byType(DropdownButtonFormField<CardCategory>));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Professional').last);
      await tester.pumpAndSettle();
      final fields = find.byType(TextFormField);
      for (final entry in {
        0: 'Work',
        1: 'Sam',
        2: 'Florist',
        3: 'Flowers for special occasions',
      }.entries) {
        await tester.ensureVisible(fields.at(entry.key));
        await tester.enterText(fields.at(entry.key), entry.value);
      }
      FocusManager.instance.primaryFocus?.unfocus();
      await tester.tap(find.text('Next'));
      await tester.pumpAndSettle();
      expect(find.text('2. SKILLS & TAGS'), findsOneWidget);
      expect(find.text('Flutter'), findsNothing);
      await tester.ensureVisible(
        find.byKey(const ValueKey('manual-skill-tags')),
      );
      await tester.enterText(
        find.byKey(const ValueKey('manual-skill-tags')),
        'Floral design',
      );
      await tester.tap(find.widgetWithText(OutlinedButton, 'Add tags'));
      await tester.pumpAndSettle();
      expect(find.widgetWithText(InputChip, 'Floral design'), findsOneWidget);
      await tester.tap(find.text('Next'));
      await tester.pumpAndSettle();
      expect(find.byType(InteractiveCardView), findsNothing);
      await tester.tap(find.text('Next'));
      await tester.pumpAndSettle();
      expect(find.byType(InteractiveCardView), findsOneWidget);
      expect(find.text('Save card'), findsOneWidget);
      expect(tester.takeException(), isNull);
    },
  );
}
