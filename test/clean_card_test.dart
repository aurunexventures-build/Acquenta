import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:contact_card_builder/models/contact_card.dart';
import 'package:contact_card_builder/models/card_link.dart';
import 'package:contact_card_builder/widgets/interactive_card_view.dart';
import 'package:contact_card_builder/widgets/visiting_card_deck.dart';

void main() {
  testWidgets('all twenty profiles wrap without overflowing a narrow wallet', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(320, 1100);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final card = ContactCard(
      id: 'many',
      title: 'Work',
      fullName: 'Sam Patel',
      role: 'Designer',
      headline: 'I design useful things.',
      links: List.generate(
        20,
        (i) => CardLink(
          id: '$i',
          title: 'Website $i',
          url: 'https://example.com/$i',
        ),
      ),
      createdAt: DateTime(2026),
      updatedAt: DateTime(2026),
    );
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: SingleChildScrollView(
            child: VisitingCardDeck(
              entries: [
                WalletEntry.own(card, onOpen: () {}),
                WalletEntry.own(card.copyWith(id: 'second'), onOpen: () {}),
              ],
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.byTooltip('Website'), findsNWidgets(40));
    expect(find.byTooltip('More profiles'), findsNothing);
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: SingleChildScrollView(child: InteractiveCardView(card: card)),
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.byTooltip('Website'), findsNWidgets(20));
    expect(tester.takeException(), isNull);
  });

  testWidgets('small card shows every profile icon and hides long skill text', (
    tester,
  ) async {
    SharedPreferences.setMockInitialValues({});
    tester.view.physicalSize = const Size(360, 800);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: SingleChildScrollView(
            child: InteractiveCardView(
              card: ContactCard(
                id: '1',
                title: 'AuruNex Ventures',
                fullName: 'Anit Singh',
                role: 'Integration Lead',
                headline: 'A long introduction',
                techStack: const ['API Integration', 'System Design'],
                links: const [
                  CardLink(
                    id: '1',
                    title: 'LinkedIn',
                    url: 'https://linkedin.com/in/example',
                    type: LinkType.linkedin,
                  ),
                  CardLink(
                    id: '2',
                    title: 'Instagram',
                    url: 'https://instagram.com/example',
                    type: LinkType.instagram,
                  ),
                  CardLink(
                    id: '3',
                    title: 'Website',
                    url: 'https://example.com',
                  ),
                ],
                createdAt: DateTime(2026),
                updatedAt: DateTime(2026),
              ),
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.text('A long introduction'), findsNothing);
    expect(find.text('API Integration'), findsNothing);
    final name = tester.getRect(find.text('Anit Singh'));
    final social = tester.getRect(find.byTooltip('LinkedIn'));
    expect(social.top, greaterThanOrEqualTo(name.bottom));
    expect(find.byTooltip('Website'), findsOneWidget);
    expect(tester.getRect(find.byTooltip('Website')).top, social.top);
    expect(find.byTooltip('More profiles'), findsNothing);
    expect(tester.takeException(), isNull);
  });
}
