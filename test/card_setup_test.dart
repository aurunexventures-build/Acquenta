import 'package:contact_card_builder/main.dart';
import 'package:contact_card_builder/models/account_profile.dart';
import 'package:contact_card_builder/screens/profile_questionnaire.dart';
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
    'confirmed conversation creates the card and leaves account defaults intact',
    (tester) async {
      SharedPreferences.setMockInitialValues({});
      final storage = await StorageService.init();
      await storage.saveAccountProfile(
        AccountProfile(
          firstName: 'Sam',
          role: 'Florist',
          company: 'Zorro Expenses',
          intro: 'I create flowers.',
          updatedAt: DateTime(2026),
        ),
        dirty: false,
      );
      await tester.pumpWidget(
        ContactCardBuilderApp(storageService: storage, requireSignIn: false),
      );
      await tester.pumpAndSettle();
      await tester.tap(find.byTooltip('Talk to Acquenta · create this card'));
      await tester.pumpAndSettle();
      expect(
        tester
            .widget<ProfileQuestionnaire>(find.byType(ProfileQuestionnaire))
            .profileName,
        'Sam',
      );
      // The conversation tests verify this exact result is emitted only after Create card.
      Navigator.pop(tester.element(find.byType(ProfileQuestionnaire)), {
        'cardName': 'Wedding work',
        'category': 'professional',
        'fullName': 'Sam Flowers',
        'role': 'Wedding florist',
        'company': 'Forest Mazars',
        'pitch': 'Wedding flowers made with care.',
        'skills': ['Floral design'],
        'bio': 'I create bespoke floral arrangements for wedding celebrations.',
        'createCard': true,
      });
      await tester.pumpAndSettle();
      final cards = await storage.loadCards();
      expect(cards, hasLength(1));
      expect(cards.single.fullName, 'Sam Flowers');
      expect(cards.single.company, 'Forest Mazars');
      expect(storage.loadAccountProfile()!.company, 'Zorro Expenses');
      expect(cards.single.headline, 'Wedding flowers made with care.');
      expect(
        cards.single.bio,
        'I create bespoke floral arrangements for wedding celebrations.',
      );
      expect(storage.hasCompletedOnboarding, isTrue);
      expect(storage.loadAccountProfile()!.firstName, 'Sam');
      expect(storage.loadAccountProfile()!.role, 'Florist');
      expect(find.byType(OnboardingCardBuilderScreen), findsNothing);
      expect(tester.takeException(), isNull);
    },
  );

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
      expect(find.text('This field is required.'), findsNWidgets(3));
      expect(
        find.byType(DropdownButtonFormField<CardCategory>),
        findsOneWidget,
      );
      expect(
        tester
            .getTopLeft(find.byType(DropdownButtonFormField<CardCategory>))
            .dy,
        greaterThan(
          tester.getTopLeft(find.text('Company and photo (optional)')).dy,
        ),
      );
      expect(find.text('Card name *'), findsNothing);
      final fields = find.byType(TextFormField);
      for (final entry in {
        0: 'Sam',
        1: 'Florist',
        2: 'Flowers for special occasions',
      }.entries) {
        await tester.ensureVisible(fields.at(entry.key));
        await tester.enterText(fields.at(entry.key), entry.value);
      }
      await tester.enterText(fields.at(2), List.filled(121, 'a').join());
      FocusManager.instance.primaryFocus?.unfocus();
      await tester.tap(find.text('Next'));
      await tester.pumpAndSettle();
      expect(find.text('Use up to 120 characters.'), findsOneWidget);
      await tester.enterText(fields.at(2), 'Flowers for special occasions');
      FocusManager.instance.primaryFocus?.unfocus();
      await tester.tap(find.text('Next'));
      await tester.pumpAndSettle();
      expect(find.text('2. SKILLS & TAGS'), findsOneWidget);
      expect(find.text('Flutter'), findsNothing);
      expect(find.byKey(const ValueKey('manual-skill-tags')), findsNothing);
      await tester.ensureVisible(find.text('Add tags'));
      await tester.tap(find.text('Add tags'));
      await tester.pumpAndSettle();
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
      expect(find.byKey(const ValueKey('manual-skill-tags')), findsNothing);
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
