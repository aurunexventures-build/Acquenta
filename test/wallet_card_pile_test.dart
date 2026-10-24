import 'package:flutter/material.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:contact_card_builder/models/contact_card.dart';
import 'package:contact_card_builder/providers/cards_provider.dart';
import 'package:contact_card_builder/services/storage_service.dart';
import 'package:contact_card_builder/widgets/visiting_card_deck.dart';
import 'package:contact_card_builder/widgets/wallet_card_pile.dart';

ContactCard sample(String id, {bool primary = false}) => ContactCard(
  id: id,
  fullName: 'Person $id',
  role: 'Architect',
  headline: 'I connect systems.',
  isDefault: primary,
  createdAt: DateTime(2026),
  updatedAt: DateTime(2026),
);
Future<(StorageService, CardsProvider)> fixture({int count = 3}) async {
  SharedPreferences.setMockInitialValues({});
  final storage = await StorageService.init();
  await storage.saveCards(
    List.generate(count, (i) => sample('$i', primary: i == 0)),
  );
  final provider = CardsProvider(storage);
  await provider.loadCards();
  return (storage, provider);
}

void main() {
  test(
    'new cards suggest distinct colours and preserve a chosen custom colour',
    () async {
      final (_, provider) = await fixture();
      addTearDown(provider.dispose);
      final first = provider.suggestedCardColour;
      await provider.addCard(sample('custom').copyWith(themeColorHex: first));
      expect(provider.suggestedCardColour, isNot(first));
      await provider.updateCard(
        provider.cards
            .firstWhere((c) => c.id == 'custom')
            .copyWith(themeColorHex: '#123ABC'),
      );
      await provider.loadCards();
      expect(
        provider.cards.firstWhere((c) => c.id == 'custom').themeColorHex,
        '#123ABC',
      );
    },
  );
  testWidgets(
    'desktop mouse drag starts immediately and updates the primary card',
    (tester) async {
      final (_, provider) = await fixture();
      addTearDown(provider.dispose);
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: SingleChildScrollView(
              child: SizedBox(
                width: 360,
                child: AnimatedBuilder(
                  animation: provider,
                  builder: (context, child) => WalletCardPile(
                    entries: provider.walletCards
                        .map((c) => WalletEntry.own(c, onOpen: () {}))
                        .toList(),
                    onReorder: provider.reorderWallet,
                  ),
                ),
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      Finder card(String id) => find.byKey(ValueKey('wallet-pile-card-$id'));
      final start = tester.getTopLeft(card('2')) + const Offset(35, 25);
      final target = tester.getTopLeft(card('0')) + const Offset(35, 25);
      final gesture = await tester.startGesture(
        start,
        kind: PointerDeviceKind.mouse,
      );
      await gesture.moveBy(const Offset(0, 20));
      await tester.pump();
      expect(find.byType(VisitingCardDeck), findsNWidgets(4));
      await gesture.moveTo(target);
      await tester.pump();
      await gesture.up();
      await tester.pumpAndSettle();
      expect(provider.defaultCard!.id, '2');
      expect(provider.walletCards.first.id, '2');
    },
    variant: TargetPlatformVariant.only(TargetPlatform.macOS),
  );
  test(
    'primary selection and dragging stay synchronized after reload',
    () async {
      final (_, provider) = await fixture();
      addTearDown(provider.dispose);
      await provider.reorderWallet(['2', '0', '1']);
      await provider.setDefaultCard('1');
      expect(provider.walletCards.first.id, '1');
      expect(provider.cards.where((c) => c.isDefault).single.id, '1');
      await provider.updateCard(
        provider.cards.firstWhere((c) => c.id == '0').copyWith(isDefault: true),
      );
      expect(provider.walletCards.first.id, '0');
      await provider.reorderWallet(['2', '0', '1']);
      expect(provider.defaultCard!.id, '2');
      expect(provider.cards.where((c) => c.isDefault).length, 1);
      await provider.loadCards();
      expect(provider.walletCards.first.id, '2');
      expect(provider.defaultCard!.id, '2');
    },
  );
  test(
    'reordering persists primary and private ranks through reload and cloud merge',
    () async {
      final (storage, provider) = await fixture();
      addTearDown(provider.dispose);
      var changes = 0;
      provider.onLocalChange = () => changes++;
      await provider.reorderWallet(['2', '0', '1']);
      expect(provider.walletCards.map((c) => c.id), ['2', '0', '1']);
      expect(provider.defaultCard!.id, '2');
      expect(changes, 1);
      await provider.loadCards();
      expect(provider.walletCards.map((c) => c.id), ['2', '0', '1']);
      final restored = CardsProvider(storage);
      addTearDown(restored.dispose);
      await restored.loadCards();
      await restored.mergeCloud(provider.cards.reversed.toList(), []);
      expect(restored.walletCards.map((c) => c.id), ['2', '0', '1']);
      expect(restored.defaultCard!.id, '2');
      expect(restored.cards.every((c) => c.walletOrder != null), isTrue);
    },
  );
  test(
    'malformed orders and dragging locked cards forward cannot change the wallet',
    () async {
      final (_, provider) = await fixture(count: 6);
      addTearDown(provider.dispose);
      await expectLater(
        provider.reorderWallet(['0', '0', '1', '2', '3', '4']),
        throwsArgumentError,
      );
      await expectLater(
        provider.reorderWallet(['5', '0', '1', '2', '3', '4']),
        throwsStateError,
      );
      expect(provider.defaultCard!.id, '0');
      expect(provider.isCardLocked('5'), isTrue);
    },
  );
  testWidgets(
    'drag front card behind a back header and promote a back card to front',
    (tester) async {
      final (_, provider) = await fixture();
      addTearDown(provider.dispose);
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: SingleChildScrollView(
              child: SizedBox(
                width: 360,
                child: AnimatedBuilder(
                  animation: provider,
                  builder: (context, child) => WalletCardPile(
                    entries: provider.walletCards
                        .map((c) => WalletEntry.own(c, onOpen: () {}))
                        .toList(),
                    onReorder: provider.reorderWallet,
                  ),
                ),
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      Finder card(String id) => find.byKey(ValueKey('wallet-pile-card-$id'));
      expect(find.byKey(const ValueKey('my-cards-pile')), findsOneWidget);
      final frontRect = tester.getRect(card('0'));
      expect(frontRect.height, greaterThan(100));
      expect(tester.getRect(card('2')).height, 64);
      Future<void> drag(String from, String to) async {
        expect(
          tester
              .widget<LongPressDraggable<String>>(
                find.descendant(
                  of: card(from),
                  matching: find.byType(LongPressDraggable<String>),
                ),
              )
              .maxSimultaneousDrags,
          1,
        );
        final start = tester.getTopLeft(card(from)) + const Offset(35, 25);
        final target = tester.getTopLeft(card(to)) + const Offset(35, 25);
        final gesture = await tester.startGesture(start);
        await tester.pump(const Duration(milliseconds: 400));
        expect(
          find.byType(VisitingCardDeck),
          findsNWidgets(4),
          reason: 'Drag $from must start',
        );
        await gesture.moveTo(target);
        await tester.pump(const Duration(milliseconds: 200));
        await gesture.up();
        await tester.pumpAndSettle();
      }

      await drag('0', '2');
      expect(provider.walletCards.map((c) => c.id), ['1', '2', '0']);
      expect(provider.defaultCard!.id, '1');
      await drag('0', '1');
      expect(provider.walletCards.map((c) => c.id), ['0', '1', '2']);
      expect(provider.defaultCard!.id, '0');
      expect(tester.takeException(), isNull);
    },
  );
}
