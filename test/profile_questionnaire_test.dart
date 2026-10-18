import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:contact_card_builder/screens/profile_questionnaire.dart';

void main() {
  testWidgets(
    'questionnaire validates, reviews, edits and applies only on confirmation',
    (tester) async {
      tester.view.physicalSize = const Size(360, 640);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
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
                      generate: (answers) async {
                        sent = answers;
                        return {
                          'role': 'Florist',
                          'pitch': 'I create wedding flowers.',
                          'skills': ['Floral design', 'Wedding arrangements'],
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
      await tester.tap(find.text('Draft my card'));
      await tester.pumpAndSettle();
      expect(find.text('Please add a few words.'), findsOneWidget);
      await tester.enterText(
        find.byType(TextFormField).first,
        'I am a florist creating wedding flowers.',
      );
      await tester.tap(find.text('Draft my card'));
      await tester.pumpAndSettle();
      expect(sent!['work'], contains('florist'));
      expect(applied, isNull);
      expect(find.text('Review your draft'), findsOneWidget);
      await tester.enterText(
        find.byType(TextFormField).last,
        'Wedding flowers made with care.',
      );
      await tester.tap(
        find.byType(InputChip).first,
      ); // Selecting never applies the draft.
      expect(applied, isNull);
      await tester.tap(find.text('Use this draft'));
      await tester.pumpAndSettle();
      expect(applied!['pitch'], 'Wedding flowers made with care.');
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets('AI failure retains questionnaire answers and allows retry', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: ProfileQuestionnaire(
            generate: (_) async => throw Exception('offline'),
          ),
        ),
      ),
    );
    await tester.enterText(
      find.byType(TextFormField).first,
      'I teach literacy.',
    );
    await tester.tap(find.text('Draft my card'));
    await tester.pumpAndSettle();
    expect(find.text('I teach literacy.'), findsOneWidget);
    expect(find.textContaining('Your answers are still here'), findsOneWidget);
    expect(find.text('Draft my card'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}
