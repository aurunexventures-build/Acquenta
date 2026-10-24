import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:qr_flutter/qr_flutter.dart';
import 'package:contact_card_builder/models/contact_card.dart';
import 'package:contact_card_builder/services/offline_card_share.dart';
import 'package:contact_card_builder/services/vcard_service.dart';
import 'package:contact_card_builder/widgets/qr_share_dialog.dart';
import 'package:contact_card_builder/widgets/visiting_card_deck.dart';

void main() {
  final card = ContactCard(
    id: 'offline',
    title: 'Work',
    fullName: 'Sam Patel',
    role: 'Designer',
    email: 'sam@example.com',
    phone: '+44123456789',
    createdAt: DateTime(2026),
    updatedAt: DateTime(2026),
  );

  test('large profiles retain offline contact details in a bounded QR', () {
    final large = card.copyWith(bio: List.filled(5000, 'a').join());
    final qr = OfflineCardShare.qr(large);
    expect(utf8.encode(qr).length, lessThanOrEqualTo(2000));
    expect(qr, contains('Sam Patel'));
    expect(qr, contains('sam@example.com'));
    expect(qr, contains('+44123456789'));
    expect(VCardService.generateVCard(card: large).length, greaterThan(5000));
  });

  testWidgets(
    'every overlapping card has an independently usable send action',
    (tester) async {
      tester.view.physicalSize = const Size(320, 800);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      final sent = <int>[];
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: SingleChildScrollView(
              child: VisitingCardDeck(
                entries: List.generate(
                  3,
                  (i) => WalletEntry(
                    id: '$i',
                    name: 'Person $i',
                    role: 'Designer',
                    onOpen: () {},
                    onSend: () => sent.add(i),
                  ),
                ),
              ),
            ),
          ),
        ),
      );
      for (var i = 0; i < 3; i++) {
        await tester.tap(find.byTooltip('Send card').at(i));
      }
      expect(sent, [0, 1, 2]);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets('send opens with a self-contained offline QR on a small phone', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(320, 640);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await tester.pumpWidget(MaterialApp(home: QrShareDialog(card: card)));
    await tester.pumpAndSettle();
    expect(find.byType(QrImageView), findsOneWidget);
    expect(OfflineCardShare.qr(card), startsWith('BEGIN:VCARD'));
    expect(find.text('Send contact file'), findsOneWidget);
    expect(find.text('Create online link'), findsNothing);
    expect(tester.takeException(), isNull);
  });
}
