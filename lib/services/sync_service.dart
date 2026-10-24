import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import '../models/contact_card.dart';
import '../models/saved_connection.dart';
import 'auth_service.dart';
import 'photo_service.dart';

class AccountDeletedException implements Exception {
  @override
  String toString() => 'This account has been deleted.';
}

class SyncResult {
  final bool success;
  final bool accountDeleted;
  final String message;
  final List<SavedConnection> connections;
  final List<ContactCard> cards;
  final List<Map<String, dynamic>> deleted;
  const SyncResult({
    required this.success,
    this.accountDeleted = false,
    required this.message,
    this.connections = const [],
    this.cards = const [],
    this.deleted = const [],
  });
}

class SyncService {
  static const nativeApiUrl = 'https://acquenta.aurunex.com';
  static final baseUrl = resolveApiBase(
    isWeb: kIsWeb,
    pageUri: Uri.base,
    override: const String.fromEnvironment('METCUE_API_URL'),
  );

  /// Web calls the Worker serving the app. Native apps use the same deployed API.
  /// A separate static preview must explicitly select its API using the override.
  static String resolveApiBase({
    required bool isWeb,
    required Uri pageUri,
    String override = '',
  }) {
    final configured = override.trim();
    if (configured.isNotEmpty) {
      final uri = Uri.tryParse(configured);
      if (uri == null ||
          !['http', 'https'].contains(uri.scheme) ||
          !uri.hasAuthority ||
          uri.hasQuery ||
          uri.hasFragment ||
          (uri.path.isNotEmpty && uri.path != '/')) {
        throw ArgumentError('METCUE_API_URL must be an HTTP(S) origin.');
      }
      return uri.origin;
    }
    if (isWeb &&
        ['http', 'https'].contains(pageUri.scheme) &&
        pageUri.hasAuthority) {
      return pageUri.origin;
    }
    return nativeApiUrl;
  }

  final http.Client client;
  SyncService({http.Client? client}) : client = client ?? http.Client();

  static Future<Map<String, dynamic>?> checkHealth() async {
    try {
      final response = await http
          .get(Uri.parse('$baseUrl/health'))
          .timeout(const Duration(seconds: 5));
      return response.statusCode == 200
          ? jsonDecode(response.body) as Map<String, dynamic>
          : null;
    } catch (_) {
      return null;
    }
  }

  Future<Map<String, dynamic>> request(
    String path,
    Map<String, dynamic> body,
    AuthService auth, {
    String method = 'POST',
  }) async {
    final userId = auth.currentUser?.uid;
    final token = await auth.getIdToken();
    if (token == null || userId != auth.currentUser?.uid) {
      throw Exception(
        'Sign in to Acquenta on this device to use AI and online sharing.',
      );
    }
    final request = http.Request(method, Uri.parse('$baseUrl$path'))
      ..headers.addAll({
        'Content-Type': 'application/json',
        'Authorization': 'Bearer $token',
      });
    if (method != 'GET') request.body = jsonEncode(body);
    final response = await (() async {
      return http.Response.fromStream(await client.send(request));
    })().timeout(const Duration(seconds: 40));
    final data = jsonDecode(response.body) as Map<String, dynamic>;
    if (response.statusCode == 410) throw AccountDeletedException();
    if (response.statusCode != 200) {
      throw Exception(data['error'] ?? 'Service unavailable.');
    }
    return data;
  }

  Future<SyncResult> sync({
    required List<SavedConnection> connections,
    required List<ContactCard> cards,
    required List<Map<String, dynamic>> deleted,
    required AuthService auth,
  }) async {
    try {
      final syncUserId = auth.currentUser?.uid;
      await request('/api/v1/account', {}, auth, method: 'GET');
      final connectionRecords = <Map<String, dynamic>>[];
      for (final c in connections) {
        connectionRecords.add({
          ...c.toJson(),
          'avatarUrl': await PhotoService.uploadIfNeeded(
            c.avatarUrl,
            'connection',
            auth,
            client,
          ),
        });
      }
      final cardRecords = <Map<String, dynamic>>[];
      for (final c in cards) {
        cardRecords.add({
          ...c.toJson(),
          'avatarUrl': await PhotoService.uploadIfNeeded(
            c.avatarUrl,
            'portrait',
            auth,
            client,
          ),
        });
      }
      if (syncUserId == null || syncUserId != auth.currentUser?.uid) {
        throw Exception('Account changed during sync.');
      }
      Map<String, dynamic> data = {};
      var indexed = true;
      for (final batch in syncBatches(
        connectionRecords,
        cardRecords,
        deleted,
      )) {
        if (syncUserId != auth.currentUser?.uid) {
          throw Exception('Account changed during sync.');
        }
        data = await request('/api/v1/sync', batch, auth);
        indexed = indexed && data['indexed'] == true;
      }
      return SyncResult(
        success: true,
        message: indexed
            ? 'Wallet synced. AI search index updated.'
            : 'Wallet synced. Some AI indexing is pending; sync again to retry.',
        connections: (data['connections'] as List)
            .map((c) => SavedConnection.fromJson(Map<String, dynamic>.from(c)))
            .toList(),
        cards: (data['cards'] as List)
            .map((c) => ContactCard.fromJson(Map<String, dynamic>.from(c)))
            .toList(),
        deleted: (data['deleted'] as List)
            .map((e) => Map<String, dynamic>.from(e))
            .toList(),
      );
    } on AccountDeletedException {
      return const SyncResult(
        success: false,
        accountDeleted: true,
        message: 'This account has been deleted.',
      );
    } catch (e) {
      return SyncResult(
        success: false,
        message:
            'Could not sync. Your local wallet is saved. ${e.toString().replaceFirst('Exception: ', '')}',
      );
    }
  }

  /// Keep every upload below the Worker's 512 KB body limit as history grows.
  static List<Map<String, dynamic>> syncBatches(
    List<Map<String, dynamic>> connections,
    List<Map<String, dynamic>> cards,
    List<Map<String, dynamic>> deleted,
  ) {
    Map<String, dynamic> empty() => {
      'protocol': 2,
      'connections': <Map<String, dynamic>>[],
      'cards': <Map<String, dynamic>>[],
      'deleted': <Map<String, dynamic>>[],
    };
    final batches = <Map<String, dynamic>>[];
    var batch = empty();
    var bytes = utf8.encode(jsonEncode(batch)).length;
    var count = 0;
    for (final group in {
      'connections': connections,
      'cards': cards,
      'deleted': deleted,
    }.entries) {
      for (final record in group.value) {
        final size = utf8.encode(jsonEncode(record)).length + 1;
        if (size > 440000) {
          throw StateError(
            'A wallet record is too large to sync. Your local data is kept.',
          );
        }
        if (bytes + size > 450000 || count >= 500) {
          batches.add(batch);
          batch = empty();
          bytes = utf8.encode(jsonEncode(batch)).length;
          count = 0;
        }
        (batch[group.key] as List<Map<String, dynamic>>).add(record);
        bytes += size;
        count++;
      }
    }
    if (count > 0 || batches.isEmpty) batches.add(batch);
    return batches;
  }

  Future<Map<String, dynamic>> generateCues(
    String text,
    String eventName,
    AuthService auth, {
    List<Map<String, String>> conversation = const [],
    bool askFollowUp = true,
  }) => request('/api/v1/cues/generate', {
    'text': text,
    'eventName': eventName,
    'conversation': conversation,
    'askFollowUp': askFollowUp,
  }, auth);

  Future<Map<String, dynamic>> semanticSearch(String query, AuthService auth) =>
      request('/api/v1/search/semantic', {'query': query}, auth);

  void close() => client.close();
}
