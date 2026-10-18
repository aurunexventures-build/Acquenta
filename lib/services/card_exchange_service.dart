import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:uuid/uuid.dart';
import '../models/card_link.dart';
import '../models/contact_card.dart';
import '../models/event_context.dart';
import '../models/saved_connection.dart';
import 'sync_service.dart';

class CardExchangeService {
  static String _unescape(String input) => input.replaceAllMapped(
    RegExp(r'\\([nN,;\\])'),
    (m) => m[1]!.toLowerCase() == 'n' ? '\n' : m[1]!,
  );
  static List<String> _parts(String value) => value
      .split(RegExp(r'(?<!\\),'))
      .map(_unescape)
      .where((e) => e.isNotEmpty)
      .toList();

  static SavedConnection parseVCard(String input, {EventContext? activeEvent}) {
    if (input.length > 30000 ||
        !input.trim().startsWith('BEGIN:VCARD') ||
        !input.trim().endsWith('END:VCARD')) {
      throw const FormatException('Scan a contact QR or paste a vCard.');
    }
    if (RegExp('BEGIN:VCARD').allMatches(input).length != 1) {
      throw const FormatException('Import one card at a time.');
    }
    final values = <String, List<String>>{}, links = <CardLink>[];
    final unfolded = input.replaceAll(RegExp(r'\r?\n[ \t]'), '');
    for (final line in unfolded.split(RegExp(r'\r?\n'))) {
      final colon = line.indexOf(':');
      if (colon < 0) continue;
      final key = line.substring(0, colon).split(';').first.toUpperCase(),
          value = line.substring(colon + 1);
      values.putIfAbsent(key, () => []).add(value);
      if (key == 'URL' &&
          RegExp(r'^https?://', caseSensitive: false).hasMatch(value)) {
        final label =
            RegExp(r'TYPE=([^;:]+)', caseSensitive: false)
                .firstMatch(line.substring(0, colon))
                ?.group(1)
                ?.replaceAll('_', ' ') ??
            'Profile';
        links.add(
          CardLink(
            id: const Uuid().v4(),
            title: label,
            url: _unescape(value),
            type: LinkType.custom,
          ),
        );
      }
    }
    String get(String key) => _unescape(values[key]?.first ?? '');
    final name = get('FN');
    if (name.trim().isEmpty) {
      throw const FormatException('This contact card has no name.');
    }
    final sourceId = get('X-METCUE-ID');
    final id = const Uuid().v5(
      Namespace.url.value,
      sourceId.isNotEmpty ? 'metcue:$sourceId' : input.trim(),
    );
    final now = DateTime.now();
    return SavedConnection(
      id: id,
      fullName: name,
      avatarUrl: RegExp(r'^[\w-]{36}$').hasMatch(get('X-METCUE-PORTRAIT'))
          ? 'portrait:${get('X-METCUE-PORTRAIT')}'
          : '',
      role: get('TITLE'),
      company: get('ORG'),
      email: get('EMAIL'),
      phone: get('TEL'),
      links: links,
      techStack: _parts(
        values['X-METCUE-SKILLS']?.first ?? values['CATEGORIES']?.first ?? '',
      ),
      headline: get('X-METCUE-HEADLINE'),
      eventContext: EventContext(
        eventName:
            activeEvent?.eventName ??
            (get('X-METCUE-EVENT').isEmpty
                ? 'Networking'
                : get('X-METCUE-EVENT')),
        location: activeEvent?.location ?? get('X-METCUE-LOCATION'),
        date:
            activeEvent?.date ?? DateTime.tryParse(get('X-METCUE-DATE')) ?? now,
        notes: get('NOTE'),
        tags: activeEvent?.tags ?? const [],
      ),
      savedAt: now,
      updatedAt: now,
    );
  }

  static SavedConnection fromCard(ContactCard card, {EventContext? event}) {
    final now = DateTime.now();
    return SavedConnection(
      id: const Uuid().v5(Namespace.url.value, 'metcue:${card.id}'),
      fullName: card.fullName,
      avatarUrl: card.avatarUrl,
      role: card.role,
      company: card.company,
      headline: card.headline,
      email: card.email,
      phone: card.phone,
      techStack: card.techStack,
      links: card.links,
      eventContext: event ?? EventContext(eventName: 'Networking', date: now),
      savedAt: now,
      updatedAt: now,
    );
  }

  static Future<SavedConnection> decode(
    String input, {
    EventContext? activeEvent,
    http.Client? client,
  }) async {
    final value = input.trim();
    if (value.startsWith('BEGIN:VCARD')) {
      return parseVCard(value, activeEvent: activeEvent);
    }
    final uri = Uri.tryParse(value), api = Uri.parse(SyncService.baseUrl);
    if (uri == null ||
        !uri.hasScheme ||
        !uri.hasAuthority ||
        uri.origin != api.origin ||
        uri.pathSegments.length != 2 ||
        uri.pathSegments.first != 'c' ||
        !RegExp(r'^[\w-]{20,100}$').hasMatch(uri.pathSegments.last)) {
      throw const FormatException('Use a Acquenta card link or a contact QR.');
    }
    final owned = client == null, transport = client ?? http.Client();
    try {
      final response = await transport
          .get(
            Uri.parse(
              '${SyncService.baseUrl}/api/v1/cards/shared/${uri.pathSegments.last}',
            ),
          )
          .timeout(const Duration(seconds: 12));
      if (response.statusCode != 200) {
        throw const FormatException('This shared card is unavailable.');
      }
      final card = ContactCard.fromJson(
        Map<String, dynamic>.from(jsonDecode(response.body)['card']),
      );
      final eventName = uri.queryParameters['event'];
      return fromCard(
        card,
        event:
            activeEvent ??
            (eventName == null
                ? null
                : EventContext(eventName: eventName, date: DateTime.now())),
      );
    } finally {
      if (owned) transport.close();
    }
  }
}
