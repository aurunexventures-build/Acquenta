import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:contact_card_builder/services/text_safety.dart';
import 'package:contact_card_builder/services/storage_service.dart';
import 'package:contact_card_builder/providers/cards_provider.dart';
import 'package:contact_card_builder/models/contact_card.dart';

void main() {
  for (final word in [
    'Fuck',
    'fuck off',
    'f.u.c.k',
    'f*ck',
    'fucking',
    'motherfucker',
    'bullshit',
    'asshole',
  ]) {
    test(
      'blocks $word',
      () => expect(() => TextSafety.validate([word]), throwsFormatException),
    );
  }
  for (final text in [
    'Scunthorpe',
    'Dickinson',
    'Assistant architect',
    'Sexual health counsellor',
  ]) {
    test(
      'allows $text',
      () => expect(() => TextSafety.validate([text]), returnsNormally),
    );
  }
  test(
    'rejected card does not change primary or create a saved record',
    () async {
      SharedPreferences.setMockInitialValues({});
      final storage = await StorageService.init();
      final cards = CardsProvider(storage);
      addTearDown(cards.dispose);
      await cards.loadCards();
      final now = DateTime.now();
      final card = ContactCard(
        id: 'safe',
        fullName: 'Sam',
        role: 'Architect',
        headline: 'I design buildings',
        createdAt: now,
        updatedAt: now,
        isDefault: true,
      );
      await cards.addCard(card);
      await expectLater(
        cards.addCard(card.copyWith(id: 'blocked', headline: 'Fuck')),
        throwsFormatException,
      );
      await expectLater(
        cards.updateCard(card.copyWith(headline: 'fuck off')),
        throwsFormatException,
      );
      expect(cards.cards.single.headline, 'I design buildings');
      expect(cards.defaultCard?.id, 'safe');
    },
  );
}
