import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import '../models/saved_connection.dart';
import 'auth_service.dart';

class SyncResult {
  final bool success;
  final String message;
  final int syncedCount;
  final DateTime? timestamp;

  const SyncResult({
    required this.success,
    required this.message,
    this.syncedCount = 0,
    this.timestamp,
  });
}

class SyncService {
  static const String baseUrl = 'https://metcue-worker.quadban-cloudflare.workers.dev';

  /// Ping Cloudflare Worker health endpoint
  static Future<Map<String, dynamic>?> checkHealth() async {
    try {
      final response = await http.get(Uri.parse('$baseUrl/health')).timeout(
        const Duration(seconds: 5),
      );
      if (response.statusCode == 200) {
        return jsonDecode(response.body) as Map<String, dynamic>;
      }
    } catch (e) {
      debugPrint('SyncService health check failed: $e');
    }
    return null;
  }

  /// Synchronize local saved connections to Cloudflare D1 & Vectorize
  static Future<SyncResult> syncToCloud({
    required List<SavedConnection> connections,
    required AuthService authService,
    DateTime? lastSyncedAt,
  }) async {
    if (!authService.isAuthenticated) {
      return const SyncResult(
        success: false,
        message: 'Sign in to enable Cloudflare Edge Sync & Vector recall.',
      );
    }

    final token = await authService.getIdToken();
    if (token == null) {
      return const SyncResult(
        success: false,
        message: 'Could not obtain authentication token.',
      );
    }

    try {
      final mutations = connections.map((c) => {
        'id': c.id,
        'fullName': c.fullName,
        'company': c.company,
        'role': c.role,
        'headline': c.headline,
        'email': c.email,
        'phone': c.phone,
        'eventName': c.eventContext.eventName,
        'eventDate': c.eventContext.date.toIso8601String(),
        'location': c.eventContext.location,
        'discussionNotes': c.eventContext.notes,
        'techStack': c.techStack,
        'eventTags': c.eventContext.tags,
        'isFavorite': c.isFavorite,
        'savedAt': c.savedAt.toIso8601String(),
      }).toList();

      final body = jsonEncode({
        'lastSyncedAt': lastSyncedAt?.toIso8601String(),
        'mutations': mutations,
      });

      final response = await http.post(
        Uri.parse('$baseUrl/api/v1/sync'),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $token',
        },
        body: body,
      ).timeout(const Duration(seconds: 15));

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        return SyncResult(
          success: true,
          message: 'Synced ${mutations.length} connections to Cloudflare Edge.',
          syncedCount: mutations.length,
          timestamp: DateTime.now(),
        );
      } else {
        return SyncResult(
          success: false,
          message: 'Sync failed: Server returned ${response.statusCode} - ${response.body}',
        );
      }
    } catch (e) {
      debugPrint('SyncService sync error: $e');
      return SyncResult(
        success: false,
        message: 'Sync error: $e',
      );
    }
  }

  /// Perform semantic vector search on Cloudflare Vectorize
  static Future<List<Map<String, dynamic>>> semanticSearch({
    required String query,
    required AuthService authService,
  }) async {
    final token = await authService.getIdToken();
    if (token == null) return [];

    try {
      final uri = Uri.parse('$baseUrl/api/v1/search/semantic').replace(
        queryParameters: {'q': query},
      );
      final response = await http.get(
        uri,
        headers: {
          'Authorization': 'Bearer $token',
        },
      ).timeout(const Duration(seconds: 8));

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        final matches = data['matches'] as List? ?? [];
        return matches.cast<Map<String, dynamic>>();
      }
    } catch (e) {
      debugPrint('Semantic vector search failed: $e');
    }
    return [];
  }
}
