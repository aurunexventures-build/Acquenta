import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'package:contact_card_builder/models/card_link.dart';
import 'package:contact_card_builder/widgets/social_icon_row.dart';

void main() {
  test(
    'usernames become shareable platform URLs and pasted URLs are preserved',
    () {
      expect(
        CardLink.normalizeInput(LinkType.instagram, '@aurunex'),
        'https://www.instagram.com/aurunex',
      );
      expect(
        CardLink.normalizeInput(LinkType.linkedin, 'in/anit-singh/'),
        'https://www.linkedin.com/in/anit-singh',
      );
      expect(
        CardLink.normalizeInput(LinkType.facebook, 'my.page'),
        'https://www.facebook.com/my.page',
      );
      expect(
        CardLink.normalizeInput(LinkType.youtube, '@mychannel'),
        'https://www.youtube.com/@mychannel',
      );
      expect(
        CardLink.normalizeInput(LinkType.linkedin, 'linkedin.com/in/anit'),
        'https://linkedin.com/in/anit',
      );
      expect(
        CardLink.normalizeInput(LinkType.website, 'aurunex.com'),
        'https://aurunex.com',
      );
      const full = 'https://www.facebook.com/profile.php?id=123';
      expect(CardLink.normalizeInput(LinkType.facebook, full), full);
      expect(
        () => CardLink.normalizeInput(LinkType.instagram, 'two names'),
        throwsFormatException,
      );
      expect(
        () => CardLink.normalizeInput(LinkType.website, 'javascript:alert(1)'),
        throwsFormatException,
      );
      const legacy = CardLink(
        id: '1',
        title: 'Old Instagram',
        url: 'https://instagram.com/example',
        type: LinkType.website,
      );
      expect(legacy.platform, LinkType.instagram);
      expect(legacy.defaultIcon, FontAwesomeIcons.instagram);
      expect(
        CardLink.inferPlatform('https://instagram.com.evil.example/foo'),
        isNull,
      );
      expect(
        CardLink.fromJson(
          legacy.copyWith(type: LinkType.instagram).toJson(),
        ).type,
        LinkType.instagram,
      );
    },
  );

  testWidgets(
    'social profiles render as accessible icon buttons without link labels',
    (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: SocialIconRow(
              links: [
                CardLink(
                  id: '1',
                  title: 'My Instagram',
                  url: 'https://instagram.com/example',
                  type: LinkType.instagram,
                ),
                CardLink(
                  id: '2',
                  title: 'My LinkedIn',
                  url: 'https://linkedin.com/in/example',
                  type: LinkType.linkedin,
                ),
              ],
            ),
          ),
        ),
      );
      expect(find.byType(IconButton), findsNWidgets(2));
      expect(find.byTooltip('Instagram'), findsOneWidget);
      expect(find.byTooltip('LinkedIn'), findsOneWidget);
      expect(find.text('My Instagram'), findsNothing);
    },
  );
}
