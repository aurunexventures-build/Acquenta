import 'dart:convert';
import 'dart:typed_data';
import 'package:crypto/crypto.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import 'auth_service.dart';
import 'sync_service.dart';

class PhotoService {
  static const maxBytes = 512 * 1024;

  /// Import the Google portrait into our normal upload pipeline, rather than
  /// storing an external URL that cannot be synced or shared offline.
  static Future<String?> importGooglePortrait(
    String url, {
    http.Client? client,
  }) async {
    final uri = Uri.tryParse(url);
    if (uri == null ||
        uri.scheme != 'https' ||
        !(uri.host == 'googleusercontent.com' ||
            uri.host.endsWith('.googleusercontent.com'))) {
      return null;
    }
    final transport = client ?? http.Client();
    try {
      final response = await transport
          .send(http.Request('GET', uri)..followRedirects = false)
          .timeout(const Duration(seconds: 8));
      if (response.statusCode != 200 ||
          (response.contentLength ?? 0) > maxBytes) {
        return null;
      }
      final bytes = BytesBuilder();
      await for (final chunk in response.stream.timeout(
        const Duration(seconds: 8),
      )) {
        if (bytes.length + chunk.length > maxBytes) return null;
        bytes.add(chunk);
      }
      return localPhoto(bytes.takeBytes());
    } catch (_) {
      return null; // A missing portrait must never block card creation.
    } finally {
      if (client == null) transport.close();
    }
  }

  static String mimeType(Uint8List bytes) {
    if (bytes.length >= 3 &&
        bytes[0] == 255 &&
        bytes[1] == 216 &&
        bytes[2] == 255) {
      return 'image/jpeg';
    }
    if (bytes.length >= 8 &&
        List.generate(8, (i) => bytes[i]).join(',') ==
            '137,80,78,71,13,10,26,10') {
      return 'image/png';
    }
    if (bytes.length >= 12 &&
        ascii.decode(bytes.sublist(0, 4), allowInvalid: true) == 'RIFF' &&
        ascii.decode(bytes.sublist(8, 12), allowInvalid: true) == 'WEBP') {
      return 'image/webp';
    }
    throw const FormatException('Choose a JPEG, PNG or WebP photo.');
  }

  static String localPhoto(Uint8List bytes) {
    if (bytes.isEmpty || bytes.length > maxBytes) {
      throw const FormatException('Choose a photo smaller than 512 KB.');
    }
    return 'data:${mimeType(bytes)};base64,${base64Encode(bytes)}';
  }

  static Uint8List decodeLocal(String value) {
    if (value.length > maxBytes * 1.4) {
      throw const FormatException('Photo is too large.');
    }
    final comma = value.indexOf(',');
    if (comma < 0) throw const FormatException('Invalid photo.');
    final bytes = base64Decode(value.substring(comma + 1));
    mimeType(bytes);
    if (bytes.length > maxBytes) {
      throw const FormatException('Photo is too large.');
    }
    return bytes;
  }

  static bool isReference(String value) =>
      RegExp(r'^(portrait|photo):[\w-]{36}$').hasMatch(value);
  static String? portraitUrl(String ref) =>
      RegExp(r'^portrait:[\w-]{36}$').hasMatch(ref)
      ? '${SyncService.baseUrl}/api/v1/portraits/${ref.substring(9)}'
      : null;

  static Future<String> uploadIfNeeded(
    String value,
    String purpose,
    AuthService auth,
    http.Client client,
  ) async {
    if (!value.startsWith('data:')) return value;
    final uid = auth.currentUser?.uid, token = await auth.getIdToken();
    if (uid == null || token == null || uid != auth.currentUser?.uid) {
      throw Exception('Sign in to sync photos.');
    }
    final bytes = decodeLocal(value),
        prefs = await SharedPreferences.getInstance();
    final key = '$uid:photo-upload:$purpose:${sha256.convert(bytes)}';
    final cached = prefs.getString(key);
    if (cached != null) return cached;
    if (uid != auth.currentUser?.uid) {
      throw Exception('Account changed during photo upload.');
    }
    final response = await client
        .post(
          Uri.parse('${SyncService.baseUrl}/api/v1/photos?purpose=$purpose'),
          headers: {
            'Authorization': 'Bearer $token',
            'Content-Type': mimeType(bytes),
          },
          body: bytes,
        )
        .timeout(const Duration(seconds: 30));
    if (response.statusCode != 200) {
      throw Exception('Could not upload the photo. The local copy is kept.');
    }
    final ref = jsonDecode(response.body)['reference'] as String;
    if (!isReference(ref) || uid != auth.currentUser?.uid) {
      throw Exception('Account changed during photo upload.');
    }
    await prefs.setString(key, ref);
    await prefs.setString('$uid:photo-cache:$ref', value);
    return ref;
  }

  static Future<Uint8List?> load(String ref, AuthService? auth) async {
    if (ref.isEmpty) return null;
    if (ref.startsWith('data:')) return decodeLocal(ref);
    if (!isReference(ref)) return null;
    final uid = auth?.currentUser?.uid;
    if (ref.startsWith('photo:') && uid == null) return null;
    final prefs = await SharedPreferences.getInstance(),
        cacheKey = '${uid ?? 'guest'}:photo-cache:$ref';
    final cached = prefs.getString(cacheKey);
    if (cached != null) return decodeLocal(cached);
    final client = http.Client();
    try {
      http.Response response;
      if (ref.startsWith('portrait:')) {
        response = await client
            .get(Uri.parse(portraitUrl(ref)!))
            .timeout(const Duration(seconds: 10));
      } else {
        response = http.Response('', 404);
      }
      if (response.statusCode != 200 && uid != null) {
        final token = await auth?.getIdToken();
        if (token == null) return null;
        response = await client
            .get(
              Uri.parse(
                '${SyncService.baseUrl}/api/v1/photos/${ref.split(':').last}',
              ),
              headers: {'Authorization': 'Bearer $token'},
            )
            .timeout(const Duration(seconds: 10));
      }
      if (response.statusCode != 200 || uid != auth?.currentUser?.uid) {
        return null;
      }
      final local = localPhoto(response.bodyBytes);
      await prefs.setString(cacheKey, local);
      return response.bodyBytes;
    } catch (_) {
      return null;
    } finally {
      client.close();
    }
  }
}
