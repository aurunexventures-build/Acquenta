import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'photo_service.dart';
import 'package:share_plus/share_plus.dart';
import '../models/contact_card.dart';
import '../models/saved_connection.dart';
import '../models/event_context.dart';

class VCardService {
  static String escape(String value) => value
      .replaceAll('\\', '\\\\')
      .replaceAll('\r\n', '\n')
      .replaceAll('\r', '\n')
      .replaceAll('\n', r'\n')
      .replaceAll(';', r'\;')
      .replaceAll(',', r'\,');
  // Fold by UTF-8 bytes, keeping characters and escaped values intact.
  static String _fold(String line) {
    final out = StringBuffer();
    var bytes = 0;
    for (final rune in line.runes) {
      final char = String.fromCharCode(rune),
          size = utf8.encode(String.fromCharCode(rune)).length;
      if (bytes + size > 75) {
        out.write('\r\n ');
        bytes = 1;
      }
      out.write(char);
      bytes += size;
    }
    return out.toString();
  }

  static String generateVCard({
    required ContactCard card,
    EventContext? eventContext,
  }) {
    final fields = <String>[
      'BEGIN:VCARD',
      'VERSION:3.0',
      'FN:${escape(card.fullName)}',
      'N:;${escape(card.fullName)};;;',
      'X-METCUE-ID:${escape(card.id)}',
      'X-ACQUENTA-FINISH:${escape(card.cardFinish)}',
      'X-ACQUENTA-COLOR:${escape(card.themeColorHex)}',
      if (PhotoService.portraitUrl(card.avatarUrl) != null) ...[
        'PHOTO;VALUE=URI:${PhotoService.portraitUrl(card.avatarUrl)}',
        'X-METCUE-PORTRAIT:${card.avatarUrl.substring(9)}',
      ],
      if (card.headline.isNotEmpty)
        'X-METCUE-HEADLINE:${escape(card.headline)}',
      if (card.location.isNotEmpty)
        'ADR;TYPE=WORK:;;${escape(card.location)};;;;',
      if (card.company.isNotEmpty) 'ORG:${escape(card.company)}',
      if (card.role.isNotEmpty) 'TITLE:${escape(card.role)}',
      if (card.phone.isNotEmpty) 'TEL;TYPE=CELL:${escape(card.phone)}',
      if (card.email.isNotEmpty) 'EMAIL:${escape(card.email)}',
      for (final link in card.links)
        'URL;TYPE=${link.title.replaceAll(RegExp(r'[^a-zA-Z0-9_]'), '_')}:${escape(link.url)}',
      if (card.techStack.isNotEmpty)
        'X-METCUE-SKILLS:${card.techStack.map(escape).join(',')}',
      if (card.techStack.isNotEmpty)
        'CATEGORIES:${card.techStack.map(escape).join(',')}',
      if (eventContext != null) ...[
        'X-METCUE-EVENT:${escape(eventContext.eventName)}',
        'X-METCUE-DATE:${eventContext.date.toUtc().toIso8601String()}',
        'X-METCUE-LOCATION:${escape(eventContext.location)}',
      ],
      'NOTE:${escape([
        card.headline,
        card.bio,
        if (eventContext != null) ...['Met at: ${eventContext.eventName}', eventContext.notes],
      ].where((e) => e.isNotEmpty).join('\n'))}',
      'END:VCARD',
    ];
    return '${fields.map(_fold).join('\r\n')}\r\n';
  }

  static String generateConnectionVCard(SavedConnection connection) =>
      generateVCard(
        card: ContactCard(
          id: connection.id,
          avatarUrl: connection.avatarUrl.startsWith('portrait:')
              ? connection.avatarUrl
              : '',
          title: connection.role,
          cardFinish: connection.cardFinish,
          themeColorHex: connection.themeColorHex.isEmpty
              ? '#343B49'
              : connection.themeColorHex,
          fullName: connection.fullName,
          role: connection.role,
          company: connection.company,
          email: connection.email,
          phone: connection.phone,
          headline: connection.headline,
          techStack: connection.techStack,
          links: connection.links,
          createdAt: connection.savedAt,
          updatedAt: connection.updatedAt,
        ),
        eventContext: connection.eventContext,
      );
  static Future<void> exportContact({
    required String vcard,
    required String name,
    Rect? sharePositionOrigin,
  }) async {
    if (!kIsWeb && defaultTargetPlatform == TargetPlatform.iOS) {
      await const MethodChannel(
        'acquenta/contacts',
      ).invokeMethod<bool>('saveContact', {'vcard': vcard});
      return;
    }
    await Share.shareXFiles(
      [
        XFile.fromData(
          utf8.encode(vcard),
          mimeType: 'text/vcard',
          name: 'contact.vcf',
        ),
      ],
      fileNameOverrides: ['contact.vcf'],
      subject: '$name - Acquenta',
      sharePositionOrigin: sharePositionOrigin,
    );
  }

  static Future<void> shareVCard({
    required ContactCard card,
    EventContext? eventContext,
    Rect? sharePositionOrigin,
  }) async {
    final data = generateVCard(card: card, eventContext: eventContext);
    await Share.shareXFiles(
      [
        XFile.fromData(
          utf8.encode(data),
          mimeType: 'text/vcard',
          name: 'contact.vcf',
        ),
      ],
      fileNameOverrides: ['contact.vcf'],
      subject: '${card.fullName} - Acquenta',
      sharePositionOrigin: sharePositionOrigin,
    );
  }
}
