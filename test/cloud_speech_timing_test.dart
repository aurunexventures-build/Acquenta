import 'package:flutter_test/flutter_test.dart';
import 'package:contact_card_builder/services/cloud_card_conversation_voice.dart';

void main() {
  test(
    'a recorded turn ends after 1.2 seconds and resumed speech resets it',
    () {
      final gate = SpeechTurnSilence();
      final start = DateTime(2026);
      expect(gate.finished(start.add(const Duration(seconds: 10))), isFalse);
      gate.update(-20, start);
      expect(
        gate.finished(start.add(const Duration(milliseconds: 1199))),
        isFalse,
      );
      expect(
        gate.finished(start.add(const Duration(milliseconds: 1200))),
        isTrue,
      );
      gate.update(-18, start.add(const Duration(milliseconds: 1000)));
      gate.update(-65, start.add(const Duration(milliseconds: 2000)));
      expect(
        gate.finished(start.add(const Duration(milliseconds: 2199))),
        isFalse,
      );
      expect(
        gate.finished(start.add(const Duration(milliseconds: 2200))),
        isTrue,
      );
    },
  );
}
