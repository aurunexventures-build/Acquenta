import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:contact_card_builder/main.dart';
import 'package:contact_card_builder/screens/connection_detail_screen.dart';
import 'package:contact_card_builder/screens/add_connection_screen.dart';
import 'package:contact_card_builder/theme/metcue_theme.dart';
import 'package:contact_card_builder/services/storage_service.dart';
import 'package:contact_card_builder/services/search_service.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test(
    'SearchService accurately matches Cam & Anit scenario by event and tech stack',
    () async {
      SharedPreferences.setMockInitialValues({});
      final storage = await StorageService.init(seedDemo: true);
      final connections = await storage.loadConnections();

      expect(connections.isNotEmpty, isTrue);

      // Test 1: Search by event name + technology: "Cam's Tech Talk Flutter"
      final resultsEventFlutter = SearchService.search(
        connections: connections,
        query: "Cam's Tech Talk Flutter",
      );

      expect(resultsEventFlutter.isNotEmpty, isTrue);
      final topMatch = resultsEventFlutter.first;
      expect(topMatch.connection.fullName, 'Anit Singh');
      expect(
        topMatch.matchReasons.any((r) => r.contains('Cam\'s Tech Talk')),
        isTrue,
      );
      expect(topMatch.matchReasons.any((r) => r.contains('Flutter')), isTrue);

      // Test 2: Search only by tech stack: "Android"
      final resultsAndroid = SearchService.search(
        connections: connections,
        query: "Android",
      );
      expect(
        resultsAndroid.any((r) => r.connection.fullName == 'Anit Singh'),
        isTrue,
      );

      // Test 3: Search by discussion topic: "side project"
      final resultsSideProject = SearchService.search(
        connections: connections,
        query: "side project",
      );
      expect(
        resultsSideProject.any((r) => r.connection.fullName == 'Anit Singh'),
        isTrue,
      );

      // Test 4: Search by Future Self Note and Vibe: "aspirational"
      final resultsAspirational = SearchService.search(
        connections: connections,
        query: "aspirational",
      );
      expect(resultsAspirational.isNotEmpty, isTrue);
      expect(resultsAspirational.first.connection.fullName, 'Anit Singh');
      expect(
        resultsAspirational.first.matchReasons.any(
          (r) => r.contains('Vibe') || r.contains('Future Self'),
        ),
        isTrue,
      );

      // Test 5: Search by Future Self impression: "matcha"
      final resultsMatcha = SearchService.search(
        connections: connections,
        query: "matcha",
      );
      expect(resultsMatcha.isNotEmpty, isTrue);
      expect(resultsMatcha.first.connection.fullName, 'Elena Rostova');
      expect(
        resultsMatcha.first.matchReasons.any((r) => r.contains('Future Self')),
        isTrue,
      );

      // Test 6: Search by Vibe tag: "Potential CTO"
      final resultsCTO = SearchService.search(
        connections: connections,
        query: "potential CTO",
      );
      expect(resultsCTO.isNotEmpty, isTrue);
      expect(resultsCTO.first.connection.fullName, 'Marcus Vance');
      expect(
        resultsCTO.first.matchReasons.any(
          (r) => r.contains('Vibe') || r.contains('Future Self'),
        ),
        isTrue,
      );

      // Test 7: Unique Vibes extraction
      final uniqueVibes = SearchService.extractUniqueVibes(connections);
      expect(uniqueVibes.contains('Aspirational Founder'), isTrue);
      expect(uniqueVibes.contains('Visionary Researcher'), isTrue);
    },
  );

  testWidgets('First launch sets up About Me before card creation', (
    WidgetTester tester,
  ) async {
    SharedPreferences.setMockInitialValues({});
    final storage = await StorageService.init(seedDemo: true);

    await tester.pumpWidget(
      ContactCardBuilderApp(storageService: storage, requireSignIn: false),
    );
    await tester.pumpAndSettle();

    expect(find.text('Set up your account'), findsOneWidget);
    expect(find.text('First name *'), findsOneWidget);
    expect(find.text('Create your card'), findsNothing);
  });

  testWidgets('Returning launch renders MetCue Wallet with My Cards tab', (
    WidgetTester tester,
  ) async {
    tester.platformDispatcher.platformBrightnessTestValue = Brightness.dark;
    addTearDown(tester.platformDispatcher.clearPlatformBrightnessTestValue);
    SharedPreferences.setMockInitialValues({'has_completed_onboarding': true});
    final storage = await StorageService.init(seedDemo: true);

    await tester.pumpWidget(
      ContactCardBuilderApp(storageService: storage, requireSignIn: false),
    );
    await tester.pumpAndSettle();

    // Verify wallet app bar title
    expect(find.textContaining('My cards'), findsWidgets);

    // Verify navigation tabs
    expect(find.text('My Cards'), findsOneWidget);
    expect(find.text('Connections'), findsOneWidget);
    expect(find.text('Smart Recall'), findsOneWidget);

    // Switch to Smart Recall tab
    await tester.tap(find.text('Smart Recall'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));

    expect(find.text('Smart recall'), findsOneWidget);
    expect(find.text('A little detail is all it takes.'), findsOneWidget);
    expect(find.text('Anit Singh'), findsNothing);
    await tester.enterText(find.byType(TextField), 'Flutter');
    await tester.pump(const Duration(milliseconds: 550));
    await tester.pumpAndSettle();
    expect(find.text('Anit Singh'), findsWidgets);
    final result = find
        .byWidgetPredicate(
          (widget) =>
              widget.key is ValueKey<String> &&
              (widget.key as ValueKey<String>).value.startsWith(
                'recall-result-',
              ),
        )
        .first;
    await tester.ensureVisible(result);
    await tester.tap(result);
    await tester.pumpAndSettle();
    expect(find.byType(ConnectionDetailScreen), findsOneWidget);
    var pageTheme = Theme.of(
      tester.element(find.byType(ConnectionDetailScreen)),
    );
    expect(pageTheme.brightness, Brightness.light);
    expect(pageTheme.scaffoldBackgroundColor, MetCueTheme.paper);
    expect(pageTheme.colorScheme.primary, MetCueTheme.purple);
    await tester.tap(find.byTooltip('Edit'));
    await tester.pumpAndSettle();
    expect(find.byType(AddConnectionScreen), findsOneWidget);
    pageTheme = Theme.of(tester.element(find.byType(AddConnectionScreen)));
    expect(pageTheme.brightness, Brightness.light);
    expect(pageTheme.scaffoldBackgroundColor, MetCueTheme.paper);
    expect(tester.takeException(), isNull);
  });
}
