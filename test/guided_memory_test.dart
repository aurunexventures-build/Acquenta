import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:contact_card_builder/models/event_context.dart';
import 'package:contact_card_builder/models/saved_connection.dart';
import 'package:contact_card_builder/services/auth_service.dart';
import 'package:contact_card_builder/services/sync_service.dart';
import 'package:contact_card_builder/widgets/voice_capture_dialog.dart';
import 'sync_search_test.dart' show TestAuth;

class MemoryInterview extends SyncService {
  final calls = <List<Map<String, String>>>[];
  @override
  Future<Map<String, dynamic>> generateCues(
    String text,
    String event,
    AuthService auth, {
    List<Map<String, String>> conversation = const [],
    bool askFollowUp = true,
  }) async {
    calls.add(conversation.map((t) => Map<String, String>.from(t)).toList());
    return {
      'cues': {
        'fullName': 'Incorrect Name',
        'role': 'Incorrect Role',
        'company': 'Incorrect Company',
        'skills': ['Invented Skill'],
        'summary': 'Discussed a design project',
        'distinctiveMemory': conversation.isEmpty
            ? ''
            : conversation.last['answer'],
        'followUpQuestion': 'What stood out about them?',
      },
    };
  }
}

SavedConnection sample() => SavedConnection(
  id: 'memory',
  fullName: 'Chloe Demo',
  role: 'Designer',
  company: 'Studio',
  techStack: ['Design'],
  eventContext: EventContext(
    eventName: 'Meetup',
    date: DateTime(2026),
    notes: 'Earlier discussion',
  ),
  savedAt: DateTime(2026),
);
void main() {
  testWidgets(
    'guided memory follows up, avoids repeating and reviews before saving',
    (tester) async {
      tester.view.physicalSize = const Size(393, 1000);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      final service = MemoryInterview(), auth = TestAuth();
      SavedConnection? saved;
      await tester.pumpWidget(
        ChangeNotifierProvider<AuthService>.value(
          value: auth,
          child: MaterialApp(
            home: Scaffold(
              body: VoiceCaptureDialog(
                guided: true,
                connection: sample(),
                service: service,
                onCaptured: (c) => saved = c,
              ),
            ),
          ),
        ),
      );
      await tester.enterText(
        find.widgetWithText(TextField, 'Say it in your own words'),
        'We discussed a design project',
      );
      await tester.ensureVisible(find.text('Continue'));
      await tester.tap(find.text('Continue'));
      await tester.pumpAndSettle();
      expect(find.text('What stood out about them?'), findsOneWidget);
      expect(saved, isNull);
      await tester.enterText(
        find.widgetWithText(TextField, 'Your reply'),
        'Red backpack',
      );
      await tester.ensureVisible(find.text('Send reply'));
      await tester.tap(find.text('Send reply'));
      await tester.pumpAndSettle();
      expect(find.widgetWithText(TextField, 'Your reply'), findsNothing);
      expect(service.calls.last.single['answer'], 'Red backpack');
      await tester.ensureVisible(
        find.widgetWithText(TextField, 'What you discussed'),
      );
      await tester.enterText(
        find.widgetWithText(TextField, 'What you discussed'),
        'Reviewed by me',
      );
      await tester.ensureVisible(find.text('Save'));
      await tester.tap(find.text('Save'));
      await tester.pumpAndSettle();
      expect(saved?.fullName, 'Chloe Demo');
      expect(saved?.role, 'Designer');
      expect(saved?.company, 'Studio');
      expect(saved?.techStack, ['Design']);
      expect(saved?.eventContext.notes, 'Reviewed by me');
      expect(saved?.cueConversation.single['answer'], 'Red backpack');
      expect(tester.takeException(), isNull);
    },
  );
  testWidgets('direct note edits need no AI and preserve shared skills', (
    tester,
  ) async {
    SavedConnection? saved;
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: VoiceCaptureDialog(
            editOnly: true,
            connection: sample(),
            onCaptured: (c) => saved = c,
          ),
        ),
      ),
    );
    await tester.ensureVisible(
      find.widgetWithText(TextField, 'What you discussed'),
    );
    await tester.enterText(
      find.widgetWithText(TextField, 'What you discussed'),
      'Updated later',
    );
    await tester.ensureVisible(find.text('Save'));
    await tester.tap(find.text('Save'));
    await tester.pumpAndSettle();
    expect(saved?.eventContext.notes, 'Updated later');
    expect(saved?.techStack, ['Design']);
    expect(saved?.fullName, 'Chloe Demo');
    expect(tester.takeException(), isNull);
  });
}
