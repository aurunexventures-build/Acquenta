import 'aai_test_helpers.dart';
import 'package:contact_card_builder/screens/connection_detail_screen.dart';
import 'dart:io';
import 'dart:convert';
import 'package:contact_card_builder/screens/account_profile_screen.dart';
import 'package:contact_card_builder/providers/account_profile_provider.dart';
import 'package:contact_card_builder/models/account_profile.dart';
import 'package:contact_card_builder/widgets/wallet_free_slots.dart';
import 'package:contact_card_builder/widgets/skills_tags_editor.dart';
import 'package:contact_card_builder/widgets/social_links_editor.dart';
import 'package:contact_card_builder/models/card_link.dart';
import 'package:contact_card_builder/screens/card_editor_screen.dart';
import 'package:contact_card_builder/screens/home_screen.dart';
import 'package:contact_card_builder/services/auth_service.dart';
import 'package:contact_card_builder/widgets/visiting_card_deck.dart';
import 'package:contact_card_builder/widgets/qr_share_dialog.dart';
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:contact_card_builder/models/contact_card.dart';
import 'package:contact_card_builder/providers/cards_provider.dart';
import 'package:contact_card_builder/providers/connections_provider.dart';
import 'package:contact_card_builder/screens/onboarding_card_builder_screen.dart';
import 'package:contact_card_builder/screens/profile_questionnaire.dart';
import 'package:contact_card_builder/screens/smart_search_screen.dart';
import 'package:contact_card_builder/services/storage_service.dart';
import 'package:contact_card_builder/theme/metcue_theme.dart';

void main() {
  setUpAll(() async {
    final fonts = Directory(
      '${File(Platform.resolvedExecutable).parent.parent.parent.path}/material_fonts',
    );
    for (final entry in {
      'Roboto': 'Roboto-Regular.ttf',
      'MaterialIcons': 'MaterialIcons-Regular.otf',
    }.entries) {
      final file = File('${fonts.path}/${entry.value}');
      if (await file.exists()) {
        final loader = FontLoader(entry.key)
          ..addFont(file.readAsBytes().then(ByteData.sublistView));
        await loader.load();
      }
    }
    final brands = FontLoader('packages/font_awesome_flutter/FontAwesomeBrands')
      ..addFont(
        rootBundle.load(
          'packages/font_awesome_flutter/lib/fonts/Font-Awesome-7-Brands-Regular-400.otf',
        ),
      );
    await brands.load();
  });
  testWidgets('render simplified phone setup and recall with real fonts', (
    tester,
  ) async {
    SharedPreferences.setMockInitialValues({});
    final storage = await StorageService.init();
    tester.view.physicalSize = const Size(360, 780);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final boundary = GlobalKey();
    final conversationVoice = FakeCardVoice();
    Future<void> capture(String name, Widget screen) async {
      await tester.pumpWidget(
        MaterialApp(
          key: ValueKey(name),
          theme: MetCueTheme.light.copyWith(
            appBarTheme: MetCueTheme.light.appBarTheme.copyWith(
              titleTextStyle: MetCueTheme.light.appBarTheme.titleTextStyle!
                  .copyWith(fontFamily: 'Roboto'),
            ),
          ),
          home: RepaintBoundary(
            key: boundary,
            child: KeyedSubtree(key: ValueKey(name), child: screen),
          ),
        ),
      );
      if (name == 'card-setup') {
        await tester.runAsync(
          () => precacheImage(
            const AssetImage('assets/branding/acquenta-icon-v3.png'),
            boundary.currentContext!,
          ),
        );
        for (var frame = 0; frame < 24; frame++) {
          await tester.pump(const Duration(milliseconds: 200));
          await tester.runAsync(() async {
            final image =
                await (boundary.currentContext!.findRenderObject()
                        as RenderRepaintBoundary)
                    .toImage(pixelRatio: 1);
            final bytes = await image.toByteData(
              format: ui.ImageByteFormat.png,
            );
            final file = File(
              'build/ui-review/card-motion/frame-${frame.toString().padLeft(2, '0')}.png',
            );
            await file.parent.create(recursive: true);
            await file.writeAsBytes(bytes!.buffer.asUint8List());
            image.dispose();
          });
        }
      }
      await tester.pumpAndSettle();
      if (name == 'people-voice-stack') {
        await tester.tap(find.text('Connections').last);
        await tester.pumpAndSettle();
      }
      if (name == 'speak-profile') {
        for (final answer in [
          'Call it Creative card. Show it as Sam Patel, an IT architect. I help teams connect their systems for work.',
          'My skills are enterprise architecture and system integration.',
          'Engineering teams planning their next project.',
        ]) {
          conversationVoice.reply(answer);
          await tester.pump(const Duration(milliseconds: 6500));
          await tester.pumpAndSettle();
        }
      }
      expect(tester.takeException(), isNull);
      await tester.runAsync(() async {
        final image =
            await (boundary.currentContext!.findRenderObject()
                    as RenderRepaintBoundary)
                .toImage(pixelRatio: 2);
        final bytes = await image.toByteData(format: ui.ImageByteFormat.png);
        final file = File('build/ui-review/$name.png');
        await file.parent.create(recursive: true);
        await file.writeAsBytes(bytes!.buffer.asUint8List());
        image.dispose();
      });
    }

    await capture(
      'skills-paragraph',
      Scaffold(
        appBar: AppBar(title: const Text('Skills & tags')),
        body: SingleChildScrollView(
          padding: const EdgeInsets.all(20),
          child: SkillsTagsEditor(
            skills: const [
              'Plumbing',
              'Bathroom fitting',
              'Android development',
            ],
            onChanged: (_) {},
          ),
        ),
      ),
    );
    final socials = [
      SocialLinkDraft(type: LinkType.linkedin, text: 'sam-patel'),
      SocialLinkDraft(type: LinkType.youtube, text: 'samcreates'),
      SocialLinkDraft(type: LinkType.website, text: 'sam.example.com'),
    ];
    await capture(
      'social-handles',
      Scaffold(
        appBar: AppBar(title: const Text('Contact profiles')),
        body: SingleChildScrollView(
          padding: const EdgeInsets.all(20),
          child: SocialLinksEditor(drafts: socials, onChanged: () {}),
        ),
      ),
    );
    await tester.pumpWidget(const SizedBox());
    for (final d in socials) {
      d.dispose();
    }
    await capture(
      'free-card-slots',
      Scaffold(
        body: Padding(
          padding: const EdgeInsets.all(20),
          child: WalletFreeSlots(used: 3, remaining: 2, onAdd: () {}),
        ),
      ),
    );
    await capture(
      'about-me-setup',
      MultiProvider(
        providers: [
          ChangeNotifierProvider(
            create: (_) => AccountProfileProvider(storage),
          ),
          ChangeNotifierProvider(create: (_) => AuthService()),
        ],
        child: const AccountProfileScreen(setup: true),
      ),
    );
    await storage.saveAccountProfile(
      AccountProfile(
        firstName: 'Sam',
        lastName: 'Patel',
        phone: '+44 7700 900123',
        emails: const ['sam@example.com', 'sam@work.example'],
        links: const [
          CardLink(
            id: 'linkedin-about',
            title: 'LinkedIn',
            type: LinkType.linkedin,
            url: 'https://www.linkedin.com/in/sam-patel',
          ),
        ],
        updatedAt: DateTime(2026),
      ),
      dirty: false,
    );
    await capture(
      'about-me-edit',
      MultiProvider(
        providers: [
          ChangeNotifierProvider(
            create: (_) => AccountProfileProvider(storage),
          ),
          ChangeNotifierProvider(create: (_) => AuthService()),
        ],
        child: const AccountProfileScreen(),
      ),
    );
    await capture(
      'card-setup',
      OnboardingCardBuilderScreen(storageService: storage),
    );
    await capture(
      'profile-name-confirmation',
      Scaffold(
        body: ProfileQuestionnaire(
          voice: FakeCardVoice(),
          understandReplies: true,
          profileName: 'Sam Patel',
          generate: (_) async => {},
        ),
      ),
    );
    await capture(
      'speak-profile',
      Scaffold(
        body: ProfileQuestionnaire(
          voice: conversationVoice,
          understandReplies: true,
          generate: (input) async {
            final count = (jsonDecode(input['conversation']!) as List).length;
            return {
              'answers': [
                'Creative card',
                'Professional networking',
                'Sam Patel',
                'IT Architect',
                'I help teams connect their enterprise systems.',
                count > 1
                    ? 'Enterprise architecture, system integration'
                    : null,
                count > 2 ? 'Engineering teams' : null,
              ],
              'next': count == 1
                  ? 5
                  : count == 2
                  ? 6
                  : -1,
              'question': count == 1
                  ? 'Which skills should your card highlight?'
                  : 'Who would you like to connect with?',
              'card': count > 2
                  ? {
                      'cardName': 'Creative card',
                      'fullName': 'Sam Patel',
                      'role': 'IT Architect',
                      'pitch': 'I help teams connect their enterprise systems.',
                      'skills': [
                        'Enterprise architecture',
                        'System integration',
                      ],
                      'category': 'professional',
                    }
                  : null,
            };
          },
        ),
      ),
    );
    await storage.saveCards([
      ContactCard(
        id: 'mine',
        title: 'Work',
        category: CardCategory.professional,
        fullName: 'Sam',
        role: 'App developer',
        headline: 'I create Android applications.',
        links: const [
          CardLink(
            id: 'linkedin',
            title: 'LinkedIn',
            type: LinkType.linkedin,
            url: 'https://www.linkedin.com/in/sam-patel',
          ),
          CardLink(
            id: 'instagram',
            title: 'Instagram',
            type: LinkType.instagram,
            url: 'https://www.instagram.com/sam',
          ),
          CardLink(id: 'website', title: 'Website', url: 'https://example.com'),
          CardLink(
            id: 'youtube',
            title: 'YouTube',
            type: LinkType.youtube,
            url: 'https://www.youtube.com/@sam',
          ),
          CardLink(
            id: 'github',
            title: 'GitHub',
            type: LinkType.github,
            url: 'https://github.com/sam',
          ),
        ],
        createdAt: DateTime(2026),
        updatedAt: DateTime(2026),
      ),
    ]);
    final sample = (await storage.loadCards()).first;
    await capture(
      'wallet-stacked',
      Scaffold(
        appBar: AppBar(title: const Text('My wallet')),
        body: Padding(
          padding: const EdgeInsets.all(16),
          child: VisitingCardDeck(
            entries: List.generate(
              3,
              (i) => WalletEntry.own(
                sample.copyWith(
                  id: 'card-$i',
                  fullName: 'Sam Patel',
                  company: 'Studio North',
                  email: 'sam@example.com',
                ),
                onOpen: () {},
                onSend: () {},
              ),
            ),
          ),
        ),
      ),
    );
    await capture('send-offline', QrShareDialog(card: sample));
    await storage.addDemoConnectionsOnce();
    final cards = CardsProvider(storage), people = ConnectionsProvider(storage);
    await cards.loadCards();
    await people.loadConnections();
    await capture(
      'edit-purpose',
      ChangeNotifierProvider.value(
        value: cards,
        child: CardEditorScreen(initialCard: sample),
      ),
    );
    await cards.updateCard(sample.copyWith(isDefault: true));
    await cards.addCard(
      sample.copyWith(id: 'personal', title: 'Personal', isDefault: false),
    );
    await cards.addCard(
      sample.copyWith(id: 'project', title: 'Project', isDefault: false),
    );
    await cards.addCard(
      sample.copyWith(
        id: 'event-card',
        themeColorHex: '#0D9488',
        fullName: 'Sam · Events',
        isDefault: false,
      ),
    );
    await cards.addCard(
      sample.copyWith(
        id: 'project-card',
        themeColorHex: '#7C3AED',
        fullName: 'Sam · Projects',
        isDefault: false,
      ),
    );
    await capture(
      'home-no-gap',
      MultiProvider(
        providers: [
          ChangeNotifierProvider.value(value: cards),
          ChangeNotifierProvider.value(value: people),
          ChangeNotifierProvider(create: (_) => AuthService()),
        ],
        child: const HomeScreen(),
      ),
    );
    await capture(
      'people-voice-stack',
      MultiProvider(
        providers: [
          ChangeNotifierProvider.value(value: cards),
          ChangeNotifierProvider.value(value: people),
          ChangeNotifierProvider(create: (_) => AuthService()),
        ],
        child: const HomeScreen(),
      ),
    );
    if (people.connections.isNotEmpty) {
      await capture(
        'connection-information-first',
        ChangeNotifierProvider.value(
          value: people,
          child: ConnectionDetailScreen(
            connectionId: people.connections.first.id,
          ),
        ),
      );
    }
    people.setSearchQuery('developer');
    addTearDown(cards.dispose);
    addTearDown(people.dispose);
    await capture(
      'recall-connections',
      MultiProvider(
        providers: [
          ChangeNotifierProvider.value(value: cards),
          ChangeNotifierProvider.value(value: people),
        ],
        child: const SmartSearchScreen(),
      ),
    );
  });
}
