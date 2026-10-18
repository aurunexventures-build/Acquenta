import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:contact_card_builder/main.dart';
import 'package:contact_card_builder/models/account_profile.dart';
import 'package:contact_card_builder/models/card_link.dart';
import 'package:contact_card_builder/models/contact_card.dart';
import 'package:contact_card_builder/services/storage_service.dart';
import 'package:contact_card_builder/screens/account_profile_screen.dart';
import 'package:contact_card_builder/screens/onboarding_card_builder_screen.dart';
import 'package:contact_card_builder/widgets/card_text_field.dart';

AccountProfile profile() => AccountProfile(
  firstName: 'Sam',
  lastName: 'Patel',
  phone: '+44123456789',
  emails: const ['sam@example.com', 'work@example.com'],
  role: 'Florist',
  company: 'Flowers',
  intro: 'I create wedding flowers.',
  links: const [
    CardLink(
      id: 'linkedin',
      title: 'LinkedIn',
      type: LinkType.linkedin,
      url: 'https://www.linkedin.com/in/sam-patel',
    ),
  ],
  updatedAt: DateTime(2026),
);

Finder field(String label) => find.descendant(
  of: find.byWidgetPredicate((w) => w is CardTextField && w.label == label),
  matching: find.byType(TextFormField),
);

void main() {
  test(
    'profile is account scoped, claimed once, and removed by account deletion',
    () async {
      SharedPreferences.setMockInitialValues({});
      final storage = await StorageService.init();
      await storage.saveAccountProfile(profile(), dirty: true);
      await storage.activateAccount('alice');
      expect(storage.loadAccountProfile()!.fullName, 'Sam Patel');
      expect(storage.profileNeedsSync, isTrue);
      await storage.activateAccount('bob');
      expect(storage.loadAccountProfile(), isNull);
      await storage.activateAccount('alice');
      expect(storage.loadAccountProfile()!.emails, hasLength(2));
      await storage.deleteAccountData('alice');
      expect(storage.loadAccountProfile(), isNull);
    },
  );

  testWidgets('new user sets up About Me before building a card', (
    tester,
  ) async {
    SharedPreferences.setMockInitialValues({});
    final storage = await StorageService.init();
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await tester.pumpWidget(
      ContactCardBuilderApp(storageService: storage, requireSignIn: false),
    );
    await tester.pumpAndSettle();
    expect(find.byType(AccountProfileScreen), findsOneWidget);
    await tester.enterText(field('First name *'), 'Sam');
    await tester.enterText(field('Last name (optional)'), 'Patel');
    await tester.tap(find.text('Save').first);
    await tester.pumpAndSettle();
    expect(find.byType(OnboardingCardBuilderScreen), findsOneWidget);
    expect(
      tester.widget<TextFormField>(field('Full Name *')).controller!.text,
      'Sam Patel',
    );
    expect(storage.loadAccountProfile()!.fullName, 'Sam Patel');
  });

  testWidgets(
    'card defaults are copied and can be changed without editing About Me',
    (tester) async {
      SharedPreferences.setMockInitialValues({});
      final storage = await StorageService.init();
      await storage.saveAccountProfile(profile(), dirty: false);
      await storage.setOnboardingCompleted(true);
      tester.view.physicalSize = const Size(390, 844);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      await tester.pumpWidget(
        ContactCardBuilderApp(storageService: storage, requireSignIn: false),
      );
      await tester.pumpAndSettle();
      await tester.tap(find.byTooltip('Create a card'));
      await tester.pumpAndSettle();
      expect(
        tester.widget<TextFormField>(field('Full Name *')).controller!.text,
        'Sam Patel',
      );
      expect(
        tester
            .widget<TextFormField>(field('Role / Job Title *'))
            .controller!
            .text,
        'Florist',
      );
      await tester.enterText(field('Card name *'), 'Work');
      await tester.tap(find.byType(DropdownButtonFormField<CardCategory>));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Professional').last);
      await tester.pumpAndSettle();
      await tester.ensureVisible(field('Full Name *'));
      await tester.enterText(field('Full Name *'), 'Card-specific name');
      await tester.tap(find.text('Next'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Next'));
      await tester.pumpAndSettle();
      expect(
        tester.widget<TextFormField>(field('Email Address')).controller!.text,
        'sam@example.com',
      );
      expect(
        tester.widget<TextFormField>(field('Mobile Phone')).controller!.text,
        '+44123456789',
      );
      await tester.ensureVisible(find.byTooltip('Choose a saved email'));
      await tester.tap(find.byTooltip('Choose a saved email'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('work@example.com').last);
      await tester.pumpAndSettle();
      expect(
        tester.widget<TextFormField>(field('Email Address')).controller!.text,
        'work@example.com',
      );
      await tester.tap(find.text('Next'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Save card'));
      await tester.pumpAndSettle();
      final saved = (await storage.loadCards()).single;
      expect(saved.fullName, 'Card-specific name');
      expect(saved.email, 'work@example.com');
      expect(saved.links.single.url, 'https://www.linkedin.com/in/sam-patel');
      expect(storage.loadAccountProfile()!.fullName, 'Sam Patel');
      expect(storage.loadAccountProfile()!.primaryEmail, 'sam@example.com');
      await tester.tap(find.byTooltip('Your account'));
      await tester.pumpAndSettle();
      expect(find.text('About Me'), findsOneWidget);
      expect(tester.takeException(), isNull);
    },
  );
  testWidgets(
    'About Me adds emails and lets the user choose the primary contact',
    (tester) async {
      SharedPreferences.setMockInitialValues({});
      final storage = await StorageService.init();
      await storage.setOnboardingCompleted(true);
      await storage.saveAccountProfile(profile(), dirty: false);
      tester.view.physicalSize = const Size(390, 844);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      await tester.pumpWidget(
        ContactCardBuilderApp(storageService: storage, requireSignIn: false),
      );
      await tester.pumpAndSettle();
      await tester.tap(find.byTooltip('Your account'));
      await tester.pumpAndSettle();
      await tester.scrollUntilVisible(
        find.text('Add another email'),
        180,
        scrollable: find.byType(Scrollable).first,
      );
      await tester.tap(find.text('Add another email'));
      await tester.pumpAndSettle();
      final additional = find.byWidgetPredicate(
        (w) =>
            w is TextField &&
            w.decoration?.labelText == 'Another contact email',
      );
      await tester.ensureVisible(additional.last);
      await tester.enterText(additional.last, 'personal@example.com');
      await tester.tap(find.byTooltip('Use as primary email').last);
      await tester.pumpAndSettle();
      await tester.tap(find.text('Save').first);
      await tester.pumpAndSettle();
      final saved = storage.loadAccountProfile()!;
      expect(saved.primaryEmail, 'personal@example.com');
      expect(saved.emails, hasLength(3));
      expect(saved.links.single.type, LinkType.linkedin);
      expect(tester.takeException(), isNull);
    },
  );
}
