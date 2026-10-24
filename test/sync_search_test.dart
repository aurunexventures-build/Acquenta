import 'dart:async';
import 'dart:convert';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:contact_card_builder/models/contact_card.dart';
import 'package:contact_card_builder/models/event_context.dart';
import 'package:contact_card_builder/models/saved_connection.dart';
import 'package:contact_card_builder/providers/cards_provider.dart';
import 'package:contact_card_builder/providers/connections_provider.dart';
import 'package:contact_card_builder/services/auth_service.dart';
import 'package:contact_card_builder/services/storage_service.dart';
import 'package:contact_card_builder/services/sync_service.dart';

class TestUser extends Fake implements User {
  @override
  String get uid => 'alice';
}

class TestAuth extends AuthService {
  bool signedIn = true;
  @override
  User? get currentUser => signedIn ? TestUser() : null;
  @override
  Future<String?> getIdToken() async => signedIn ? 'test-token' : null;
}

class TestSync extends SyncService {
  final requests = <String>[];
  final responses = <Completer<Map<String, dynamic>>>[];
  Completer<SyncResult>? pendingSync;
  int syncCount = 0;
  @override
  Future<Map<String, dynamic>> semanticSearch(String query, AuthService auth) {
    requests.add(query);
    final response = Completer<Map<String, dynamic>>();
    responses.add(response);
    return response.future;
  }

  final contexts = <List<String>>[];
  @override
  Future<Map<String, dynamic>> request(
    String path,
    Map<String, dynamic> body,
    AuthService auth, {
    String method = 'POST',
  }) {
    contexts.add(List<String>.from(body['context'] as List? ?? []));
    return semanticSearch(body['query'] as String, auth);
  }

  @override
  Future<SyncResult> sync({
    required List<SavedConnection> connections,
    required List<ContactCard> cards,
    required List<Map<String, dynamic>> deleted,
    required AuthService auth,
  }) async {
    syncCount++;
    return pendingSync?.future ??
        SyncResult(
          success: true,
          message: 'Synced',
          connections: connections,
          cards: cards,
          deleted: deleted,
        );
  }
}

final now = DateTime.utc(2026, 10, 1);
SavedConnection person(String id, String name) => SavedConnection(
  id: id,
  fullName: name,
  eventContext: EventContext(eventName: 'Meetup', date: now),
  savedAt: now,
);
Map<String, dynamic> match(SavedConnection c) => {
  'connection': c.toJson(),
  'score': 0.8,
  'reason': 'Similar saved memory',
};

void main() {
  test(
    'short and multilingual queries use AI; refinements reset on a new search',
    () async {
      SharedPreferences.setMockInitialValues({});
      final storage = await StorageService.init();
      final service = TestSync();
      final provider = ConnectionsProvider(storage, syncService: service);
      final cards = CardsProvider(storage);
      addTearDown(provider.dispose);
      addTearDown(cards.dispose);
      await provider.loadConnections();
      provider.bindAuth(TestAuth(), cards: cards);
      for (final query in ['AI', 'IT', 'डेवलपर']) {
        provider.setSearchQuery(query);
        await Future<void>.delayed(const Duration(milliseconds: 800));
        expect(service.requests.last, query);
        service.responses.last.complete({'matches': [], 'aiReranked': true});
        await Future<void>.delayed(Duration.zero);
      }
      provider.refineRecall('only Flutter');
      await Future<void>.delayed(const Duration(milliseconds: 800));
      expect(service.contexts.last, ['डेवलपर']);
      service.responses.last.complete({'matches': [], 'aiReranked': true});
      await Future<void>.delayed(Duration.zero);
      provider.setSearchQuery('plumber');
      expect(provider.recallContext, isEmpty);
      provider.clearForAccountSwitch();
      expect(provider.recallContext, isEmpty);
    },
  );

  test(
    'AI-ranked meaning matches survive the old vector cutoff and use current local records',
    () async {
      SharedPreferences.setMockInitialValues({});
      final storage = await StorageService.init();
      final developer = person(
        'dev',
        'Mei',
      ).copyWith(role: 'Flutter developer', techStack: ['Flutter']);
      await storage.saveConnections([developer]);
      final service = TestSync();
      final provider = ConnectionsProvider(storage, syncService: service);
      final cards = CardsProvider(storage);
      final auth = TestAuth();
      await provider.loadConnections();
      provider.bindAuth(auth, cards: cards);
      provider.setSearchQuery('code wizard');
      await Future<void>.delayed(const Duration(milliseconds: 800));
      service.responses.last.complete({
        'matches': [
          {...match(developer), 'score': .65},
        ],
        'indexed': true,
        'aiReranked': true,
        'interpretation': 'Software developers',
      });
      await Future<void>.delayed(Duration.zero);
      expect(provider.searchResults.map((r) => r.connection.id), ['dev']);
      expect(provider.recallInterpretation, 'Software developers');
      provider.setSearchQuery('code wizard');
      await Future<void>.delayed(const Duration(milliseconds: 800));
      expect(
        service.requests.length,
        1,
        reason: 'Identical queries reuse the current wallet cache',
      );
      provider.dispose();
      cards.dispose();
      auth.dispose();
    },
  );
  TestWidgetsFlutterBinding.ensureInitialized();
  setUp(() => SharedPreferences.setMockInitialValues({}));
  test(
    'growing histories batch by encoded bytes and record count without loss',
    () {
      final records = List.generate(
        8,
        (i) => {'id': 'person-$i', 'text': '🎉' * 40000},
      );
      final batches = SyncService.syncBatches(records, [], []);
      expect(batches.length, greaterThan(1));
      expect(batches.expand((b) => b['connections'] as List).length, 8);
      for (final batch in batches) {
        expect(utf8.encode(jsonEncode(batch)).length, lessThan(512000));
      }
      final many = SyncService.syncBatches(
        List.generate(1001, (i) => {'id': '$i'}),
        [],
        [],
      );
      expect(many.length, 3);
      expect(SyncService.syncBatches([], [], []).length, 1);
    },
  );
  test(
    'web uses its Cloudflare origin, native uses the existing Worker, and development can override it',
    () {
      expect(
        SyncService.resolveApiBase(
          isWeb: true,
          pageUri: Uri.parse('https://metcue.example/#/wallet'),
        ),
        'https://metcue.example',
      );
      expect(
        SyncService.resolveApiBase(
          isWeb: false,
          pageUri: Uri.parse('file:///app/'),
        ),
        SyncService.nativeApiUrl,
      );
      expect(
        SyncService.resolveApiBase(
          isWeb: true,
          pageUri: Uri.parse('http://localhost:4187'),
          override: 'http://localhost:8787/',
        ),
        'http://localhost:8787',
      );
      expect(
        () => SyncService.resolveApiBase(
          isWeb: true,
          pageUri: Uri.parse('http://localhost'),
          override: 'https://api.example/path',
        ),
        throwsArgumentError,
      );
    },
  );

  test(
    'sync uses matching API contract and preserves all returned connection fields',
    () async {
      final contact = person('remote', 'Remote person').copyWith(
        rawCue: 'Coffee at the gallery',
        callWhen: ['Exhibition'],
        futureSelfNote: 'Collaborate',
      );
      final service = SyncService(
        client: MockClient((request) async {
          if (request.url.path == '/api/v1/account') {
            expect(request.method, 'GET');
            return http.Response('{"active":true}', 200);
          }
          expect(request.method, 'POST');
          expect(request.url.path, '/api/v1/sync');
          expect(request.headers['Authorization'], 'Bearer test-token');
          final body = jsonDecode(request.body);
          expect(body['protocol'], 2);
          expect(body['connections'][0]['rawCue'], contact.rawCue);
          return http.Response(
            jsonEncode({
              'connections': [contact.toJson()],
              'cards': [],
              'deleted': [],
              'indexed': true,
            }),
            200,
          );
        }),
      );
      final auth = TestAuth();
      final result = await service.sync(
        connections: [contact],
        cards: [],
        deleted: [],
        auth: auth,
      );
      expect(result.success, true);
      expect(result.connections.single.callWhen, ['Exhibition']);
      expect(result.connections.single.rawCue, contact.rawCue);
      service.close();
      auth.dispose();
    },
  );
  testWidgets(
    'AI search is debounced and old responses cannot replace a newer query',
    (tester) async {
      final storage = await StorageService.init();
      await storage.activateAccount('alice');
      final service = TestSync(), auth = TestAuth();
      final provider = ConnectionsProvider(storage, syncService: service);
      await provider.loadConnections();
      await provider.addConnection(person('one', 'Elena'));
      await provider.addConnection(person('two', 'Priya'));
      provider.bindAuth(auth);
      provider.setSearchQuery('old memory');
      await tester.pump(const Duration(milliseconds: 300));
      provider.setSearchQuery('new memory');
      await tester.pump(const Duration(milliseconds: 701));
      expect(service.requests, ['new memory']);
      provider.setSearchQuery('latest memory');
      await tester.pump(const Duration(milliseconds: 701));
      expect(service.requests, ['new memory', 'latest memory']);
      service.responses[1].complete({
        'matches': [
          match(provider.connections.firstWhere((c) => c.id == 'two')),
        ],
        'indexed': true,
      });
      await tester.pump();
      expect(provider.searchResults.first.connection.id, 'two');
      service.responses[0].complete({
        'matches': [
          match(provider.connections.firstWhere((c) => c.id == 'one')),
        ],
        'indexed': true,
      });
      await tester.pump();
      expect(provider.searchResults.first.connection.id, 'two');
      provider.dispose();
      auth.dispose();
    },
  );
  testWidgets(
    'saving a cue schedules automatic sync and cloud results keep event filters',
    (tester) async {
      final storage = await StorageService.init();
      await storage.activateAccount('alice');
      final service = TestSync(), auth = TestAuth();
      final cards = CardsProvider(storage);
      final provider = ConnectionsProvider(storage, syncService: service);
      await provider.loadConnections();
      await cards.loadCards();
      provider.bindAuth(auth, cards: cards);
      await provider.addConnection(person('one', 'Elena'));
      await tester.pump(const Duration(seconds: 2));
      await tester.pump();
      expect(service.syncCount, 1);
      provider.setSearchQuery('person who can help with quantum computing');
      await tester.pump(const Duration(milliseconds: 701));
      service.responses.last.complete({
        'matches': [match(provider.connections.single)],
        'indexed': true,
      });
      await tester.pump();
      expect(provider.searchResults.first.connection.id, 'one');
      provider.setEventFilter('Different event');
      expect(provider.searchResults, isEmpty);
      provider.dispose();
      cards.dispose();
      auth.dispose();
    },
  );
  test(
    'sync response merges remote contacts without erasing a local edit made in flight',
    () async {
      final storage = await StorageService.init();
      await storage.activateAccount('alice');
      final service = TestSync(), auth = TestAuth();
      final cards = CardsProvider(storage),
          provider = ConnectionsProvider(storage, syncService: service);
      await cards.loadCards();
      await provider.loadConnections();
      await provider.addConnection(person('one', 'Elena'));
      final original = provider.connections.single;
      service.pendingSync = Completer<SyncResult>();
      final task = provider.syncWallet(auth, cards);
      await provider.updateConnection(
        original.copyWith(rawCue: 'New local memory'),
      );
      service.pendingSync!.complete(
        SyncResult(
          success: true,
          message: 'Synced',
          connections: [original, person('two', 'Priya')],
        ),
      );
      await task;
      expect(provider.connections.length, 2);
      expect(
        provider.connections.firstWhere((c) => c.id == 'one').rawCue,
        'New local memory',
      );
      provider.dispose();
      cards.dispose();
      auth.dispose();
    },
  );
  test('a deletion made in flight wins over an older remote record', () async {
    final storage = await StorageService.init();
    await storage.activateAccount('alice');
    final service = TestSync(), auth = TestAuth();
    final cards = CardsProvider(storage),
        provider = ConnectionsProvider(storage, syncService: service);
    await cards.loadCards();
    await provider.loadConnections();
    await provider.addConnection(person('one', 'Elena'));
    final original = provider.connections.single;
    service.pendingSync = Completer<SyncResult>();
    final task = provider.syncWallet(auth, cards);
    await provider.deleteConnection('one');
    service.pendingSync!.complete(
      SyncResult(success: true, message: 'Synced', connections: [original]),
    );
    await task;
    expect(provider.connections, isEmpty);
    expect(storage.loadDeletions().single['id'], 'one');
    provider.dispose();
    cards.dispose();
    auth.dispose();
  });
  testWidgets(
    'a high vector score cannot reintroduce an unrelated plumber into developer results',
    (tester) async {
      final storage = await StorageService.init();
      final service = TestSync(), auth = TestAuth();
      final provider = ConnectionsProvider(storage, syncService: service);
      await provider.loadConnections();
      final plumber = person(
        'plumber',
        'Owen Demo',
      ).copyWith(role: 'Plumber', techStack: ['Plumbing']);
      final developer = person(
        'developer',
        'Dev',
      ).copyWith(role: 'Software developer', techStack: ['Android']);
      await provider.addConnection(plumber);
      await provider.addConnection(developer);
      provider.bindAuth(auth);
      provider.setSearchQuery('I met a tech developer');
      await tester.pump(const Duration(milliseconds: 701));
      service.responses.last.complete({
        'matches': [
          {...match(plumber), 'score': .99},
        ],
        'indexed': true,
      });
      await tester.pump();
      expect(provider.searchResults.map((r) => r.connection.id), ['developer']);
      provider.dispose();
      auth.dispose();
    },
  );
}
