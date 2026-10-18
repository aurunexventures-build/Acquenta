import 'package:contact_card_builder/screens/card_scanner_screen.dart';
import 'package:contact_card_builder/providers/cards_provider.dart';
import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:contact_card_builder/models/event_context.dart';
import 'package:contact_card_builder/models/saved_connection.dart';
import 'package:contact_card_builder/providers/connections_provider.dart';
import 'package:contact_card_builder/services/storage_service.dart';
import 'package:contact_card_builder/services/contact_import_service.dart';
import 'package:contact_card_builder/services/duplicate_service.dart';
import 'package:contact_card_builder/services/card_ocr_service.dart';
import 'package:contact_card_builder/services/reminder_notifications.dart';
import 'package:contact_card_builder/screens/contact_import_screen.dart';
import 'package:contact_card_builder/screens/duplicate_contacts_screen.dart';

SavedConnection contact(
  String id, {
  String name = 'Priya',
  String email = '',
  String phone = '',
  String company = '',
}) => SavedConnection(
  id: id,
  fullName: name,
  email: email,
  phone: phone,
  company: company,
  eventContext: EventContext(eventName: 'Meetup', date: DateTime(2026)),
  savedAt: DateTime(2026),
);

class FakeNotifications implements ReminderNotificationBackend {
  @override
  bool supported = true;
  bool allowed = true, fail = false;
  int cancelled = 0;
  final scheduled = <int, DateTime>{};
  Completer<bool>? permission;
  @override
  Future<bool> requestPermission() async => permission?.future ?? allowed;
  @override
  Future<void> cancelAll() async {
    cancelled++;
    scheduled.clear();
  }

  @override
  Future<void> schedule(int id, DateTime at) async {
    if (fail) throw StateError('OS unavailable');
    scheduled[id] = at;
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUp(() => SharedPreferences.setMockInitialValues({}));
  test(
    'CSV preserves quoted text, Unicode, leading zeros and reports incomplete rows',
    () {
      final result = ContactImportService.parse(
        '\uFEFFName,Email,Phone,Notes\r\n"Priya, Patel",PRIYA@example.com,0123456789,"Coffee\r\nand robotics"\r\n,missing@example.com,,\r\n',
      );
      expect(result.contacts.single.fullName, 'Priya, Patel');
      expect(result.contacts.single.phone, '0123456789');
      expect(result.contacts.single.eventContext.notes, 'Coffee\nand robotics');
      expect(result.warnings.length, 1);
      expect(() => ContactImportService.parse(''), throwsFormatException);
      expect(
        () => ContactImportService.parse('x' * 1000001),
        throwsFormatException,
      );
      expect(
        () => ContactImportService.parse('Unknown\nSomething'),
        throwsFormatException,
      );
    },
  );
  test('multiple vCards import with folding and incomplete-card warning', () {
    final result = ContactImportService.parse(
      'BEGIN:VCARD\nVERSION:3.0\nFN:Élodie\nEMAIL:elodie@\n example.com\nEND:VCARD\nBEGIN:VCARD\nFN:Other\nEND:VCARD\nBEGIN:VCARD\nFN:Broken',
    );
    expect(result.contacts.length, 2);
    expect(result.contacts.first.email, 'elodie@example.com');
    expect(result.warnings.length, 1);
  });
  test('duplicate matching avoids name-only and short-phone matches', () {
    expect(
      DuplicateService.reason(
        contact('a', email: ' PRIYA@EXAMPLE.COM '),
        contact('b', email: 'priya@example.com'),
      ),
      isNotNull,
    );
    expect(
      DuplicateService.reason(
        contact('a', phone: '+44 123 456 789'),
        contact('b', phone: '0044123456789'),
      ),
      isNotNull,
    );
    expect(
      DuplicateService.reason(
        contact('a', phone: '123'),
        contact('b', phone: '123'),
      ),
      isNull,
    );
    expect(DuplicateService.reason(contact('a'), contact('b')), isNull);
    expect(
      DuplicateService.reason(
        contact('a', company: ' Studio '),
        contact('b', company: 'studio'),
      ),
      isNotNull,
    );
  });
  test(
    'merge keeps chosen values and archives conflicting private details',
    () {
      final due = DateTime.now().add(const Duration(days: 2));
      final a = contact('a', email: 'keep@example.com').copyWith(
        rawCue: 'Keep cue',
        followUpAt: due,
        followUpNote: 'Keep reminder',
      );
      final b = contact('b', email: 'other@example.com', phone: '123456789')
          .copyWith(
            rawCue: 'Other cue',
            followUpAt: due,
            followUpNote: 'Other reminder',
          );
      final merged = DuplicateService.merge(a, b);
      expect(merged.id, 'a');
      expect(merged.email, 'keep@example.com');
      expect(merged.phone, '123456789');
      expect(merged.rawCue, 'Keep cue');
      expect(merged.followUpNote, 'Keep reminder');
      expect(merged.interactions.single.text, contains('Other reminder'));
      expect(merged.interactions.single.text, contains('Other cue'));
    },
  );
  test(
    'saved merge removes source with sync tombstone and rejects stale preview',
    () async {
      final storage = await StorageService.init();
      final p = ConnectionsProvider(storage);
      await p.loadConnections();
      addTearDown(p.dispose);
      await p.addConnection(contact('a', email: 'same@example.com'));
      await p.addConnection(contact('b', email: 'same@example.com'));
      final a = p.connections.firstWhere((c) => c.id == 'a'),
          b = p.connections.firstWhere((c) => c.id == 'b');
      await p.mergeConnections(a, b);
      expect(p.connections.length, 1);
      expect(storage.loadDeletions().single['id'], 'b');
      await expectLater(p.mergeIncoming(a, contact('c')), throwsStateError);
    },
  );
  test(
    'OCR extraction handles email and formatted phone without inventing company',
    () {
      final fields = CardOcrService.extract(
        'Priya Patel\nStudio\npriya@example.com\n+44 (20) 1234 5678',
      );
      expect(fields['fullName'], 'Priya Patel');
      expect(fields['email'], 'priya@example.com');
      expect(fields['phone'], contains('1234 5678'));
      expect(fields.containsKey('company'), false);
      expect(CardOcrService.extract('')['fullName'], '');
    },
  );
  test(
    'notifications require opt-in, cancel on account switch, and cap future alerts',
    () async {
      final backend = FakeNotifications(),
          service = ReminderNotifications(backend: FakeNotifications());
      final notices = ReminderNotifications(backend: backend);
      final now = DateTime.now();
      final records = List.generate(
        70,
        (i) => contact(
          'p-$i',
        ).copyWith(followUpAt: now.add(Duration(days: i + 1))),
      );
      await notices.refresh('alice', records);
      expect(backend.scheduled, isEmpty);
      expect(await notices.setEnabled(true, 'alice', records), true);
      expect(backend.scheduled.length, 60);
      await notices.refresh('bob', []);
      expect(backend.scheduled, isEmpty);
      expect(notices.enabled, false);
      await notices.refresh('alice', [
        records.first.copyWith(followUpCompleted: true),
      ]);
      expect(backend.scheduled, isEmpty);
      await notices.setEnabled(false, 'alice', records);
      expect(notices.enabled, false);
      expect(backend.scheduled, isEmpty);
      backend.allowed = false;
      expect(await service.setEnabled(false, 'other', []), true);
    },
  );
  test(
    'permission denial, OS failure and account change during permission are safe',
    () async {
      final backend = FakeNotifications()..allowed = false;
      final service = ReminderNotifications(backend: backend);
      expect(await service.setEnabled(true, 'alice', []), false);
      expect(service.status, contains('not allowed'));
      backend.allowed = true;
      backend.fail = true;
      await service.setEnabled(true, 'alice', [
        contact(
          'a',
        ).copyWith(followUpAt: DateTime.now().add(const Duration(days: 1))),
      ]);
      expect(service.status, contains('unavailable'));
      backend.permission = Completer<bool>();
      final enabling = service.setEnabled(true, 'alice', []);
      await service.refresh('bob', []);
      backend.permission!.complete(true);
      expect(await enabling, false);
      expect(service.enabled, false);
    },
  );
  testWidgets(
    'scanner supports reviewed manual entry and rejects an empty name',
    (tester) async {
      tester.view.physicalSize = const Size(390, 900);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      final storage = await StorageService.init();
      final p = ConnectionsProvider(storage);
      final cards = CardsProvider(storage);
      await p.loadConnections();
      await cards.loadCards();
      await tester.pumpWidget(
        MultiProvider(
          providers: [
            ChangeNotifierProvider.value(value: p),
            ChangeNotifierProvider.value(value: cards),
          ],
          child: const MaterialApp(home: CardScannerScreen()),
        ),
      );
      await tester.ensureVisible(find.text('Save reviewed contact'));
      await tester.tap(find.text('Save reviewed contact'));
      await tester.pumpAndSettle();
      expect(p.connections, isEmpty);
      expect(find.textContaining('missing or oversized'), findsOneWidget);
      await tester.ensureVisible(find.byType(TextField).first);
      await tester.enterText(find.byType(TextField).first, 'Scanned Priya');
      await tester.ensureVisible(find.text('Save reviewed contact'));
      await tester.tap(find.text('Save reviewed contact'));
      await tester.pumpAndSettle();
      expect(p.connections.single.fullName, 'Scanned Priya');
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox());
      p.dispose();
      cards.dispose();
    },
  );

  for (final width in [390.0, 1440.0]) {
    testWidgets('review imports and merge duplicate details at $width', (
      tester,
    ) async {
      tester.view.physicalSize = Size(width, 900);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      final storage = await StorageService.init();
      final p = ConnectionsProvider(storage);
      await p.loadConnections();
      await tester.pumpWidget(
        ChangeNotifierProvider.value(
          value: p,
          child: const MaterialApp(home: ContactImportScreen()),
        ),
      );
      await tester.enterText(
        find.byType(TextField),
        'Name,Email\nPriya,priya@example.com\nOther,other@example.com',
      );
      await tester.tap(find.text('Preview import'));
      await tester.pumpAndSettle();
      expect(p.connections, isEmpty);
      await tester.ensureVisible(find.text('Import selected'));
      await tester.tap(find.text('Import selected'));
      await tester.pumpAndSettle();
      expect(p.connections.length, 2);
      await p.addConnection(
        contact('third', email: 'priya@example.com', name: 'Priya duplicate'),
      );
      await tester.pumpWidget(
        ChangeNotifierProvider.value(
          value: p,
          child: const MaterialApp(home: DuplicateContactsScreen()),
        ),
      );
      await tester.pumpAndSettle();
      await tester.tap(find.text('Keep Priya'));
      await tester.pumpAndSettle();
      expect(find.text('Merge these contacts?'), findsOneWidget);
      await tester.tap(find.text('Merge'));
      await tester.pumpAndSettle();
      expect(p.connections.length, 2);
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox());
      p.dispose();
    });
  }
}
