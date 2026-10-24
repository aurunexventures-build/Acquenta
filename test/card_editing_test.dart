import 'aai_test_helpers.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:contact_card_builder/main.dart';
import 'package:contact_card_builder/models/contact_card.dart';
import 'package:contact_card_builder/providers/cards_provider.dart';
import 'package:contact_card_builder/screens/card_editor_screen.dart';
import 'package:contact_card_builder/screens/profile_questionnaire.dart';
import 'package:contact_card_builder/services/storage_service.dart';

ContactCard card(String id, {bool primary = false}) => ContactCard(
  id: id,
  title: id,
  fullName: 'Sam Patel',
  role: 'Designer',
  headline: 'I design wedding flowers.',
  isDefault: primary,
  createdAt: DateTime(2026),
  updatedAt: DateTime(2026),
);

void main() {
  testWidgets(
    'pitch length is enforced even after scrolling its field off-screen',
    (tester) async {
      SharedPreferences.setMockInitialValues({});
      final storage = await StorageService.init();
      final provider = CardsProvider(storage);
      await provider.loadCards();
      await provider.addCard(card('work'));
      addTearDown(provider.dispose);
      await tester.pumpWidget(
        ChangeNotifierProvider.value(
          value: provider,
          child: MaterialApp(
            home: CardEditorScreen(initialCard: provider.cards.single),
          ),
        ),
      );
      final pitch = find.descendant(
        of: find.byKey(const ValueKey('edit-pitch')),
        matching: find.byType(TextFormField),
      );
      await tester.scrollUntilVisible(
        pitch,
        180,
        scrollable: find.byType(Scrollable).first,
      );
      await tester.enterText(pitch, List.filled(121, 'a').join());
      FocusManager.instance.primaryFocus?.unfocus();
      await tester.scrollUntilVisible(
        find.text('Private card settings'),
        250,
        scrollable: find.byType(Scrollable).first,
      );
      await tester.tap(find.text('Save').first);
      await tester.pumpAndSettle();
      expect(
        find.text('Keep the one-line pitch within 120 characters.'),
        findsOneWidget,
      );
      expect(provider.cards.single.headline, 'I design wedding flowers.');
      expect(tester.takeException(), isNull);
    },
  );

  test(
    'primary is chosen explicitly and never replaced by creation or deletion',
    () async {
      SharedPreferences.setMockInitialValues({});
      final storage = await StorageService.init();
      final provider = CardsProvider(storage);
      await provider.loadCards();
      await provider.addCard(card('work'));
      expect(provider.defaultCard, isNull);
      await provider.setDefaultCard('work');
      await provider.addCard(card('personal'));
      expect(provider.defaultCard!.id, 'work');
      expect(provider.walletCards.first.id, 'work');
      await provider.setDefaultCard('personal');
      expect(provider.cards.where((c) => c.isDefault), hasLength(1));
      expect(
        (await storage.loadCards()).firstWhere((c) => c.isDefault).id,
        'personal',
      );
      await provider.deleteCard('personal');
      expect(provider.defaultCard, isNull);
      expect(provider.cards.single.isDefault, isFalse);
      await provider.setDefaultCard('missing');
      expect(provider.defaultCard, isNull);
      provider.dispose();
    },
  );

  testWidgets(
    'editing keeps fields after scrolling and does not change primary',
    (tester) async {
      SharedPreferences.setMockInitialValues({});
      final storage = await StorageService.init();
      final provider = CardsProvider(storage);
      await provider.loadCards();
      await provider.addCard(card('primary', primary: true));
      await provider.addCard(card('work'));
      tester.view.physicalSize = const Size(320, 700);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      addTearDown(provider.dispose);
      await tester.pumpWidget(
        ChangeNotifierProvider.value(
          value: provider,
          child: MaterialApp(
            home: CardEditorScreen(initialCard: provider.cards.first),
          ),
        ),
      );
      await tester.pumpAndSettle();
      Finder input(String key) => find.descendant(
        of: find.byKey(ValueKey('edit-$key')),
        matching: find.byType(TextFormField),
      );
      await tester.scrollUntilVisible(
        input('name'),
        180,
        scrollable: find.byType(Scrollable).first,
      );
      await tester.enterText(input('name'), 'Sam Edited');
      await tester.scrollUntilVisible(
        input('email'),
        250,
        scrollable: find.byType(Scrollable).first,
      );
      await tester.enterText(input('email'), 'sam@example.com');
      await tester.tap(find.text('Save').first);
      await tester.pumpAndSettle();
      final edited = provider.cards.firstWhere((c) => c.id == 'work');
      expect(edited.fullName, 'Sam Edited');
      expect(edited.email, 'sam@example.com');
      expect(provider.defaultCard!.id, 'primary');
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets('empty wallet retains the introductory caption below the brand', (
    tester,
  ) async {
    SharedPreferences.setMockInitialValues({});
    final storage = await StorageService.init();
    await storage.setOnboardingCompleted(true);
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await tester.pumpWidget(
      ContactCardBuilderApp(storageService: storage, requireSignIn: false),
    );
    await tester.pumpAndSettle();
    expect(find.text('One you.\nMany possibilities.'), findsNothing);
    expect(tester.getRect(find.text('My cards')).top, lessThan(170));
    expect(find.byTooltip('Create a card'), findsOneWidget);
    expect(find.text('Create a card'), findsNothing);
    expect(tester.takeException(), isNull);
  });

  testWidgets('one-description draft remains usable with a phone keyboard', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(393, 852);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    addTearDown(tester.view.resetViewInsets);
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          // The real dialog is on the navigator overlay; apply keyboard insets once.
          resizeToAvoidBottomInset: false,
          body: ProfileQuestionnaire(
            voice: SilentCardVoice(),
            generate: (_) async => {
              'role': 'Designer',
              'pitch': 'I create flowers.',
              'skills': ['Floral design'],
            },
          ),
        ),
      ),
    );
    await tester.enterText(
      find.byKey(const ValueKey('conversation-reply')),
      'I create flowers for weddings.',
    );
    tester.view.viewInsets = const FakeViewPadding(bottom: 340);
    await tester.pumpAndSettle();
    await tester.ensureVisible(
      find.byKey(const ValueKey('conversation-reply')),
    );
    await tester.pumpAndSettle();
    expect(find.text('Add more detail'), findsNothing);
    expect(find.byTooltip('Close'), findsOneWidget);
    expect(
      tester.getRect(find.byTooltip('Close')).bottom,
      lessThanOrEqualTo(512),
    );
    expect(tester.takeException(), isNull);
    tester.view.resetViewInsets();
    await tester.pumpAndSettle();
    await answerCardQuestions(tester);
    expect(find.byType(TextFormField), findsNothing);
    expect(find.text('Review your answers'), findsOneWidget);
  });
}
