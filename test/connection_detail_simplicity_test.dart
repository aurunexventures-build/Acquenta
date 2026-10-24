import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:contact_card_builder/models/event_context.dart';
import 'package:contact_card_builder/models/saved_connection.dart';
import 'package:contact_card_builder/providers/connections_provider.dart';
import 'package:contact_card_builder/services/storage_service.dart';
import 'package:contact_card_builder/screens/connection_detail_screen.dart';

void main() {
  testWidgets(
    'details stay simple while all notes and skills remain accessible',
    (tester) async {
      tester.view.physicalSize = const Size(320, 900);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      SharedPreferences.setMockInitialValues({});
      final storage = await StorageService.init();
      await storage.saveConnections([
        SavedConnection(
          id: 'zara',
          fullName: 'Zara Demo',
          role: 'AI creator',
          email: 'zara@example.com',
          phone: '+44123456789',
          futureSelfNote: 'Ask about the project',
          distinctiveMemory: 'Red backpack',
          microContext: 'By the stage',
          rawCue: 'Original private memory',
          techStack: ['Design', 'AI', 'Dart', 'Flutter', 'Python', 'Writing'],
          eventContext: EventContext(
            eventName: 'College meetup',
            date: DateTime(2026),
            notes: 'We discussed a robotics club',
          ),
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
            home: ConnectionDetailScreen(connectionId: 'zara'),
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.text('Cognitive Recall Anchors'), findsNothing);
      expect(find.text('Red backpack'), findsNothing);
      expect(find.text('Original private memory'), findsNothing);
      expect(find.text('Call'), findsOneWidget);
      expect(find.text('Email'), findsOneWidget);
      expect(find.text('Talk to Acquenta AI'), findsOneWidget);
      final memory = tester.getRect(
        find.byKey(const ValueKey('add-connection-memory')),
      );
      final export = tester.getRect(
        find.byKey(const ValueKey('export-connection-contact')),
      );
      expect(export.top - memory.bottom, greaterThan(100));
      expect(memory.height, greaterThanOrEqualTo(48));
      await tester.ensureVisible(find.text('+1 more'));
      await tester.tap(find.text('+1 more'));
      await tester.pumpAndSettle();
      expect(find.text('Writing'), findsOneWidget);
      await tester.tap(find.text('Done'));
      await tester.pumpAndSettle();
      await tester.ensureVisible(find.text('Notes & activity'));
      await tester.tap(find.text('Notes & activity'));
      await tester.pumpAndSettle();
      expect(find.text('Red backpack'), findsOneWidget);
      expect(find.text('Original private memory'), findsNothing);
      await tester.ensureVisible(find.text('Original conversation'));
      await tester.tap(find.text('Original conversation'));
      await tester.pumpAndSettle();
      expect(find.text('Original private memory'), findsOneWidget);
      expect(find.text('We discussed a robotics club'), findsOneWidget);
      expect(tester.takeException(), isNull);
    },
  );
}
