import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:contact_card_builder/models/event_context.dart';
import 'package:contact_card_builder/models/saved_connection.dart';
import 'package:contact_card_builder/providers/connections_provider.dart';
import 'package:contact_card_builder/services/storage_service.dart';
import 'package:contact_card_builder/services/search_service.dart';
import 'package:contact_card_builder/services/reconnect_service.dart';
import 'package:contact_card_builder/widgets/relationship_tools.dart';
import 'package:contact_card_builder/screens/follow_ups_screen.dart';
import 'package:contact_card_builder/screens/connection_detail_screen.dart';

SavedConnection person() => SavedConnection(
  id: 'person',
  fullName: 'Priya',
  rawCue: 'Yellow backpack',
  eventContext: EventContext(
    eventName: 'Design Night',
    date: DateTime(2026),
    notes: 'Packaging',
  ),
  savedAt: DateTime(2026),
);

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUp(() => SharedPreferences.setMockInitialValues({}));
  test(
    'history preserves previous cues, supports recall and rejects stale edits',
    () async {
      final storage = await StorageService.init();
      final p = ConnectionsProvider(storage);
      addTearDown(p.dispose);
      await p.loadConnections();
      await p.addConnection(person());
      final before = p.connections.single;
      await p.updateConnection(
        before.copyWith(rawCue: 'New memory'),
        expectedVersion: before.updatedAt,
      );
      expect(
        p.connections.single.interactions.single.text,
        contains('Yellow backpack'),
      );
      await p.addInteraction('person', 'Discussed origami robotics');
      final current = p.connections.single;
      expect(
        SearchService.search(
          connections: [current],
          query: 'origami',
        ).single.connection.id,
        'person',
      );
      await expectLater(
        p.updateConnection(
          before.copyWith(fullName: 'Stale'),
          expectedVersion: before.updatedAt,
        ),
        throwsStateError,
      );
      expect(p.connections.single.rawCue, 'New memory');
      expect((await storage.loadConnections()).single.interactions.length, 2);
      await expectLater(p.addInteraction('person', '   '), throwsArgumentError);
      await expectLater(
        p.addInteraction('person', 'x' * 2001),
        throwsArgumentError,
      );
      await p.deleteConnection('person');
      await expectLater(p.updateConnection(before), throwsStateError);
    },
  );
  test('offline drafts use saved context without inventing promises', () {
    expect(ReconnectService.draft(person()), contains('Design Night'));
    expect(ReconnectService.draft(person()), isNot(contains('promised')));
    expect(
      ReconnectService.draft(
        person().copyWith(
          fullName: '',
          eventContext: EventContext(eventName: '', date: DateTime(2026)),
        ),
      ),
      startsWith('Hi there'),
    );
  });
  for (final width in [390.0, 1440.0]) {
    testWidgets('log interaction and edit reconnect draft at $width', (
      tester,
    ) async {
      tester.view.physicalSize = Size(width, 900);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      final storage = await StorageService.init();
      final p = ConnectionsProvider(storage);
      await p.loadConnections();
      await p.addConnection(person());
      await tester.pumpWidget(
        ChangeNotifierProvider.value(
          value: p,
          child: MaterialApp(
            home: Scaffold(
              body: Consumer<ConnectionsProvider>(
                builder: (_, p, _) => SingleChildScrollView(
                  child: RelationshipTools(connection: p.connections.single),
                ),
              ),
            ),
          ),
        ),
      );
      await tester.tap(find.text('Log interaction'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Save note'));
      await tester.pumpAndSettle();
      expect(find.text('Write a short note first.'), findsOneWidget);
      await tester.enterText(find.byType(TextFormField), 'Coffee and robotics');
      await tester.tap(find.text('Save note'));
      await tester.pumpAndSettle();
      expect(
        p.connections.single.interactions.single.text,
        'Coffee and robotics',
      );
      await tester.tap(find.text('Conversation note'));
      await tester.pumpAndSettle();
      expect(find.text('Coffee and robotics'), findsOneWidget);
      await tester.tap(find.text('Reconnect'));
      await tester.pumpAndSettle();
      await tester.enterText(find.byType(TextFormField), 'Hello Priya');
      expect(find.text('Hello Priya'), findsOneWidget);
      await tester.tap(find.text('Close'));
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox());
      p.dispose();
    });
  }
  testWidgets(
    'completed reminders can be reopened and deleted contacts show a safe empty state',
    (tester) async {
      final storage = await StorageService.init();
      final p = ConnectionsProvider(storage);
      await p.loadConnections();
      await p.addConnection(person());
      await p.setFollowUp(
        'person',
        DateTime.now().add(const Duration(days: 2)),
        'Send proposal',
      );
      await p.completeFollowUp('person');
      await tester.pumpWidget(
        ChangeNotifierProvider.value(
          value: p,
          child: const MaterialApp(home: FollowUpsScreen()),
        ),
      );
      await tester.pumpAndSettle();
      await tester.tap(find.text('Completed'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Reopen'));
      await tester.pumpAndSettle();
      expect(p.pendingFollowUps.length, 1);
      await p.deleteConnection('person');
      await tester.pumpWidget(
        ChangeNotifierProvider.value(
          value: p,
          child: const MaterialApp(
            home: ConnectionDetailScreen(connectionId: 'person'),
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.text('Connection unavailable'), findsOneWidget);
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox());
      p.dispose();
    },
  );
}
