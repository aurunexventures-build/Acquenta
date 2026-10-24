import 'package:flutter/material.dart';
import '../services/conversation_audio_activity.dart';

class ConversationListeningIndicator extends StatelessWidget {
  final ConversationAudioActivitySource source;
  const ConversationListeningIndicator({super.key, required this.source});
  @override
  Widget build(
    BuildContext context,
  ) => ValueListenableBuilder<ConversationAudioActivity>(
    valueListenable: source.activity,
    builder: (context, value, _) {
      if (value.phase == ConversationAudioPhase.idle) {
        return const SizedBox.shrink();
      }
      final transcribing = value.phase == ConversationAudioPhase.transcribing;
      final level = value.level.clamp(0.0, 1.0);
      return Semantics(
        liveRegion: true,
        label: transcribing
            ? 'Transcribing your reply'
            : 'Listening, microphone active',
        child: Container(
          key: const ValueKey('conversation-audio-activity'),
          margin: const EdgeInsets.fromLTRB(16, 4, 16, 8),
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
          decoration: BoxDecoration(
            color: const Color(0xFFEEE9FA),
            borderRadius: BorderRadius.circular(18),
          ),
          child: Row(
            children: [
              SizedBox(
                width: 76,
                height: 38,
                child: transcribing
                    ? const Center(
                        child: SizedBox(
                          width: 22,
                          height: 22,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        ),
                      )
                    : Row(
                        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                        children: List.generate(
                          7,
                          (i) => AnimatedContainer(
                            key: ValueKey('listening-bar-$i'),
                            duration: const Duration(milliseconds: 120),
                            width: 5,
                            height: 6 + level * [12, 22, 30, 32, 30, 22, 12][i],
                            decoration: BoxDecoration(
                              color: const Color(0xFF2563EB),
                              borderRadius: BorderRadius.circular(4),
                            ),
                          ),
                        ),
                      ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  transcribing
                      ? 'Transcribing your reply…'
                      : 'Listening… speak naturally',
                  style: Theme.of(context).textTheme.bodyMedium,
                ),
              ),
            ],
          ),
        ),
      );
    },
  );
}
