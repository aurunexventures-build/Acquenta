import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:contact_card_builder/widgets/voice_people_search_field.dart';
import 'package:contact_card_builder/widgets/people_card_pile.dart';
import 'package:contact_card_builder/widgets/visiting_card_deck.dart';
import 'aai_test_helpers.dart';

void main() {
  testWidgets('spoken search uses transcription then AI cleanup', (
    tester,
  ) async {
    final voice = FakeCardVoice();
    final controller = TextEditingController();
    final changes = <String>[];
    String? sent;
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: VoicePeopleSearchField(
            controller: controller,
            voice: voice,
            onChanged: changes.add,
            request: (_, _) async => {},
            organise: (raw) async {
              sent = raw;
              return 'architect Bengaluru';
            },
          ),
        ),
      ),
    );
    await tester.tap(find.byTooltip('Speak to find a familiar face'));
    await tester.pumpAndSettle();
    voice.reply('Find the architect I met in Bengaluru');
    await tester.pumpAndSettle();
    expect(sent, 'Find the architect I met in Bengaluru');
    expect(changes, [
      'Find the architect I met in Bengaluru',
      'architect Bengaluru',
    ]);
    expect(controller.text, 'architect Bengaluru');
    await tester.pumpWidget(const SizedBox());
    controller.dispose();
  });
  testWidgets('typing wins over delayed AI cleanup', (tester) async {
    final voice = FakeCardVoice();
    final controller = TextEditingController();
    final pending = Completer<String>();
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: VoicePeopleSearchField(
            controller: controller,
            voice: voice,
            onChanged: (_) {},
            request: (_, _) async => {},
            organise: (_) => pending.future,
          ),
        ),
      ),
    );
    await tester.tap(find.byTooltip('Speak to find a familiar face'));
    await tester.pumpAndSettle();
    voice.reply('the developer');
    await tester.pump();
    await tester.enterText(find.byType(TextField), 'Mei');
    pending.complete('developer');
    await tester.pumpAndSettle();
    expect(controller.text, 'Mei');
    await tester.pumpWidget(const SizedBox());
    controller.dispose();
  });
  testWidgets('failed AI cleanup keeps the editable transcript', (
    tester,
  ) async {
    final voice = FakeCardVoice();
    final controller = TextEditingController();
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: VoicePeopleSearchField(
            controller: controller,
            voice: voice,
            onChanged: (_) {},
            request: (_, _) async => {},
            organise: (_) async => throw StateError('offline'),
          ),
        ),
      ),
    );
    await tester.tap(find.byTooltip('Speak to find a familiar face'));
    await tester.pumpAndSettle();
    voice.reply('yellow camera');
    await tester.pumpAndSettle();
    expect(controller.text, 'yellow camera');
    expect(
      find.textContaining('Your transcribed words are kept'),
      findsOneWidget,
    );
    await tester.pumpWidget(const SizedBox());
    controller.dispose();
  });
  testWidgets(
    'people stack holds 50 contacts in one scroll area without arrows',
    (tester) async {
      await tester.binding.setSurfaceSize(const Size(390, 1000));
      addTearDown(() => tester.binding.setSurfaceSize(null));
      String? opened;
      final entries = List.generate(
        50,
        (i) => WalletEntry(
          id: '$i',
          name: 'Person $i',
          role: 'Architect',
          onOpen: () => opened = '$i',
        ),
      );
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: SingleChildScrollView(
              child: PeopleCardPile(entries: entries),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      Finder card(String id) => find.byKey(ValueKey('wallet-pile-card-$id'));
      expect(find.byTooltip('Next people'), findsNothing);
      expect(card('49'), findsOneWidget);
      expect(find.byType(PeopleCardPile), findsOneWidget);
      await tester.scrollUntilVisible(card('2'), 500);
      await tester.pumpAndSettle();
      expect(tester.getRect(card('2')).height, 64);
      await tester.tapAt(tester.getCenter(card('2')));
      await tester.pumpAndSettle();
      expect(opened, '2');
      expect(tester.getRect(card('2')).height, 64);
      expect(tester.getRect(card('0')).height, 64);
      expect(card('49'), findsOneWidget);
      expect(find.byTooltip('Previous people'), findsNothing);
    },
  );
}
