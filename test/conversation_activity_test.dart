import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:contact_card_builder/services/conversation_audio_activity.dart';
import 'package:contact_card_builder/services/conversation_screen_awake.dart';
import 'package:contact_card_builder/widgets/conversation_listening_indicator.dart';

class Activity implements ConversationAudioActivitySource {
  @override
  final ValueNotifier<ConversationAudioActivity> activity = ValueNotifier(
    const ConversationAudioActivity(ConversationAudioPhase.listening),
  );
}

void main() {
  testWidgets(
    'audio bars respond to the microphone and switch to transcription',
    (tester) async {
      final source = Activity();
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(body: ConversationListeningIndicator(source: source)),
        ),
      );
      expect(find.text('Listening… speak naturally'), findsOneWidget);
      final quiet = tester
          .widget<AnimatedContainer>(
            find.byKey(const ValueKey('listening-bar-3')),
          )
          .constraints!
          .maxHeight;
      source.activity.value = const ConversationAudioActivity(
        ConversationAudioPhase.listening,
        .9,
      );
      await tester.pumpAndSettle();
      expect(
        tester
            .widget<AnimatedContainer>(
              find.byKey(const ValueKey('listening-bar-3')),
            )
            .constraints!
            .maxHeight,
        greaterThan(quiet),
      );
      source.activity.value = const ConversationAudioActivity(
        ConversationAudioPhase.transcribing,
      );
      await tester.pump();
      expect(find.text('Transcribing your reply…'), findsOneWidget);
      expect(find.byType(CircularProgressIndicator), findsOneWidget);
      source.activity.value = const ConversationAudioActivity(
        ConversationAudioPhase.idle,
      );
      await tester.pump();
      expect(
        find.byKey(const ValueKey('conversation-audio-activity')),
        findsNothing,
      );
      await tester.pumpWidget(const SizedBox());
      source.activity.dispose();
    },
  );
  testWidgets('screen stays awake only for the foreground conversation', (
    tester,
  ) async {
    final changes = <bool>[];
    final awake = ConversationScreenAwake(
      setEnabled: (value) async {
        changes.add(value);
      },
    );
    awake.open();
    await awake.settled;
    expect(changes.last, isTrue);
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.paused);
    await awake.settled;
    expect(changes.last, isFalse);
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
    await awake.settled;
    expect(changes.last, isTrue);
    awake.close();
    await awake.settled;
    expect(changes.last, isFalse);
  });
}
