import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:contact_card_builder/models/card_link.dart';
import 'package:contact_card_builder/models/contact_card.dart';
import 'package:contact_card_builder/providers/cards_provider.dart';
import 'package:contact_card_builder/services/skill_tags.dart';
import 'package:contact_card_builder/services/storage_service.dart';
import 'package:contact_card_builder/widgets/ai_voice_composer.dart';
import 'package:contact_card_builder/widgets/card_text_field.dart';
import 'package:contact_card_builder/widgets/skills_tags_editor.dart';
import 'package:contact_card_builder/widgets/social_links_editor.dart';
import 'package:contact_card_builder/widgets/wallet_free_slots.dart';

void main() {
  test(
    'manual comma-separated tags have individual limits, not a 50 character total',
    () {
      final tags = SkillTags.parse(
        'Plumbing, Bathroom fitting, Android development, Flutter, Kotlin, plumbing',
      );
      expect(tags, [
        'Plumbing',
        'Bathroom fitting',
        'Android development',
        'Flutter',
        'Kotlin',
      ]);
      expect(tags.join(',').length, greaterThan(50));
      expect(() => SkillTags.parse('x' * 51), throwsFormatException);
    },
  );
  test(
    'local free-card limit preserves primary and allows reuse after deleting',
    () async {
      SharedPreferences.setMockInitialValues({});
      final storage = await StorageService.init(), now = DateTime(2026);
      final cards = CardsProvider(storage);
      await cards.loadCards();
      for (var i = 0; i < 5; i++) {
        await cards.addCard(
          ContactCard(
            id: '$i',
            title: 'Work',
            fullName: 'Sam',
            isDefault: i == 0,
            createdAt: now,
            updatedAt: now,
          ),
        );
      }
      expect(cards.canCreateCard, isFalse);
      expect(
        () => cards.addCard(
          ContactCard(
            id: 'six',
            title: 'Extra',
            fullName: 'Sam',
            createdAt: now,
            updatedAt: now,
          ),
        ),
        throwsStateError,
      );
      expect(cards.defaultCard!.id, '0');
      await cards.deleteCard('4');
      expect(cards.remainingCardSlots, 1);
      cards.dispose();
    },
  );
  testWidgets(
    'voice is opt-in and review is required before applying AI wording',
    (tester) async {
      final name = TextEditingController(text: 'Sam'),
          pitch = TextEditingController(text: 'I create flowers');
      addTearDown(name.dispose);
      addTearDown(pitch.dispose);
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: ListView(
              children: [
                CardTextField(controller: name, label: 'Full name'),
                CardTextField(
                  controller: pitch,
                  label: 'Pitch',
                  voiceEnabled: true,
                  organise: (_) async => 'I design wedding flowers.',
                ),
              ],
            ),
          ),
        ),
      );
      expect(find.byTooltip('Speak with AI'), findsOneWidget);
      await tester.tap(find.byTooltip('Speak with AI'));
      await tester.pumpAndSettle();
      expect(find.byType(AiVoiceComposer), findsOneWidget);
      await tester.tap(find.text('Organise typed text'));
      await tester.pumpAndSettle();
      expect(pitch.text, 'I create flowers');
      await tester.tap(find.text('Use this wording'));
      await tester.pumpAndSettle();
      expect(pitch.text, 'I design wedding flowers.');
      expect(find.text('Undo'), findsOneWidget);
      final snack = tester.widget<SnackBar>(find.byType(SnackBar));
      expect(snack.persist, isFalse);
      await tester.pump(const Duration(seconds: 4));
      await tester.pumpAndSettle();
      expect(find.text('Undo'), findsNothing);
    },
  );
  testWidgets(
    'paragraph extraction offers short skills before explicitly adding them',
    (tester) async {
      var tags = <String>[];
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: StatefulBuilder(
              builder: (context, update) => SingleChildScrollView(
                child: SkillsTagsEditor(
                  skills: tags,
                  extract: (text) async {
                    expect(text.length, greaterThan(50));
                    return ['Plumbing', 'Bathroom fitting'];
                  },
                  onChanged: (value) => update(() => tags = value),
                ),
              ),
            ),
          ),
        ),
      );
      await tester.enterText(
        find.byKey(const ValueKey('skill-experience')),
        'I am a plumber who repairs pipes and installs bathrooms for local families.',
      );
      await tester.tap(find.text('Extract skills'));
      await tester.pumpAndSettle();
      expect(tags, isEmpty);
      await tester.tap(find.widgetWithText(FilterChip, 'Plumbing'));
      await tester.pumpAndSettle();
      expect(tags, ['Plumbing']);
    },
  );
  testWidgets(
    'social rows build URLs from handles and support another profile',
    (tester) async {
      final drafts = [SocialLinkDraft(type: LinkType.linkedin)];
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: SingleChildScrollView(
              child: SocialLinksEditor(drafts: drafts, onChanged: () {}),
            ),
          ),
        ),
      );
      await tester.enterText(find.byType(TextFormField).first, 'sam-patel');
      expect(drafts.first.link!.url, 'https://www.linkedin.com/in/sam-patel');
      await tester.tap(find.byTooltip('Add social profile or website'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('YouTube').last);
      await tester.pumpAndSettle();
      await tester.enterText(find.byType(TextFormField).last, '@samcreates');
      expect(drafts.last.link!.url, 'https://www.youtube.com/@samcreates');
      await tester.pumpWidget(const SizedBox());
      for (final d in drafts) {
        d.dispose();
      }
    },
  );
  testWidgets('three cards show exactly two tappable blank wallet slots', (
    tester,
  ) async {
    var taps = 0;
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: WalletFreeSlots(used: 3, remaining: 2, onAdd: () => taps++),
        ),
      ),
    );
    expect(find.text('Add card · slot 4 of 5'), findsOneWidget);
    expect(find.text('Add card · slot 5 of 5'), findsOneWidget);
    await tester.tap(find.text('Add card · slot 4 of 5'));
    await tester.tap(find.text('Add card · slot 5 of 5'));
    expect(taps, 2);
  });
}
