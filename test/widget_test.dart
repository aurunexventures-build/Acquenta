import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:contact_card_builder/main.dart';
import 'package:contact_card_builder/services/storage_service.dart';
import 'package:contact_card_builder/services/search_service.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('SearchService accurately matches Cam & Anit scenario by event and tech stack', () async {
    SharedPreferences.setMockInitialValues({});
    final storage = await StorageService.init();
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
    expect(topMatch.matchReasons.any((r) => r.contains('Cam\'s Tech Talk')), isTrue);
    expect(topMatch.matchReasons.any((r) => r.contains('Flutter')), isTrue);

    // Test 2: Search only by tech stack: "Android"
    final resultsAndroid = SearchService.search(
      connections: connections,
      query: "Android",
    );
    expect(resultsAndroid.any((r) => r.connection.fullName == 'Anit Singh'), isTrue);

    // Test 3: Search by discussion topic: "side project"
    final resultsSideProject = SearchService.search(
      connections: connections,
      query: "side project",
    );
    expect(resultsSideProject.any((r) => r.connection.fullName == 'Anit Singh'), isTrue);

    // Test 4: Search by Future Self Note and Vibe: "aspirational"
    final resultsAspirational = SearchService.search(
      connections: connections,
      query: "aspirational",
    );
    expect(resultsAspirational.isNotEmpty, isTrue);
    expect(resultsAspirational.first.connection.fullName, 'Anit Singh');
    expect(resultsAspirational.first.matchReasons.any((r) => r.contains('Vibe') || r.contains('Future Self')), isTrue);

    // Test 5: Search by Future Self impression: "matcha"
    final resultsMatcha = SearchService.search(
      connections: connections,
      query: "matcha",
    );
    expect(resultsMatcha.isNotEmpty, isTrue);
    expect(resultsMatcha.first.connection.fullName, 'Elena Rostova');
    expect(resultsMatcha.first.matchReasons.any((r) => r.contains('Future Self')), isTrue);

    // Test 6: Search by Vibe tag: "Potential CTO"
    final resultsCTO = SearchService.search(
      connections: connections,
      query: "potential CTO",
    );
    expect(resultsCTO.isNotEmpty, isTrue);
    expect(resultsCTO.first.connection.fullName, 'Marcus Vance');
    expect(resultsCTO.first.matchReasons.any((r) => r.contains('Vibe') || r.contains('Future Self')), isTrue);

    // Test 7: Unique Vibes extraction
    final uniqueVibes = SearchService.extractUniqueVibes(connections);
    expect(uniqueVibes.contains('Aspirational Founder'), isTrue);
    expect(uniqueVibes.contains('Visionary Researcher'), isTrue);
  });

  testWidgets('First launch displays Craft Your MetCue Card profile onboarding wizard', (WidgetTester tester) async {
    SharedPreferences.setMockInitialValues({});
    final storage = await StorageService.init();

    await tester.pumpWidget(ContactCardBuilderApp(storageService: storage));
    await tester.pumpAndSettle();

    // Verify first-time profile builder is shown
    expect(find.text('Craft Your MetCue Card'), findsOneWidget);
    expect(find.text('1. YOUR IDENTITY'), findsOneWidget);
    expect(find.text('Skip'), findsOneWidget);
  });

  testWidgets('Returning launch renders MetCue Wallet with My Cards tab', (WidgetTester tester) async {
    SharedPreferences.setMockInitialValues({'has_completed_onboarding': true});
    final storage = await StorageService.init();

    await tester.pumpWidget(ContactCardBuilderApp(storageService: storage));
    await tester.pumpAndSettle();

    // Verify wallet app bar title
    expect(find.textContaining('MetCue Wallet'), findsWidgets);

    // Verify navigation tabs
    expect(find.text('My Cards'), findsOneWidget);
    expect(find.text('Connections'), findsOneWidget);
    expect(find.text('Smart Recall'), findsOneWidget);

    // Switch to Smart Recall tab
    await tester.tap(find.text('Smart Recall'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));

    expect(find.text('Neural Brain'), findsOneWidget);
    expect(find.text('Ranked Cards'), findsOneWidget);
    expect(find.text('MetCue Neural Recall'), findsOneWidget);

    // Switch to Ranked Cards view
    await tester.tap(find.text('Ranked Cards'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));

    // Verify top connection and Future Self Notes show up
    expect(find.text('Anit Singh'), findsOneWidget);
    expect(find.textContaining('humble yet brilliantly sharp architect'), findsOneWidget);
  });
}
