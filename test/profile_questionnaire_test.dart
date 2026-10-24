import 'dart:async';
import 'aai_test_helpers.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:contact_card_builder/screens/profile_questionnaire.dart';

void main() {
  testWidgets('backgrounding while creating does not leave the card stuck', (
    tester,
  ) async {
    final response = Completer<Map<String, dynamic>>();
    Map<String, dynamic>? applied;
    addTearDown(
      () => tester.binding.handleAppLifecycleStateChanged(
        AppLifecycleState.resumed,
      ),
    );
    await tester.pumpWidget(
      MaterialApp(
        home: Builder(
          builder: (context) => Scaffold(
            body: TextButton(
              onPressed: () async {
                applied = await showDialog<Map<String, dynamic>>(
                  context: context,
                  builder: (_) => ProfileQuestionnaire(
                    voice: SilentCardVoice(),
                    generate: (_) => response.future,
                  ),
                );
              },
              child: const Text('Open'),
            ),
          ),
        ),
      ),
    );
    await tester.tap(find.text('Open'));
    await tester.pumpAndSettle();
    await answerCardQuestions(tester);
    await tester.tap(find.text('Create card'));
    await tester.pump();
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.paused);
    response.complete({'pitch': 'I create flowers.', 'skills': []});
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
    await tester.pumpAndSettle();
    expect(applied, containsPair('createCard', true));
    expect(tester.takeException(), isNull);
  });

  testWidgets(
    'chat keeps all replies, edits an answer and creates only on confirmation',
    (tester) async {
      tester.view.physicalSize = const Size(360, 640);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      final voice = SilentCardVoice();
      Map<String, dynamic>? applied;
      Map<String, String>? sent;
      await tester.pumpWidget(
        MaterialApp(
          home: Builder(
            builder: (context) => Scaffold(
              body: TextButton(
                onPressed: () async {
                  applied = await showDialog<Map<String, dynamic>>(
                    context: context,
                    builder: (_) => ProfileQuestionnaire(
                      voice: voice,
                      generate: (answers) async {
                        sent = answers;
                        return {
                          'pitch': 'Wedding flowers made with care.',
                          'skills': ['Floral design'],
                        };
                      },
                    ),
                  );
                },
                child: const Text('Open'),
              ),
            ),
          ),
        ),
      );
      await tester.tap(find.text('Open'));
      await tester.pumpAndSettle();
      expect(find.byType(TextFormField), findsNothing);
      await tester.tap(find.byTooltip('Send reply'));
      await tester.pumpAndSettle();
      expect(find.text('Add a reply first.'), findsOneWidget);
      await answerCardQuestions(tester);
      expect(sent, isNull);
      expect(applied, isNull);
      expect(find.text('Review your answers'), findsOneWidget);
      await tester.scrollUntilVisible(
        find.byTooltip('Edit Headline'),
        -180,
        scrollable: find.descendant(
          of: find.byKey(const ValueKey('card-conversation')),
          matching: find.byType(Scrollable),
        ),
      );
      await Scrollable.ensureVisible(
        tester.element(find.byTooltip('Edit Headline')),
        alignment: .5,
      );
      await tester.pumpAndSettle();
      await tester.tap(find.byTooltip('Edit Headline'));
      await tester.pumpAndSettle();
      await tester.enterText(
        find.byKey(const ValueKey('conversation-reply')),
        'Wedding flowers made with care.',
      );
      await tester.tap(find.byTooltip('Save answer'));
      await tester.pumpAndSettle();
      await tester.tap(find.byTooltip('Replay conversation'));
      await tester.pumpAndSettle();
      expect(voice.spoken.last, contains('Wedding work'));
      expect(voice.spoken.last, contains('Sam Patel'));
      expect(voice.spoken.last, contains('Wedding flowers made with care.'));
      await tester.tap(find.text('Create card'));
      await tester.pumpAndSettle();
      expect(sent!['work'], contains('Wedding flowers made with care.'));
      expect(applied, containsPair('cardName', 'Wedding work'));
      expect(applied, containsPair('fullName', 'Sam Patel'));
      expect(applied, containsPair('role', 'Florist'));
      expect(applied, containsPair('category', 'professional'));
      expect(applied, containsPair('createCard', true));
      expect(voice.disposed, isTrue);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'voice asks every question and advances without repeated microphone taps',
    (tester) async {
      final voice = FakeCardVoice();
      var requests = 0;
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: ProfileQuestionnaire(
              voice: voice,
              generate: (_) async {
                requests++;
                return {'pitch': 'I create flowers.', 'skills': []};
              },
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(voice.listening, isTrue);
      expect(voice.spoken.single, 'What should we name your card?');
      final oldResult = voice.result!;
      voice.reply('Work');
      await tester.pump(const Duration(milliseconds: 6500));
      await tester.pumpAndSettle();
      oldResult('Stale words from the previous recording', true);
      await tester.pumpAndSettle();
      expect(voice.spoken.last, 'What is this card for?');
      for (final answer in [
        'Professional',
        'Sam Patel',
        'Florist',
        'I create wedding flowers.',
        'Floral design',
        'Couples planning a wedding',
      ]) {
        expect(voice.listening, isTrue);
        voice.reply(answer);
        await tester.pump(const Duration(milliseconds: 6500));
        await tester.pumpAndSettle();
      }
      expect(voice.listening, isFalse);
      expect(find.text('Create card'), findsOneWidget);
      expect(requests, 0);
      expect(
        voice.spoken.length,
        8,
      ); // Seven questions and the spoken review invitation.
      expect(
        find.text('Stale words from the previous recording'),
        findsNothing,
      );
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'voice interruption preserves answers and closing stops the microphone',
    (tester) async {
      final voice = FakeCardVoice();
      await tester.pumpWidget(
        MaterialApp(
          home: Builder(
            builder: (context) => Scaffold(
              body: TextButton(
                onPressed: () => showDialog<void>(
                  context: context,
                  builder: (_) => ProfileQuestionnaire(
                    voice: voice,
                    generate: (_) async => {},
                  ),
                ),
                child: const Text('Open'),
              ),
            ),
          ),
        ),
      );
      await tester.tap(find.text('Open'));
      await tester.pumpAndSettle();
      voice.reply('My work card');
      await tester.pump(const Duration(milliseconds: 6500));
      await tester.pumpAndSettle();
      voice.error!('microphone interrupted');
      await tester.pumpAndSettle();
      expect(find.textContaining('Your answers are kept'), findsOneWidget);
      expect(find.text('My work card'), findsOneWidget);
      await tester.tap(find.byTooltip('Resume voice conversation'));
      await tester.pumpAndSettle();
      expect(voice.listening, isTrue);
      await tester.tap(find.byTooltip('Close'));
      await tester.pumpAndSettle();
      expect(voice.disposed, isTrue);
      expect(voice.listening, isFalse);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets('generation failure keeps the full conversation for retry', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: ProfileQuestionnaire(
            voice: SilentCardVoice(),
            generate: (_) async => throw Exception('offline'),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    await answerCardQuestions(tester, description: 'I teach literacy.');
    await tester.tap(find.text('Create card'));
    await tester.pumpAndSettle();
    expect(find.textContaining('Your answers are still here'), findsOneWidget);
    expect(find.text('Create card'), findsOneWidget);
    await tester.tap(find.byTooltip('Replay conversation'));
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
  });
  testWidgets(
    'AI interprets spoken intent, skips known fields, collects skills and previews before saving',
    (tester) async {
      Map<String, dynamic>? applied;
      final requests = <Map<String, String>>[];
      await tester.pumpWidget(
        MaterialApp(
          home: Builder(
            builder: (context) => Scaffold(
              body: TextButton(
                onPressed: () async {
                  applied = await showDialog<Map<String, dynamic>>(
                    context: context,
                    builder: (_) => ProfileQuestionnaire(
                      voice: SilentCardVoice(),
                      understandReplies: true,
                      generate: (input) async {
                        requests.add(input);
                        final count = requests.length;
                        return {
                          'answers': [
                            'Creative card',
                            'Professional',
                            'Amit Singh',
                            'Senior IT Architect',
                            'I help teams integrate systems.',
                            count >= 2 ? 'System integration' : null,
                            count >= 3 ? 'Engineering teams' : null,
                          ],
                          'next': count == 1
                              ? 5
                              : count == 2
                              ? 6
                              : -1,
                          'question': count == 1
                              ? 'Which skills should we highlight?'
                              : 'Who would you like to connect with?',
                          'card': count < 3
                              ? null
                              : {
                                  'cardName': 'Creative card',
                                  'fullName': 'Amit Singh',
                                  'role': 'Senior IT Architect',
                                  'pitch': 'I help teams integrate systems.',
                                  'skills': ['System integration'],
                                  'bio':
                                      'I design integrations for engineering teams.',
                                  'category': 'professional',
                                },
                        };
                      },
                    ),
                  );
                },
                child: const Text('Open'),
              ),
            ),
          ),
        ),
      );
      await tester.tap(find.text('Open'));
      await tester.pumpAndSettle();
      for (final reply in [
        'You can call it as a creative card. Show it as Amit Singh. I work as a senior IT architect.',
        'My skill is system integration.',
        'Engineering teams.',
      ]) {
        await tester.enterText(
          find.byKey(const ValueKey('conversation-reply')),
          reply,
        );
        await tester.tap(find.byTooltip('Send reply'));
        await tester.pumpAndSettle();
        expect(applied, isNull);
      }
      expect(requests.first['mode'], 'conversation');
      expect(
        requests.last['conversation'],
        contains('My skill is system integration.'),
      );
      expect(find.text('Create card'), findsOneWidget);
      await tester.scrollUntilVisible(
        find.text('Your name: Amit Singh'),
        -180,
        scrollable: find.descendant(
          of: find.byKey(const ValueKey('card-conversation')),
          matching: find.byType(Scrollable),
        ),
      );
      expect(find.text('Your name: Amit Singh'), findsOneWidget);
      await tester.tap(find.text('Create card'));
      await tester.pumpAndSettle();
      expect(applied, containsPair('cardName', 'Creative card'));
      expect(applied, containsPair('fullName', 'Amit Singh'));
      expect(applied!['skills'], ['System integration']);
      expect(applied!['bio'], 'I design integrations for engineering teams.');
      expect(
        requests.length,
        3,
      ); // Confirming saves exactly the reviewed draft.
      expect(tester.takeException(), isNull);
    },
  );
  testWidgets('confirms the exact profile name and edits only the final draft', (
    tester,
  ) async {
    final requests = <Map<String, String>>[];
    Map<String, dynamic>? saved;
    await tester.pumpWidget(
      MaterialApp(
        home: Builder(
          builder: (context) => Scaffold(
            body: TextButton(
              onPressed: () async {
                saved = await showDialog<Map<String, dynamic>>(
                  context: context,
                  builder: (_) => ProfileQuestionnaire(
                    voice: SilentCardVoice(),
                    understandReplies: true,
                    profileName: 'Ánīt Singh',
                    generate: (input) async {
                      requests.add(input);
                      return {
                        'answers': [
                          'Creative',
                          'Work',
                          'Ánīt Singh',
                          'Architect',
                          'I help teams connect systems.',
                          'System integration',
                          'Engineering teams',
                        ],
                        'next': -1,
                        'question': '',
                        'card': {
                          'cardName': 'Creative',
                          'fullName': 'Ánīt Singh',
                          'role': 'Architect',
                          'pitch': 'I help teams connect systems.',
                          'skills': ['System integration'],
                          'category': 'professional',
                        },
                      };
                    },
                  ),
                );
              },
              child: const Text('Open'),
            ),
          ),
        ),
      ),
    );
    await tester.tap(find.text('Open'));
    await tester.pumpAndSettle();
    expect(
      find.textContaining('Your profile name is Ánīt Singh.'),
      findsOneWidget,
    );
    await tester.tap(find.text('Use this name'));
    await tester.pumpAndSettle();
    expect(requests, isEmpty);
    expect(find.byTooltip('Edit Your name'), findsNothing);
    expect(find.text('What should we name your card?'), findsOneWidget);
    await tester.enterText(
      find.byKey(const ValueKey('conversation-reply')),
      'Creative, for my work as an architect. I help engineering teams connect systems; my skill is system integration.',
    );
    await tester.tap(find.byTooltip('Send reply'));
    await tester.pumpAndSettle();
    expect(requests.single['profileName'], 'Ánīt Singh');
    expect(requests.single['conversation'], contains('profileNameConfirmed'));
    expect(saved, isNull);
    await tester.scrollUntilVisible(
      find.byTooltip('Edit Your name'),
      -180,
      scrollable: find.descendant(
        of: find.byKey(const ValueKey('card-conversation')),
        matching: find.byType(Scrollable),
      ),
    );
    await Scrollable.ensureVisible(
      tester.element(find.byTooltip('Edit Your name')),
      alignment: .5,
    );
    await tester.pumpAndSettle();
    await tester.tap(find.byTooltip('Edit Your name'));
    await tester.pumpAndSettle();
    await tester.enterText(
      find.byKey(const ValueKey('conversation-reply')),
      'Anit Singh',
    );
    await tester.tap(find.byTooltip('Save correction'));
    await tester.pumpAndSettle();
    expect(
      requests.length,
      1,
    ); // A spelling correction does not restart the interview.
    await tester.tap(find.text('Create card'));
    await tester.pumpAndSettle();
    expect(saved, containsPair('fullName', 'Anit Singh'));
    expect(tester.takeException(), isNull);
  });

  testWidgets('declining a profile name asks for a card-specific alternative', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: ProfileQuestionnaire(
            voice: SilentCardVoice(),
            understandReplies: true,
            profileName: 'Anit Singh',
            generate: (_) async => {},
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.text('Use another name'));
    await tester.pumpAndSettle();
    expect(
      find.text('What name would you like on this card instead?'),
      findsOneWidget,
    );
    expect(find.byTooltip('Edit Your name'), findsNothing);
    expect(find.text('Use this name'), findsNothing);
    expect(tester.takeException(), isNull);
  });
  testWidgets(
    'a spoken yes confirms the profile name without dictating its spelling',
    (tester) async {
      final voice = FakeCardVoice();
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: ProfileQuestionnaire(
              voice: voice,
              understandReplies: true,
              profileName: 'Ánīt Singh',
              generate: (_) async => {},
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(voice.spoken.last, contains('Your profile name is Ánīt Singh.'));
      voice.reply('Yes, you can use the same name');
      await tester.pump(const Duration(milliseconds: 6500));
      await tester.pumpAndSettle();
      expect(voice.spoken.last, 'What should we name your card?');
      expect(voice.listening, isTrue);
      expect(find.byTooltip('Edit Your name'), findsNothing);
      expect(tester.takeException(), isNull);
    },
  );
  testWidgets('short pauses and recognition restarts keep one complete reply', (
    tester,
  ) async {
    final voice = FakeCardVoice();
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: ProfileQuestionnaire(voice: voice, generate: (_) async => {}),
        ),
      ),
    );
    await tester.pumpAndSettle();
    voice.result!('Creative', false);
    await tester.pump(const Duration(seconds: 2));
    voice.reply('Creative work');
    await tester.pump(const Duration(milliseconds: 400));
    final staleResult = voice.result!;
    await tester.pump(const Duration(seconds: 1));
    expect(voice.spoken.length, 1);
    expect(find.byKey(const ValueKey('conversation-reply')), findsOneWidget);
    voice.reply('for my design business');
    await tester.pump(const Duration(seconds: 2));
    expect(
      voice.spoken.length,
      1,
    ); // New words reset the three-second silence deadline.
    final composer = tester.widget<TextField>(
      find.byKey(const ValueKey('conversation-reply')),
    );
    expect(composer.controller!.text, 'Creative work for my design business');
    await tester.pump(const Duration(milliseconds: 2500));
    await tester.pumpAndSettle();
    expect(find.text('Creative work for my design business'), findsOneWidget);
    expect(voice.spoken.last, 'What is this card for?');
    staleResult('Late result from a previous answer', true);
    await tester.pumpAndSettle();
    expect(find.text('Late result from a previous answer'), findsNothing);
    expect(tester.takeException(), isNull);
  });

  testWidgets(
    'explicit pause holds a reply indefinitely and resume appends to it',
    (tester) async {
      final voice = FakeCardVoice();
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: ProfileQuestionnaire(voice: voice, generate: (_) async => {}),
          ),
        ),
      );
      await tester.pumpAndSettle();
      voice.result!('My creative', false);
      await tester.pump();
      await tester.tap(find.byTooltip('Pause voice conversation'));
      await tester.pumpAndSettle();
      await tester.pump(const Duration(seconds: 15));
      expect(voice.spoken.length, 1);
      expect(
        tester
            .widget<TextField>(find.byKey(const ValueKey('conversation-reply')))
            .controller!
            .text,
        'My creative',
      );
      await tester.tap(find.byTooltip('Resume voice conversation'));
      await tester.pumpAndSettle();
      voice.result!('work card', true);
      await tester.pump();
      await tester.tap(find.byTooltip('Send reply'));
      await tester.pumpAndSettle();
      expect(find.text('My creative work card'), findsOneWidget);
      expect(voice.spoken.last, 'What is this card for?');
      expect(tester.takeException(), isNull);
    },
  );
}
