import 'dart:convert';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:contact_card_builder/models/contact_card.dart';
import 'package:contact_card_builder/models/event_context.dart';
import 'package:contact_card_builder/models/saved_connection.dart';
import 'package:contact_card_builder/services/auth_service.dart';
import 'package:contact_card_builder/services/card_exchange_service.dart';
import 'package:contact_card_builder/services/photo_service.dart';
import 'package:contact_card_builder/services/search_service.dart';
import 'package:contact_card_builder/services/sync_service.dart';
import 'package:contact_card_builder/services/vcard_service.dart';
import 'package:contact_card_builder/widgets/voice_capture_dialog.dart';
import 'sync_search_test.dart' show TestAuth;

const asset = '00000000-0000-0000-0000-000000000001';

class InterviewService extends SyncService {
  final calls = <List<Map<String, String>>>[];
  @override
  Future<Map<String, dynamic>> generateCues(
    String text,
    String eventName,
    AuthService auth, {
    List<Map<String, String>> conversation = const [],
    bool askFollowUp = true,
  }) async {
    calls.add(conversation);
    return {
      'cues': {
        'summary': 'Designer focused on recycled packaging',
        'skills': ['Packaging'],
        'followUpQuestion': conversation.length >= 2
            ? ''
            : conversation.isEmpty
            ? 'What stood out about them?'
            : 'When would you reconnect?',
      },
      'rawCue': text,
    };
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUp(() => SharedPreferences.setMockInitialValues({}));
  test(
    'blocked and unavailable photo checks stay uncached and expose safe messages',
    () async {
      final auth = TestAuth();
      final local = PhotoService.localPhoto(
        Uint8List.fromList([255, 216, 255, 224]),
      );
      for (final status in [422, 429, 503]) {
        var calls = 0;
        final client = MockClient((_) async {
          calls++;
          return http.Response('{"error":"secret provider details"}', status);
        });
        for (var i = 0; i < 2; i++) {
          await expectLater(
            PhotoService.uploadIfNeeded(local, 'portrait', auth, client),
            throwsA(
              isA<PhotoSafetyException>().having(
                (e) => e.message,
                'safe message',
                isNot(contains('secret')),
              ),
            ),
          );
        }
        expect(calls, 2);
        client.close();
      }
      auth.dispose();
    },
  );
  test(
    'photo bytes stay locally available and upload once per account and purpose',
    () async {
      final bytes = Uint8List.fromList([
        255,
        216,
        255,
        224,
        0,
        16,
        74,
        70,
        73,
        70,
      ]);
      final local = PhotoService.localPhoto(bytes);
      expect(PhotoService.decodeLocal(local), bytes);
      final auth = TestAuth();
      var uploads = 0;
      final client = MockClient((request) async {
        uploads++;
        expect(request.headers['Authorization'], 'Bearer test-token');
        expect(request.bodyBytes, bytes);
        return http.Response(jsonEncode({'reference': 'photo:$asset'}), 200);
      });
      final first = await PhotoService.uploadIfNeeded(
            local,
            'connection',
            auth,
            client,
          ),
          second = await PhotoService.uploadIfNeeded(
            local,
            'connection',
            auth,
            client,
          );
      expect(first, second);
      expect(uploads, 1);
      expect(await PhotoService.load(first, auth), bytes);
      auth.signedIn = false;
      expect(await PhotoService.load(first, auth), isNull);
      client.close();
      auth.dispose();
    },
  );
  test(
    'invalid photos cannot be stored and private wallet photos do not enter exported cards',
    () {
      expect(
        () =>
            PhotoService.localPhoto(Uint8List.fromList(utf8.encode('<svg/>'))),
        throwsFormatException,
      );
      expect(
        () => PhotoService.localPhoto(Uint8List(512 * 1024 + 1)),
        throwsFormatException,
      );
      final now = DateTime.now();
      final person = SavedConnection(
        id: 'private',
        fullName: 'Priya',
        avatarUrl: 'photo:$asset',
        eventContext: EventContext(eventName: 'Meetup', date: now),
        savedAt: now,
      );
      final exported = VCardService.generateConnectionVCard(person);
      expect(exported, isNot(contains(asset)));
      final card = ContactCard(
        id: 'portrait',
        fullName: 'Priya',
        title: 'Designer',
        avatarUrl: 'portrait:$asset',
        createdAt: now,
        updatedAt: now,
      );
      final received = CardExchangeService.parseVCard(
        VCardService.generateVCard(card: card),
      );
      expect(received.avatarUrl, card.avatarUrl);
      expect(
        VCardService.generateVCard(
          card: card.copyWith(avatarUrl: 'data:image/jpeg;base64,AAAA'),
        ),
        isNot(contains('base64')),
      );
    },
  );
  test(
    'answers are retained through JSON and searchable by their original wording',
    () {
      final now = DateTime.now(),
          person = SavedConnection(
            id: 'person',
            fullName: 'Priya',
            rawCue: 'Met a designer',
            cueConversation: [
              {'question': 'What stood out?', 'answer': 'Recycled packaging'},
            ],
            eventContext: EventContext(eventName: 'Meetup', date: now),
            savedAt: now,
          );
      final saved = SavedConnection.fromJson(
        jsonDecode(jsonEncode(person.toJson())),
      );
      expect(saved.cueConversation, person.cueConversation);
      expect(
        SearchService.search(
          connections: [saved],
          query: 'recycled',
        ).single.connection.id,
        'person',
      );
    },
  );
  testWidgets(
    'AI organises once without an interview and keeps original words',
    (tester) async {
      tester.view.physicalSize = const Size(360, 780);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      final auth = TestAuth(), service = InterviewService();
      SavedConnection? saved;
      await tester.pumpWidget(
        ChangeNotifierProvider<AuthService>.value(
          value: auth,
          child: MaterialApp(
            home: Scaffold(
              body: VoiceCaptureDialog(
                service: service,
                onCaptured: (c) {
                  saved = c;
                },
              ),
            ),
          ),
        ),
      );
      await tester.enterText(find.widgetWithText(TextField, 'Name'), 'Priya');
      await tester.enterText(
        find.widgetWithText(TextField, 'Say it in your own words'),
        'Met a designer after the talk',
      );
      await tester.ensureVisible(find.text('Organise with AI'));
      await tester.tap(find.text('Organise with AI'));
      await tester.pumpAndSettle();
      expect(find.text('What stood out about them?'), findsNothing);
      expect(find.text('Your answer'), findsNothing);
      expect(
        find.text('Designer focused on recycled packaging'),
        findsOneWidget,
      );
      expect(service.calls.length, 1);
      await tester.ensureVisible(find.text('Save'));
      await tester.tap(find.text('Save'));
      await tester.pumpAndSettle();
      expect(saved?.rawCue, 'Met a designer after the talk');
      expect(
        saved?.eventContext.notes,
        'Designer focused on recycled packaging',
      );
      expect(saved?.cueConversation, isEmpty);
      expect(tester.takeException(), isNull);
      service.close();
      auth.dispose();
    },
  );
}
