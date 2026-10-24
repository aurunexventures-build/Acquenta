import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:contact_card_builder/services/card_conversation_voice.dart';

class SilentCardVoice implements CardConversationVoice {
  final spoken = <String>[];
  bool disposed = false;
  @override
  Future<bool> initialize() async => false;
  @override
  Future<void> speak(String text) async {
    spoken.add(text);
  }

  @override
  Future<void> listen({
    required void Function(String, bool) onResult,
    required VoidCallback onDone,
    required void Function(String) onError,
  }) async {}
  @override
  Future<void> stop() async {}
  @override
  Future<void> dispose() async {
    disposed = true;
  }
}

class FakeCardVoice extends SilentCardVoice {
  void Function(String, bool)? result;
  VoidCallback? done;
  void Function(String)? error;
  bool listening = false;
  @override
  Future<bool> initialize() async => true;
  @override
  Future<void> listen({
    required void Function(String, bool) onResult,
    required VoidCallback onDone,
    required void Function(String) onError,
  }) async {
    result = onResult;
    done = onDone;
    error = onError;
    listening = true;
  }

  @override
  Future<void> stop() async {
    listening = false;
    result = null;
    done = null;
    error = null;
  }

  @override
  Future<void> dispose() async {
    disposed = true;
    await stop();
  }

  void reply(String text) {
    result?.call(text, true);
    done?.call();
  }
}

Future<void> answerCardQuestions(
  WidgetTester tester, {
  String description = 'I create wedding flowers.',
}) async {
  for (final answer in [
    'Wedding work',
    'Professional',
    'Sam Patel',
    'Florist',
    description,
    'Floral design',
    'Couples planning their wedding',
  ]) {
    await tester.enterText(
      find.byKey(const ValueKey('conversation-reply')),
      answer,
    );
    await tester.tap(find.byTooltip('Send reply'));
    await tester.pumpAndSettle();
  }
}
