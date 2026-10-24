import 'package:flutter_test/flutter_test.dart';
import 'package:contact_card_builder/services/card_conversation_voice.dart';

void main() {
  test('prefers enhanced male over default male and premium female', () {
    final voice = preferredCardVoice([
      {
        'name': 'Female',
        'gender': 'female',
        'locale': 'en-GB',
        'quality': 'premium',
      },
      {
        'name': 'Default',
        'gender': 'male',
        'locale': 'en-GB',
        'quality': 'default',
      },
      {
        'name': 'Enhanced',
        'gender': 'male',
        'locale': 'en-US',
        'quality': 'enhanced',
      },
    ]);
    expect(voice?['name'], 'Enhanced');
  });
  test('does not silently substitute female or another language', () {
    expect(
      preferredCardVoice([
        {'gender': 'female', 'locale': 'en-GB'},
        {'gender': 'male', 'locale': 'fr-FR'},
      ]),
      isNull,
    );
    expect(preferredCardVoice([]), isNull);
  });
  test(
    'browser voices can use explicit male labels without gender metadata',
    () {
      expect(
        preferredCardVoice([
          {'name': 'Google UK English Female', 'locale': 'en-GB'},
          {'name': 'Google UK English Male', 'locale': 'en-GB'},
        ], browser: true)?['name'],
        'Google UK English Male',
      );
      expect(
        preferredCardVoice([
          {'name': 'Daniel', 'locale': 'en-GB'},
        ], browser: true)?['name'],
        'Daniel',
      );
      expect(
        preferredCardVoice([
          {'name': 'Unknown', 'locale': 'en-GB'},
        ], browser: true),
        isNull,
      );
      expect(
        preferredCardVoice([
          {'name': 'Google UK English Female', 'locale': 'en-GB'},
        ], browser: true),
        isNull,
      );
      expect(
        preferredCardVoice([
          {'name': 'Daniel', 'gender': 'female', 'locale': 'en-GB'},
        ], browser: true),
        isNull,
      );
    },
  );
}
