import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:provider/provider.dart';
import 'package:contact_card_builder/main.dart';
import 'package:contact_card_builder/services/storage_service.dart';
import 'package:contact_card_builder/services/vcard_service.dart';
import 'package:contact_card_builder/models/contact_card.dart';
import 'package:contact_card_builder/models/card_link.dart';
import 'package:contact_card_builder/widgets/visiting_card_deck.dart';
import 'package:contact_card_builder/providers/connections_provider.dart';
import 'package:contact_card_builder/models/saved_connection.dart';
import 'package:contact_card_builder/models/event_context.dart';
import 'package:contact_card_builder/screens/connection_detail_screen.dart';

void main() {
  setUp(() => SharedPreferences.setMockInitialValues({}));
  for (final size in [const Size(360, 780), const Size(1100, 800)]) {
    testWidgets('QR aligns with heading right edge at $size', (tester) async {
      tester.view.physicalSize = size;
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      final storage = await StorageService.init();
      await storage.setOnboardingCompleted(true);
      await storage.addDemoIdentityCardsOnce();
      await tester.pumpWidget(
        ContactCardBuilderApp(storageService: storage, requireSignIn: false),
      );
      await tester.pumpAndSettle();
      final heading = tester.getRect(
        find.byKey(const ValueKey('wallet-heading')),
      );
      final qr = tester.getRect(find.byTooltip('Receive a card'));
      expect(qr.right, closeTo(heading.right, 8));
      expect(tester.takeException(), isNull);
    });
  }
  testWidgets(
    'primary card sizes to content and shows location and social link',
    (tester) async {
      final c = ContactCard(
        id: 'qa',
        title: 'Work',
        fullName: 'Alex',
        role: 'Developer',
        location: 'London',
        links: [
          CardLink(
            id: 'linkedin',
            title: 'LinkedIn',
            type: LinkType.linkedin,
            url: 'https://linkedin.com/in/alex',
          ),
        ],
        createdAt: DateTime(2026),
        updatedAt: DateTime(2026),
      );
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: VisitingCardDeck(
              entries: [WalletEntry.own(c, onOpen: () {})],
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.text('London'), findsOneWidget);
      expect(find.textContaining('linkedin.com/in/alex'), findsNothing);
      expect(find.byTooltip('LinkedIn'), findsOneWidget);
      expect(
        tester.getSize(find.byKey(const ValueKey('wallet-card-qa'))).height,
        lessThan(300),
      );
      expect(tester.takeException(), isNull);
    },
  );
  testWidgets('person identity precedes context and activity is collapsed', (
    tester,
  ) async {
    final storage = await StorageService.init();
    await storage.saveConnections([
      SavedConnection(
        id: 'person',
        fullName: 'Jamie QA',
        role: 'Developer',
        email: 'jamie@example.com',
        rawCue: 'Blue jacket',
        eventContext: EventContext(eventName: 'Meetup', date: DateTime(2026)),
        savedAt: DateTime(2026),
      ),
    ]);
    final provider = ConnectionsProvider(storage);
    await provider.loadConnections();
    addTearDown(provider.dispose);
    await tester.pumpWidget(
      ChangeNotifierProvider.value(
        value: provider,
        child: const MaterialApp(
          home: ConnectionDetailScreen(connectionId: 'person'),
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(
      tester.getTopLeft(find.text('Jamie QA').last).dy,
      lessThan(tester.getTopLeft(find.text('Contact')).dy),
    );
    expect(find.text('Interaction history'), findsNothing);
    expect(find.text('Your original memory\nBlue jacket'), findsNothing);
    expect(tester.takeException(), isNull);
  });
  test('iOS export opens native contact editor with a real vCard', () async {
    TestWidgetsFlutterBinding.ensureInitialized();
    debugDefaultTargetPlatformOverride = TargetPlatform.iOS;
    addTearDown(() => debugDefaultTargetPlatformOverride = null);
    const channel = MethodChannel('acquenta/contacts');
    MethodCall? received;
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, (call) async {
          received = call;
          return false;
        });
    addTearDown(
      () => TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(channel, null),
    );
    await VCardService.exportContact(
      vcard: 'BEGIN:VCARD\r\nVERSION:3.0\r\nFN:Alex\r\nEND:VCARD\r\n',
      name: 'Alex',
    );
    expect(received!.method, 'saveContact');
    expect((received!.arguments as Map)['vcard'], startsWith('BEGIN:VCARD'));
  });
}
