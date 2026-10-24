import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:contact_card_builder/main.dart';
import 'package:contact_card_builder/models/contact_card.dart';
import 'package:contact_card_builder/providers/cards_provider.dart';
import 'package:contact_card_builder/screens/card_editor_screen.dart';
import 'package:contact_card_builder/services/storage_service.dart';

ContactCard sample(String id, {bool primary = false}) => ContactCard(
  id: id,
  title: id,
  fullName: 'Sam Patel',
  role: 'Architect',
  headline: 'I help teams build.',
  isDefault: primary,
  createdAt: DateTime(2026),
  updatedAt: DateTime(2026),
);
void main() {
  testWidgets(
    'wallet deletion can be cancelled and confirmed deletion frees a slot with a sync tombstone',
    (tester) async {
      SharedPreferences.setMockInitialValues({});
      final storage = await StorageService.init();
      await storage.saveCards([
        sample('Work', primary: true),
        sample('Creative'),
      ]);
      await storage.setOnboardingCompleted(true);
      await tester.pumpWidget(
        ContactCardBuilderApp(storageService: storage, requireSignIn: false),
      );
      await tester.pumpAndSettle();
      expect(find.byTooltip('Card options'), findsNWidgets(2));
      expect(find.byTooltip('Send card'), findsNothing);
      expect(find.textContaining('Add card · slot'), findsNothing);
      await tester.tap(
        find.descendant(
          of: find.byKey(const ValueKey('wallet-pile-card-Work')),
          matching: find.byTooltip('Card options'),
        ),
      );
      await tester.pumpAndSettle();
      await tester.tap(find.text('Delete card').last);
      await tester.pumpAndSettle();
      expect(
        find.text(
          'Delete “Sam Patel” from your wallet? This frees up its card slot.',
        ),
        findsOneWidget,
      );
      await tester.tap(find.text('Cancel'));
      await tester.pumpAndSettle();
      expect((await storage.loadCards()).length, 2);
      await tester.tap(
        find.descendant(
          of: find.byKey(const ValueKey('wallet-pile-card-Work')),
          matching: find.byTooltip('Card options'),
        ),
      );
      await tester.pumpAndSettle();
      await tester.tap(find.text('Delete card').last);
      await tester.pumpAndSettle();
      await tester.tap(find.widgetWithText(FilledButton, 'Delete card'));
      await tester.pumpAndSettle();
      final cards = await storage.loadCards();
      expect(cards.map((card) => card.id), ['Creative']);
      expect(
        storage.loadDeletions().any(
          (d) => d['kind'] == 'card' && d['id'] == 'Work',
        ),
        isTrue,
      );
      final provider = tester
          .element(find.byTooltip('Card options'))
          .read<CardsProvider>();
      expect(provider.remainingCardSlots, 4);
      expect(provider.defaultCard, isNull);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets('existing card editor exposes Delete card but new cards do not', (
    tester,
  ) async {
    SharedPreferences.setMockInitialValues({});
    final storage = await StorageService.init();
    final cards = CardsProvider(storage);
    await cards.loadCards();
    await cards.addCard(sample('Work'));
    Future<void> open(ContactCard? card) async {
      await tester.pumpWidget(
        ChangeNotifierProvider.value(
          value: cards,
          child: MaterialApp(home: CardEditorScreen(initialCard: card)),
        ),
      );
      await tester.pumpAndSettle();
    }

    await open(null);
    expect(find.text('Delete card'), findsNothing);
    await tester.pumpWidget(const SizedBox());
    await open(cards.cards.single);
    await tester.scrollUntilVisible(
      find.text('Delete card'),
      400,
      scrollable: find.byType(Scrollable).first,
    );
    expect(find.text('Delete card'), findsOneWidget);
    await tester.tap(find.text('Delete card'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Cancel'));
    await tester.pumpAndSettle();
    expect(cards.cards.length, 1);
    expect(tester.takeException(), isNull);
  });
  testWidgets(
    'deleting from an editor returns to the wallet and never shows a different card',
    (tester) async {
      SharedPreferences.setMockInitialValues({});
      final storage = await StorageService.init();
      await storage.saveCards([
        sample('Work', primary: true),
        sample('Creative'),
      ]);
      await storage.setOnboardingCompleted(true);
      await tester.pumpWidget(
        ContactCardBuilderApp(storageService: storage, requireSignIn: false),
      );
      await tester.pumpAndSettle();
      await tester.tap(
        find.descendant(
          of: find.byKey(const ValueKey('wallet-pile-card-Work')),
          matching: find.text('Sam Patel'),
        ),
      );
      await tester.pumpAndSettle();
      await tester.tap(find.byTooltip('Edit Card'));
      await tester.pumpAndSettle();
      await tester.scrollUntilVisible(
        find.text('Delete card'),
        400,
        scrollable: find.byType(Scrollable).first,
      );
      await tester.tap(find.text('Delete card'));
      await tester.pumpAndSettle();
      await tester.tap(find.widgetWithText(FilledButton, 'Delete card'));
      await tester.pumpAndSettle();
      expect(find.byType(CardEditorScreen), findsNothing);
      expect(find.text('My cards'), findsWidgets);
      expect((await storage.loadCards()).map((c) => c.id), ['Creative']);
      expect(tester.takeException(), isNull);
    },
  );
}
