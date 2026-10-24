import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:contact_card_builder/screens/profile_questionnaire.dart';
import 'aai_test_helpers.dart';

void main() {
  testWidgets(
    'purpose and identity must be confirmed; a spoken employer can be edited before saving',
    (tester) async {
      Map<String, dynamic>? saved;
      var calls = 0;
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
                      briefConversation: true,
                      profileName: 'Sam',
                      generate: (_) async {
                        calls++;
                        return {
                          'answers': [
                            'Architect card',
                            'Professional',
                            'Sam',
                            'IT Architect',
                            'I integrate systems.',
                            'System integration',
                            'Engineering teams',
                          ],
                          'next': -1,
                          'question': '',
                          'card': {
                            'cardName': 'Architect card',
                            'category': 'professional',
                            'fullName': 'Sam',
                            'role': 'IT Architect',
                            'pitch': 'I integrate systems.',
                            'company': 'Forest Mazars',
                            'bio': 'I integrate systems at Forest Mazars.',
                            'skills': ['System integration'],
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
      await tester.enterText(
        find.byKey(const ValueKey('conversation-reply')),
        'I work as an architect at Forest Mazars.',
      );
      await tester.tap(find.byTooltip('Send reply'));
      await tester.pumpAndSettle();
      final create = find.byWidgetPredicate((widget) => widget is FilledButton);
      expect(tester.widget<FilledButton>(create).onPressed, isNull);
      expect(
        tester
            .widget<ChoiceChip>(find.widgetWithText(ChoiceChip, 'Professional'))
            .selected,
        isFalse,
      );
      expect(tester.widget<FilledButton>(create).onPressed, isNull);
      final scroll = find.descendant(
        of: find.byKey(const ValueKey('card-conversation')),
        matching: find.byType(Scrollable),
      );
      await tester.scrollUntilVisible(
        find.byTooltip('Edit Company'),
        180,
        scrollable: scroll,
      );
      expect(find.text('Company: Forest Mazars'), findsOneWidget);
      await Scrollable.ensureVisible(
        tester.element(find.byTooltip('Edit Company')),
        alignment: 0.4,
      );
      await tester.pumpAndSettle();
      await tester.tap(find.byTooltip('Edit Company'));
      await tester.pumpAndSettle();
      await tester.enterText(
        find.byKey(const ValueKey('conversation-reply')),
        'Forest Mazars UK',
      );
      await tester.tap(find.byTooltip('Save correction'));
      await tester.pumpAndSettle();
      expect(tester.widget<FilledButton>(create).onPressed, isNull);
      await tester.scrollUntilVisible(
        find.byKey(const ValueKey('confirm-card-identity')),
        150,
        scrollable: scroll,
      );
      await tester.tap(find.byKey(const ValueKey('confirm-card-identity')));
      await tester.pumpAndSettle();
      await tester.scrollUntilVisible(
        find.text('Personal'),
        150,
        scrollable: scroll,
      );
      await Scrollable.ensureVisible(
        tester.element(find.text('Personal')),
        alignment: 0.4,
      );
      await tester.pumpAndSettle();
      await tester.tap(find.text('Personal'));
      await tester.pumpAndSettle();
      expect(tester.widget<FilledButton>(create).onPressed, isNotNull);
      await tester.tap(create);
      await tester.pumpAndSettle();
      expect(saved!['category'], 'personal');
      expect(saved!['company'], 'Forest Mazars UK');
      expect(saved!['fullName'], 'Sam');
      expect(calls, 1);
      expect(tester.takeException(), isNull);
    },
  );
}
