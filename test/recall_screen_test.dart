import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:contact_card_builder/providers/connections_provider.dart';
import 'package:contact_card_builder/services/storage_service.dart';
import 'package:contact_card_builder/screens/smart_search_screen.dart';
import 'package:contact_card_builder/widgets/recall_network.dart';
import 'package:contact_card_builder/widgets/recall_activity.dart';
import 'package:contact_card_builder/widgets/visiting_card_deck.dart';

void main() {
  for (final width in [320.0, 390.0, 1000.0]) {
    testWidgets('visible recall flow, reasons and full top match at $width', (
      tester,
    ) async {
      SharedPreferences.setMockInitialValues({});
      final storage = await StorageService.init();
      await storage.addDemoConnectionsOnce();
      final people = ConnectionsProvider(storage);
      await people.loadConnections();
      addTearDown(people.dispose);
      tester.view.physicalSize = Size(width, 800);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      addTearDown(tester.view.resetViewInsets);
      await tester.pumpWidget(
        ChangeNotifierProvider.value(
          value: people,
          child: const MaterialApp(home: SmartSearchScreen()),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.byType(RecallNetwork), findsNothing);
      await tester.enterText(find.byType(TextField), 'developer');
      await tester.pumpAndSettle();
      expect(find.byType(RecallNetwork), findsOneWidget);
      expect(find.byType(RecallActivity), findsOneWidget);
      expect(people.searchResults.length, greaterThan(1));
      final top = find.byKey(const ValueKey('top-recall-match'));
      expect(tester.widget<VisitingCardDeck>(top).compact, isFalse);
      expect(
        tester.getTopLeft(find.byType(RecallNetwork)).dy,
        lessThan(tester.getTopLeft(top).dy),
      );
      final decks = tester
          .widgetList<VisitingCardDeck>(find.byType(VisitingCardDeck))
          .toList();
      expect(decks.last.compact, isTrue);
      expect(decks.last.rankStart, 2);
      expect(
        decks
            .expand((deck) => deck.entries)
            .every((entry) => entry.matchNote != null),
        isTrue,
      );
      await tester.ensureVisible(find.text('Matches'));
      await tester.tap(find.text('Matches'));
      await tester.pumpAndSettle();
      expect(find.byType(RecallNetwork), findsNothing);
      expect(find.byType(RecallActivity), findsNothing);
      final summary = people.searchResults.first.matchReasons.first;
      final explanation = find.byTooltip(summary).first;
      await tester.ensureVisible(explanation);
      await tester.tap(explanation);
      await tester.pumpAndSettle();
      expect(
        find.text('Why ${people.searchResults.first.connection.fullName}?'),
        findsOneWidget,
      );
      await tester.tap(find.text('Close'));
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(
        ChangeNotifierProvider.value(
          value: people,
          child: const MaterialApp(
            home: SmartSearchScreen(key: ValueKey('reopen')),
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.byType(RecallNetwork), findsNothing);
      await tester.ensureVisible(find.text('Matches'));
      await tester.tap(find.text('Matches'));
      await tester.pumpAndSettle();
      expect(find.byType(RecallNetwork), findsOneWidget);
      if (width < 760) {
        tester.view.viewInsets = const FakeViewPadding(bottom: 320);
        await tester.pumpAndSettle();
        expect(find.byType(RecallNetwork), findsNothing);
        expect(find.byKey(const ValueKey('top-recall-match')), findsOneWidget);
        expect(tester.takeException(), isNull);
      }
    });
  }
}
