import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:contact_card_builder/models/contact_card.dart';
import 'package:contact_card_builder/models/saved_connection.dart';
import 'package:contact_card_builder/services/card_exchange_service.dart';
import 'package:contact_card_builder/services/vcard_service.dart';
import 'package:contact_card_builder/widgets/card_finish_picker.dart';
import 'package:contact_card_builder/widgets/visiting_card_deck.dart';

void main() {
  final card = ContactCard(
    id: 'finish-card',
    fullName: 'Sam Patel',
    themeColorHex: '#234B42',
    cardFinish: 'linen',
    createdAt: DateTime(2026),
    updatedAt: DateTime(2026),
  );
  test('appearance survives save, copy and offline contact exchange', () {
    final restored = ContactCard.fromJson(
      card.toJson(),
    ).copyWith(role: 'Architect');
    expect(restored.cardFinish, 'linen');
    final received = CardExchangeService.parseVCard(
      VCardService.generateVCard(card: restored),
    );
    expect(received.cardFinish, 'linen');
    expect(received.themeColorHex, '#234B42');
    final saved = SavedConnection.fromJson(
      received.toJson(),
    ).copyWith(futureSelfNote: 'Met at work');
    expect(saved.cardFinish, 'linen');
    expect(
      WalletEntry.person(saved, onOpen: () {}).color.toARGB32(),
      0xFF234B42,
    );
    expect(CardExchangeService.fromCard(restored).cardFinish, 'linen');
  });
  testWidgets('finish controls update a live preview without an account', (
    tester,
  ) async {
    String finish = 'plain';
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: StatefulBuilder(
            builder: (context, setState) => CardFinishPicker(
              value: finish,
              colour: '#FFFFFF',
              name: 'Sam Patel',
              onChanged: (v) => setState(() => finish = v),
            ),
          ),
        ),
      ),
    );
    await tester.tap(find.text('Monogram'));
    await tester.pumpAndSettle();
    expect(finish, 'monogram');
    expect(tester.takeException(), isNull);
  });
}
