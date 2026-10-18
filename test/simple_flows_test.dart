import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:contact_card_builder/models/contact_card.dart';
import 'package:contact_card_builder/models/event_context.dart';
import 'package:contact_card_builder/models/saved_connection.dart';
import 'package:contact_card_builder/providers/cards_provider.dart';
import 'package:contact_card_builder/providers/connections_provider.dart';
import 'package:contact_card_builder/screens/profile_questionnaire.dart';
import 'package:contact_card_builder/screens/smart_search_screen.dart';
import 'package:contact_card_builder/services/own_card_search.dart';
import 'package:contact_card_builder/services/search_service.dart';
import 'package:contact_card_builder/services/storage_service.dart';
import 'package:contact_card_builder/widgets/recall_network.dart';
import 'package:contact_card_builder/widgets/voice_magic_bar.dart';

ContactCard ownCard(String id, String pitch) => ContactCard(
  id: id,
  title: 'Work',
  category: CardCategory.professional,
  fullName: 'My own profile',
  role: 'Creator',
  headline: pitch,
  createdAt: DateTime(2026),
  updatedAt: DateTime(2026),
);
void main() {
  setUp(() => SharedPreferences.setMockInitialValues({}));
  test('own card recall includes Android wording from its pitch', () {
    final cards = [
      ownCard('android', 'I create Android applications'),
      ownCard('other', 'I teach yoga'),
    ];
    expect(OwnCardSearch.search(cards, 'Android').map((c) => c.id), [
      'android',
    ]);
  });
  test(
    'direct technology evidence outranks broad associations and ties prefer recent contacts',
    () {
      SavedConnection person(String id, String pitch, DateTime at) =>
          SavedConnection(
            id: id,
            fullName: id,
            role: 'Creator',
            headline: pitch,
            eventContext: EventContext(eventName: 'Meetup', date: at),
            savedAt: at,
          );
      final old = person('older', 'I build Android apps', DateTime(2025));
      final recent = person('recent', 'I build Android apps', DateTime(2026));
      final broad = person('generic', 'I build websites', DateTime(2026));
      final results = SearchService.search(
        connections: [old, broad, recent],
        query: 'Android apps',
      );
      expect(results.first.connection.id, 'recent');
    },
  );
  testWidgets('recall excludes own cards even when their skills match', (
    tester,
  ) async {
    final storage = await StorageService.init();
    await storage.saveCards([
      ownCard('android', 'I create Android applications'),
    ]);
    final cards = CardsProvider(storage), people = ConnectionsProvider(storage);
    await cards.loadCards();
    await people.loadConnections();
    addTearDown(cards.dispose);
    addTearDown(people.dispose);
    await tester.pumpWidget(
      MultiProvider(
        providers: [
          ChangeNotifierProvider.value(value: cards),
          ChangeNotifierProvider.value(value: people),
        ],
        child: const MaterialApp(home: SmartSearchScreen()),
      ),
    );
    await tester.enterText(find.byType(TextField), 'Android');
    await tester.pumpAndSettle();
    expect(find.text('Your cards'), findsNothing);
    expect(find.text('My own profile'), findsNothing);
    expect(find.byType(RecallNetwork), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
  for (final size in [
    const Size(320, 568),
    const Size(360, 640),
    const Size(390, 844),
  ]) {
    testWidgets(
      'profile voice and AI controls stay usable at $size with keyboard',
      (tester) async {
        tester.view.physicalSize = size;
        tester.view.devicePixelRatio = 1;
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);
        addTearDown(tester.view.resetViewInsets);
        await tester.pumpWidget(
          MaterialApp(
            home: Scaffold(
              body: ProfileQuestionnaire(
                generate: (_) async => {
                  'role': 'Creator',
                  'pitch': 'I create Android apps.',
                  'skills': ['Android'],
                },
              ),
            ),
          ),
        );
        expect(find.byType(VoiceMagicBar), findsOneWidget);
        expect(find.text('Speak'), findsOneWidget);
        expect(find.text('Draft my card'), findsOneWidget);
        final work = find.byType(TextFormField).first;
        await tester.enterText(work, 'I create Android apps.');
        tester.view.viewInsets = const FakeViewPadding(bottom: 280);
        await tester.pumpAndSettle();
        expect(find.byTooltip('Draft my card'), findsOneWidget);
        expect(tester.takeException(), isNull);
        tester.view.resetViewInsets();
        await tester.pumpAndSettle();
        await tester.ensureVisible(find.text('Draft my card'));
        await tester.tap(find.text('Draft my card'));
        await tester.pumpAndSettle();
        expect(find.text('Review your draft'), findsOneWidget);
        expect(tester.takeException(), isNull);
      },
    );
  }
}
