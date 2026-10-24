import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:contact_card_builder/models/contact_card.dart';
import 'package:contact_card_builder/providers/connections_provider.dart';
import 'package:contact_card_builder/services/storage_service.dart';
import 'package:contact_card_builder/services/nearby_card_service.dart';
import 'package:contact_card_builder/services/vcard_service.dart';
import 'package:contact_card_builder/screens/nearby_exchange_screen.dart';

class FakeNearby implements NearbyCardTransport {
  final controller = StreamController<Map<String, dynamic>>.broadcast();
  bool enabled = true;
  int stops = 0, saves = 0, confirms = 0, declines = 0;
  String? invited, sent;
  @override
  Stream<Map<String, dynamic>> get events => controller.stream;
  void emit(String type, [Map<String, dynamic> fields = const {}]) =>
      controller.add({'type': type, ...fields});
  @override
  Future<bool> available() async => enabled;
  @override
  Future<String> start(bool sending) async => 'Acquenta TEST';
  @override
  Future<void> invite(String id) async {
    invited = id;
    emit('connecting');
  }

  @override
  Future<void> accept(bool accept) async {}
  @override
  Future<void> confirm() async {
    confirms++;
  }

  @override
  Future<void> send(String card) async {
    sent = card;
    emit('sent');
  }

  @override
  Future<void> saved() async {
    saves++;
  }

  @override
  Future<void> decline() async {
    declines++;
  }

  @override
  Future<void> stop() async {
    stops++;
  }

  @override
  Future<void> dispose() async {
    await stop();
    await controller.close();
  }
}

ContactCard sample() => ContactCard(
  id: 'sample',
  fullName: 'Sam',
  role: 'Architect',
  headline: 'I design buildings',
  bio: 'Public introduction',
  avatarUrl: 'portrait:00000000-0000-0000-0000-000000000001',
  createdAt: DateTime(2026),
  updatedAt: DateTime(2026),
);
Future<ConnectionsProvider> mount(
  WidgetTester tester,
  FakeNearby transport, {
  bool sending = true,
}) async {
  SharedPreferences.setMockInitialValues({});
  final storage = await StorageService.init();
  final provider = ConnectionsProvider(storage);
  await provider.loadConnections();
  await tester.pumpWidget(
    ChangeNotifierProvider.value(
      value: provider,
      child: MaterialApp(
        home: NearbyExchangeScreen(
          card: sending ? sample() : null,
          transport: transport,
        ),
      ),
    ),
  );
  await tester.pumpAndSettle();
  return provider;
}

void main() {
  testWidgets(
    'sender requires matching-code confirmation; delivery success requires saved acknowledgement',
    (tester) async {
      final transport = FakeNearby();
      final p = await mount(tester, transport);
      addTearDown(p.dispose);
      transport.emit('found', {'id': 'other', 'name': 'Acquenta PEER'});
      await tester.pumpAndSettle();
      await tester.tap(find.text('Acquenta PEER'));
      await tester.pump(const Duration(milliseconds: 200));
      expect(transport.invited, 'other');
      transport.emit('verification', {
        'code': '123456',
        'name': 'Acquenta PEER',
      });
      await tester.pumpAndSettle();
      expect(find.text('Swipe up or tap to send'), findsNothing);
      await tester.ensureVisible(find.text('Codes match'));
      await tester.tap(find.text('Codes match'));
      await tester.pumpAndSettle();
      expect(transport.confirms, 1);
      expect(find.text('Swipe up or tap to send'), findsNothing);
      transport.emit('ready');
      await tester.pumpAndSettle();
      await tester.ensureVisible(find.text('Swipe up or tap to send'));
      await tester.tap(find.text('Swipe up or tap to send'));
      await tester.pumpAndSettle();
      expect(transport.sent, contains('BEGIN:VCARD'));
      expect(transport.sent, isNot(contains('PORTRAIT')));
      expect(transport.sent, contains('Public introduction'));
      expect(
        find.text('Card sent. Waiting for them to save it…'),
        findsOneWidget,
      );
      expect(find.text('Saved in their wallet'), findsNothing);
      transport.emit('saved');
      await tester.pumpAndSettle();
      expect(find.text('Saved in their wallet'), findsOneWidget);
      await tester.pumpWidget(const SizedBox());
    },
  );
  testWidgets(
    'receiver previews before saving and acknowledges only after local wallet contains the card',
    (tester) async {
      final transport = FakeNearby();
      final p = await mount(tester, transport, sending: false);
      addTearDown(p.dispose);
      transport.emit('card', {
        'card': VCardService.generateVCard(
          card: sample().copyWith(avatarUrl: ''),
        ),
      });
      await tester.pumpAndSettle();
      expect(p.connections, isEmpty);
      expect(transport.saves, 0);
      await tester.ensureVisible(find.text('Save to my wallet'));
      await tester.tap(find.text('Save to my wallet'));
      await tester.pumpAndSettle();
      expect(p.connections.single.fullName, 'Sam');
      expect(transport.saves, 1);
      expect(find.text('Added to your wallet'), findsOneWidget);
      await tester.pumpWidget(const SizedBox());
    },
  );
  testWidgets('nearby refuses a URL payload instead of fetching it', (
    tester,
  ) async {
    final transport = FakeNearby();
    final p = await mount(tester, transport, sending: false);
    addTearDown(p.dispose);
    transport.emit('card', {'card': 'https://example.com/card'});
    await tester.pumpAndSettle();
    expect(p.connections, isEmpty);
    expect(transport.declines, 1);
    expect(find.textContaining('could not be read'), findsOneWidget);
    await tester.pumpWidget(const SizedBox());
  });
  testWidgets(
    'unavailable transport shows honest QR fallback and no peer discovery',
    (tester) async {
      final transport = FakeNearby()..enabled = false;
      final p = await mount(tester, transport);
      addTearDown(p.dispose);
      expect(
        find.textContaining('available in the iPhone app'),
        findsOneWidget,
      );
      expect(find.text('Looking for nearby iPhones…'), findsNothing);
      await tester.pumpWidget(const SizedBox());
    },
  );
}
