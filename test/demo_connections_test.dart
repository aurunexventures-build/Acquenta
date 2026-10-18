import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:contact_card_builder/services/storage_service.dart';
import 'package:contact_card_builder/services/demo_connections.dart';
import 'package:contact_card_builder/services/search_service.dart';

void main() {
  test('profession recall outranks an incidental event-name match', () {
    final results = SearchService.search(
      connections: demoConnections(),
      query: 'creator',
    );
    expect(results.first.connection.role.toLowerCase(), contains('creator'));
    expect(
      results.first.matchReasons.any((r) => r.startsWith('Role:')),
      isTrue,
    );
  });

  test(
    'five AuruNex personas are added once without replacing edits',
    () async {
      SharedPreferences.setMockInitialValues({});
      final storage = await StorageService.init();
      await storage.addDemoIdentityCardsOnce();
      var cards = await storage.loadCards();
      expect(cards, hasLength(5));
      expect(cards.every((c) => c.title == 'AuruNex Ventures'), isTrue);
      expect(cards.where((c) => c.isDefault), hasLength(1));
      expect(
        cards.map((c) => c.role),
        containsAll(['Integration Lead', 'Senior IT Architect']),
      );
      cards[0] = cards[0].copyWith(headline: 'My edited headline');
      await storage.saveCards(cards);
      await storage.addDemoIdentityCardsOnce();
      cards = await storage.loadCards();
      expect(cards, hasLength(5));
      expect(cards.first.headline, 'My edited headline');
    },
  );
  test('20 varied Demo contacts are searchable and seed only once', () async {
    SharedPreferences.setMockInitialValues({});
    final storage = await StorageService.init();
    await storage.saveConnections([
      demoConnections().first.copyWith(fullName: 'Edited Demo'),
    ]);
    await storage.addDemoConnectionsOnce();
    var contacts = await storage.loadConnections();
    expect(contacts, hasLength(20));
    expect(contacts.every((c) => c.fullName.endsWith(' Demo')), isTrue);
    expect(contacts.map((c) => c.id).toSet(), hasLength(20));
    expect(contacts.first.fullName, 'Edited Demo');
    for (final query in [
      'plumber',
      'YouTube',
      'Flutter',
      'Instagram',
      'bicycle',
      'pottery',
    ]) {
      expect(
        SearchService.search(connections: contacts, query: query),
        isNotEmpty,
      );
    }
    final removed = contacts.removeLast();
    await storage.saveConnections(contacts);
    await storage.addDemoConnectionsOnce();
    contacts = await storage.loadConnections();
    expect(contacts, hasLength(19));
    expect(contacts.any((c) => c.id == removed.id), isFalse);
  });
}
