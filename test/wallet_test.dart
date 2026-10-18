import 'dart:convert';
import 'package:qr_flutter/qr_flutter.dart';
import 'package:contact_card_builder/widgets/interactive_card_view.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:provider/provider.dart';
import 'package:contact_card_builder/models/card_link.dart';
import 'package:contact_card_builder/models/contact_card.dart';
import 'package:contact_card_builder/models/event_context.dart';
import 'package:contact_card_builder/models/saved_connection.dart';
import 'package:contact_card_builder/services/auth_service.dart';
import 'package:contact_card_builder/services/card_exchange_service.dart';
import 'package:contact_card_builder/services/search_service.dart';
import 'package:contact_card_builder/services/storage_service.dart';
import 'package:contact_card_builder/services/vcard_service.dart';
import 'package:contact_card_builder/providers/connections_provider.dart';
import 'package:contact_card_builder/providers/cards_provider.dart';
import 'package:contact_card_builder/screens/receive_card_screen.dart';
import 'package:contact_card_builder/screens/connection_detail_screen.dart';
import 'package:contact_card_builder/widgets/voice_capture_dialog.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUp(() => SharedPreferences.setMockInitialValues({}));
  final now = DateTime.utc(2026, 10, 17);
  ContactCard card() => ContactCard(
    id: 'card-real',
    title: 'Creative',
    fullName: 'Priya, Designer; London',
    company: 'Studio\nLondon',
    phone: '+44 123',
    email: 'priya@example.com',
    techStack: ['Branding', 'Design, systems'],
    links: [
      const CardLink(
        id: 'linkedin',
        title: 'LinkedIn',
        url: 'https://linkedin.com/in/priya',
        type: LinkType.linkedin,
      ),
    ],
    createdAt: now,
    updatedAt: now,
  );
  SavedConnection connection() => SavedConnection(
    id: 'person',
    fullName: 'Priya',
    eventContext: EventContext(eventName: 'Design Talk', date: now),
    rawCue: 'Yellow bag; illustrator who can help with packaging',
    distinctiveMemory: 'Yellow bag',
    microContext: 'Beside the stage',
    callWhen: ['Packaging launch'],
    savedAt: now,
  );

  test('new wallets are empty; demo fixtures are opt in', () async {
    final storage = await StorageService.init();
    expect(await storage.loadCards(), isEmpty);
    expect(await storage.loadConnections(), isEmpty);
  });
  test(
    'offline QR preserves Unicode, escaped values, social links and context',
    () {
      final source = card().copyWith(headline: 'Designer 🎨 ${'é' * 90}');
      final vcard = VCardService.generateVCard(
        card: source,
        eventContext: EventContext(
          eventName: 'Creative Night',
          location: 'London',
          date: now,
          notes: 'Discussed packaging',
        ),
      );
      for (final line in vcard.split('\r\n')) {
        expect(utf8.encode(line).length, lessThanOrEqualTo(75));
      }
      final received = CardExchangeService.parseVCard(vcard);
      expect(received.fullName, source.fullName);
      expect(received.company, source.company);
      expect(received.headline, source.headline);
      expect(received.links.single.url, source.links.single.url);
      expect(received.techStack, source.techStack);
      expect(received.eventContext.eventName, 'Creative Night');
      expect(received.eventContext.notes, contains('Discussed packaging'));
      expect(received.rawCue, isEmpty);
    },
  );
  testWidgets(
    'the main card flip uses an offline contact QR rather than an unpublished URL',
    (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: SingleChildScrollView(
              child: InteractiveCardView(card: card(), isExpanded: true),
            ),
          ),
        ),
      );
      await tester.tap(find.byTooltip('Flip for QR Code'));
      await tester.pumpAndSettle();
      final qr = tester.widget<QrImageView>(find.byType(QrImageView));
      final painted =
          tester
                  .widgetList<CustomPaint>(
                    find.descendant(
                      of: find.byType(QrImageView),
                      matching: find.byType(CustomPaint),
                    ),
                  )
                  .firstWhere((w) => w.painter is QrPainter)
                  .painter
              as QrPainter;
      final expected = QrPainter(
        data: VCardService.generateVCard(card: card()),
        version: QrVersions.auto,
        errorCorrectionLevel: qr.errorCorrectionLevel,
        gapless: qr.gapless,
        eyeStyle: qr.eyeStyle,
        dataModuleStyle: qr.dataModuleStyle,
      );
      await tester.runAsync(() async {
        final actualPixels = await painted.toImageData(200);
        final expectedPixels = await expected.toImageData(200);
        expect(
          actualPixels!.buffer.asUint8List(),
          expectedPixels!.buffer.asUint8List(),
        );
      });
      expect(tester.takeException(), isNull);
    },
  );
  test('repeat scans preserve recipient cues and never duplicate', () async {
    final storage = await StorageService.init();
    final provider = ConnectionsProvider(storage);
    await provider.loadConnections();
    final received = CardExchangeService.parseVCard(
      VCardService.generateVCard(card: card()),
    );
    await provider.addConnection(received);
    await provider.updateConnection(
      received.copyWith(rawCue: 'Met beside the stage'),
    );
    await provider.addConnection(received);
    expect(provider.connections.length, 1);
    expect(provider.connections.single.rawCue, 'Met beside the stage');
    provider.dispose();
  });
  test('every cue survives local roundtrip and can be found offline', () async {
    final storage = await StorageService.init();
    await storage.saveConnections([connection()]);
    final saved = (await storage.loadConnections()).single;
    expect(saved.toJson(), connection().toJson());
    for (final query in [
      'yellow bag',
      'illustrator',
      'beside the stage',
      'packaging launch',
    ]) {
      expect(
        SearchService.search(
          connections: [saved],
          query: query,
        ).first.connection.id,
        'person',
      );
    }
  });
  test(
    'guest claim, sign out and switching accounts isolate wallet and deletions',
    () async {
      final storage = await StorageService.init();
      await storage.saveConnections([connection()]);
      await storage.activateAccount('alice');
      expect((await storage.loadConnections()).length, 1);
      await storage.markDeleted('connection', 'deleted', now);
      await storage.activateAccount(null);
      expect(await storage.loadConnections(), isEmpty);
      expect(storage.loadDeletions(), isEmpty);
      await storage.activateAccount('bob');
      expect(await storage.loadConnections(), isEmpty);
      expect(storage.loadDeletions(), isEmpty);
      await storage.activateAccount('alice');
      expect(
        (await storage.loadConnections()).single.rawCue,
        connection().rawCue,
      );
      expect(storage.loadDeletions().single['id'], 'deleted');
    },
  );
  test('arbitrary URLs and malformed card imports are rejected', () async {
    for (final input in [
      'hello',
      'https://example.com/c/aaaaaaaaaaaaaaaaaaaa',
      'BEGIN:VCARD\nEND:VCARD',
    ]) {
      await expectLater(
        CardExchangeService.decode(input),
        throwsFormatException,
      );
    }
  });
  testWidgets(
    'rough cue can be saved without AI or microphone access on a narrow screen',
    (tester) async {
      tester.view.physicalSize = const Size(390, 844);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      SavedConnection? saved;
      await tester.pumpWidget(
        ChangeNotifierProvider(
          create: (_) => AuthService(),
          child: MaterialApp(
            home: Scaffold(
              body: VoiceCaptureDialog(
                onCaptured: (c) {
                  saved = c;
                },
              ),
            ),
          ),
        ),
      );
      await tester.enterText(
        find.widgetWithText(TextField, 'Name'),
        'Designer with yellow bag',
      );
      await tester.enterText(
        find.widgetWithText(TextField, 'Say it in your own words'),
        'Helps with packaging; met after the design talk',
      );
      await tester.ensureVisible(find.text('Save'));
      await tester.tap(find.text('Save'));
      await tester.pumpAndSettle();
      expect(saved?.rawCue, contains('packaging'));
      expect(saved?.eventContext.notes, contains('packaging'));
      expect(tester.takeException(), isNull);
    },
  );
  testWidgets(
    'newly received cards offer optional memory; repeat scans do not prompt again',
    (tester) async {
      final storage = await StorageService.init();
      final people = ConnectionsProvider(storage);
      addTearDown(people.dispose);
      await people.loadConnections();
      for (var scan = 0; scan < 2; scan++) {
        await tester.pumpWidget(
          MultiProvider(
            providers: [
              ChangeNotifierProvider.value(value: people),
              ChangeNotifierProvider(create: (_) => CardsProvider(storage)),
              ChangeNotifierProvider(create: (_) => AuthService()),
            ],
            child: MaterialApp(
              key: ValueKey(scan),
              home: const ReceiveCardScreen(enableCamera: false),
            ),
          ),
        );
        await tester.pumpAndSettle();
        expect(find.text('Import contacts'), findsNothing);
        expect(find.text('Scan paper card'), findsNothing);
        await tester.tap(find.byTooltip('More options'));
        await tester.pumpAndSettle();
        await tester.tap(find.text('Paste card link'));
        await tester.pumpAndSettle();
        await tester.enterText(
          find.byType(TextField),
          VCardService.generateVCard(card: card()),
        );
        await tester.ensureVisible(find.text('Read card'));
        await tester.tap(find.text('Read card'));
        await tester.pumpAndSettle();
        await tester.ensureVisible(find.text('Save to my wallet'));
        await tester.tap(find.text('Save to my wallet'));
        await tester.pumpAndSettle();
        if (scan == 0) {
          expect(find.text('Saved to your wallet'), findsOneWidget);
          expect(find.text('Add a cue'), findsOneWidget);
          await tester.tap(find.text('Later'));
          await tester.pumpAndSettle();
        } else {
          expect(find.text('Saved to your wallet'), findsNothing);
          expect(find.text('Add a cue'), findsNothing);
        }
        expect(find.byType(ConnectionDetailScreen), findsOneWidget);
        expect(people.connections, hasLength(1));
        expect(people.connections.single.fullName, card().fullName);
        expect(tester.takeException(), isNull);
      }
    },
  );
}
