import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:contact_card_builder/widgets/card_colour_picker.dart';

void main() {
  testWidgets(
    'custom hex colour can be applied and invalid input cannot be saved',
    (tester) async {
      String? chosen;
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: CardColourPicker(
              value: '#2563EB',
              onChanged: (value) => chosen = value,
            ),
          ),
        ),
      );
      await tester.tap(find.text('Choose any colour'));
      await tester.pumpAndSettle();
      await tester.enterText(find.byType(TextField), '#12');
      await tester.pumpAndSettle();
      expect(
        tester
            .widget<FilledButton>(
              find.widgetWithText(FilledButton, 'Use colour'),
            )
            .onPressed,
        isNull,
      );
      await tester.enterText(find.byType(TextField), '#12AB34');
      await tester.pumpAndSettle();
      await tester.tap(find.text('Use colour'));
      await tester.pumpAndSettle();
      expect(chosen, '#12AB34');
    },
  );
}
