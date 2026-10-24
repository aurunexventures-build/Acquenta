import 'package:flutter/foundation.dart';

enum ConversationAudioPhase { idle, listening, transcribing }

class ConversationAudioActivity {
  final ConversationAudioPhase phase;
  final double level;
  const ConversationAudioActivity(this.phase, [this.level = 0]);
}

abstract interface class ConversationAudioActivitySource {
  ValueListenable<ConversationAudioActivity> get activity;
}
