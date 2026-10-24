import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:contact_card_builder/screens/profile_questionnaire.dart';
import 'aai_test_helpers.dart';

void main() {
  testWidgets(
    'brief chat confirms the name locally then asks work and remembers understood details',
    (tester) async {
      final voice = FakeCardVoice();
      final requests = <Map<String, String>>[];
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: ProfileQuestionnaire(
              voice: voice,
              understandReplies: true,
              briefConversation: true,
              profileName: 'Sam',
              generate: (body) async {
                requests.add(body);
                return {
                  'answers': [
                    'Florist card',
                    'Professional',
                    'Sam',
                    'Florist',
                    'I create wedding flowers.',
                    null,
                    'Couples',
                  ],
                  'context': {
                    'answers': [
                      'Florist card',
                      'Professional',
                      'Sam',
                      'Florist',
                      'I create wedding flowers.',
                      null,
                      'Couples',
                    ],
                    'skills': [],
                    'company': '',
                  },
                  'next': 5,
                  'question':
                      'What skills or specialties would you like to highlight?',
                  'card': null,
                };
              },
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(voice.spoken.single, contains('Your profile name is Sam.'));
      voice.result!('Yes, use the same name', true);
      await tester.pump(const Duration(seconds: 3));
      await tester.pumpAndSettle();
      expect(requests, isEmpty); // A simple confirmation needs no text model.
      expect(voice.spoken.last, contains('Tell me what you do'));
      voice.result!(
        'A work card. I am a florist creating wedding flowers for couples.',
        true,
      );
      await tester.pump(const Duration(milliseconds: 2999));
      expect(requests, isEmpty);
      await tester.pump(const Duration(milliseconds: 1));
      await tester.pumpAndSettle();
      expect(requests, hasLength(1));
      expect(requests.single['conversationStyle'], 'brief');
      expect(requests.single['profileName'], 'Sam');
      expect(
        voice.spoken.last,
        'What skills or specialties would you like to highlight?',
      );
      expect(requests.single['conversationVersion'], '3');
      voice.result!('Floral design', true);
      await tester.pump(const Duration(seconds: 3));
      await tester.pumpAndSettle();
      expect(requests, hasLength(2));
      expect(requests.last['previousDraft'], contains('Florist'));
      expect(find.text('What should we name your card?'), findsNothing);
      expect(tester.takeException(), isNull);
    },
  );
}
