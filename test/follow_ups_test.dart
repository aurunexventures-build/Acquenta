import 'dart:convert';
import 'package:contact_card_builder/services/follow_up_calendar.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:contact_card_builder/models/event_context.dart';
import 'package:contact_card_builder/models/saved_connection.dart';
import 'package:contact_card_builder/providers/connections_provider.dart';
import 'package:contact_card_builder/services/storage_service.dart';
import 'package:contact_card_builder/widgets/follow_up_card.dart';
import 'package:contact_card_builder/screens/follow_ups_screen.dart';

SavedConnection person(String id) => SavedConnection(
  id: id,
  fullName: 'Priya $id',
  eventContext: EventContext(eventName: 'Meetup', date: DateTime(2026)),
  savedAt: DateTime(2026),
);

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUp(() => SharedPreferences.setMockInitialValues({}));

  test(
    'legacy records load, reminders persist and remain account scoped',
    () async {
      final storage = await StorageService.init();
      await storage.activateAccount('first-user');
      final provider = ConnectionsProvider(storage);
      await provider.loadConnections();
      addTearDown(provider.dispose);
      expect(
        SavedConnection.fromJson(
          person('old').toJson()..remove('followUpAt'),
        ).followUpAt,
        isNull,
      );
      await provider.addConnection(person('a'));
      await provider.addConnection(person('b'));
      final due = DateTime.now().add(const Duration(days: 2));
      await provider.setFollowUp('a', due, 'Send proposal');
      await provider.setFollowUp(
        'b',
        due.subtract(const Duration(days: 1)),
        'Coffee',
      );
      expect(provider.pendingFollowUps.map((c) => c.id), ['b', 'a']);
      expect(
        (await storage.loadConnections())
            .firstWhere((c) => c.id == 'a')
            .followUpNote,
        'Send proposal',
      );
      await provider.toggleFavorite('a');
      expect(
        provider.connections.firstWhere((c) => c.id == 'a').followUpAt,
        due,
      );
      await provider.completeFollowUp('a');
      expect(provider.pendingFollowUps.map((c) => c.id), ['b']);
      await provider.setFollowUp('a', due, 'Reopened');
      expect(
        provider.connections.firstWhere((c) => c.id == 'a').followUpCompleted,
        false,
      );
      await provider.removeFollowUp('a');
      expect(
        provider.connections.firstWhere((c) => c.id == 'a').followUpAt,
        isNull,
      );
      await expectLater(
        provider.setFollowUp('a', DateTime(2000), ''),
        throwsArgumentError,
      );
      await storage.activateAccount('other-user');
      provider.clearForAccountSwitch();
      await provider.loadConnections();
      expect(provider.pendingFollowUps, isEmpty);
    },
  );

  test('calendar uses UTC, escapes notes and folds Unicode safely', () {
    final c = person('a').copyWith(
      followUpAt: DateTime.parse('2027-01-10T10:00:00+01:00'),
      followUpNote: 'Proposal; café, team\n${'🎉' * 60}',
    );
    final calendar = FollowUpCalendar.generate(c);
    expect(calendar, contains('DTSTART:20270110T090000Z'));
    expect(calendar, contains('TRIGGER:-PT10M'));
    final unfolded = calendar.replaceAll('\r\n ', '');
    expect(unfolded, contains(r'Proposal\; café\, team\n'));
    expect(unfolded, contains('🎉' * 60));
    for (final line in calendar.split('\r\n')) {
      expect(utf8.encode(line).length, lessThanOrEqualTo(75));
    }
  });

  for (final width in [390.0, 1440.0]) {
    testWidgets('schedule, snooze and complete at width $width', (
      tester,
    ) async {
      tester.view.physicalSize = Size(width, 900);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      final storage = await StorageService.init();
      final provider = ConnectionsProvider(storage);
      await provider.loadConnections();
      await provider.addConnection(person('a'));
      await tester.pumpWidget(
        ChangeNotifierProvider.value(
          value: provider,
          child: MaterialApp(
            home: Scaffold(
              body: Consumer<ConnectionsProvider>(
                builder: (_, p, _) => SingleChildScrollView(
                  child: FollowUpCard(connection: p.connections.first),
                ),
              ),
            ),
          ),
        ),
      );
      await tester.tap(find.text('Set reminder'));
      await tester.pumpAndSettle();
      await tester.enterText(find.byType(TextFormField), 'Send proposal');
      await tester.tap(find.text('Save'));
      await tester.pumpAndSettle();
      expect(provider.pendingFollowUps.single.followUpNote, 'Send proposal');
      await tester.tap(find.text('Snooze to tomorrow'));
      await tester.pumpAndSettle();
      expect(provider.pendingFollowUps.single.followUpAt!.hour, 9);
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(
        ChangeNotifierProvider.value(
          value: provider,
          child: const MaterialApp(home: FollowUpsScreen()),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.text('Priya a'), findsOneWidget);
      await tester.tap(find.text('Complete'));
      await tester.pumpAndSettle();
      expect(find.textContaining('No pending follow-ups'), findsOneWidget);
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox());
      provider.dispose();
    });
  }
}
