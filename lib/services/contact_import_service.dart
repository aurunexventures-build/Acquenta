import 'dart:convert';
import 'package:csv/csv.dart';
import 'package:uuid/uuid.dart';
import '../models/event_context.dart';
import '../models/saved_connection.dart';
import 'card_exchange_service.dart';

class ContactImportPreview {
  final List<SavedConnection> contacts;
  final List<String> warnings;
  const ContactImportPreview(this.contacts, this.warnings);
}

class ContactImportService {
  static ContactImportPreview parse(String input) {
    final text = input.replaceFirst('\uFEFF', '').trim();
    if (utf8.encode(text).length > 1000000) {
      throw const FormatException('Choose a file smaller than 1 MB.');
    }
    if (text.isEmpty) throw const FormatException('This file is empty.');
    final contacts = <SavedConnection>[], warnings = <String>[];
    if (text.toUpperCase().startsWith('BEGIN:VCARD')) {
      final cards = RegExp(
        r'BEGIN:VCARD[\s\S]*?END:VCARD',
        caseSensitive: false,
      ).allMatches(text).toList();
      if (cards.length > 500) {
        throw const FormatException('Import up to 500 contacts at a time.');
      }
      for (var i = 0; i < cards.length; i++) {
        try {
          contacts.add(
            CardExchangeService.parseVCard(
              cards[i]
                  .group(0)!
                  .replaceAll(
                    RegExp('BEGIN:VCARD', caseSensitive: false),
                    'BEGIN:VCARD',
                  )
                  .replaceAll(
                    RegExp('END:VCARD', caseSensitive: false),
                    'END:VCARD',
                  ),
            ),
          );
        } catch (_) {
          warnings.add('Card ${i + 1}: unsupported or missing name; skipped.');
        }
      }
      if (cards.length !=
          RegExp('BEGIN:VCARD', caseSensitive: false).allMatches(text).length) {
        warnings.add('An incomplete card was skipped.');
      }
    } else {
      final normalized = text.replaceAll('\r\n', '\n').replaceAll('\r', '\n');
      final rows = const CsvToListConverter(
        shouldParseNumbers: false,
        eol: '\n',
      ).convert(normalized);
      if (rows.length > 501) {
        throw const FormatException('Import up to 500 contacts at a time.');
      }
      String key(Object? v) =>
          v.toString().toLowerCase().replaceAll(RegExp('[^a-z0-9]'), '');
      final header = rows.first.map(key).toList();
      for (var i = 1; i < rows.length; i++) {
        final row = rows[i];
        String get(List<String> keys) {
          for (final k in keys) {
            final index = header.indexOf(k);
            if (index >= 0 &&
                index < row.length &&
                row[index].toString().trim().isNotEmpty) {
              return row[index].toString().trim();
            }
          }
          return '';
        }

        final name = get(['fullname', 'name', 'displayname']);
        final fullName = name.isNotEmpty
            ? name
            : [
                get(['firstname', 'givenname']),
                get(['lastname', 'familyname']),
              ].where((e) => e.isNotEmpty).join(' ');
        if (row.every((e) => e.toString().trim().isEmpty)) continue;
        if (fullName.isEmpty) {
          warnings.add('Row ${i + 1}: missing name; skipped.');
          continue;
        }
        final email = get(['email', 'emailaddress', 'email1value']);
        final phone = get([
          'phone',
          'mobile',
          'phonenumber',
          'phone1value',
          'mobilephone',
        ]);
        final now = DateTime.now();
        contacts.add(
          SavedConnection(
            id: const Uuid().v5(
              Namespace.url.value,
              'import:${email.toLowerCase()}|$phone|${fullName.toLowerCase()}',
            ),
            fullName: fullName,
            email: email,
            phone: phone,
            company: get(['company', 'organization', 'organization1name']),
            role: get(['role', 'title', 'jobtitle', 'organization1title']),
            eventContext: EventContext(
              eventName: 'Imported contacts',
              date: now,
              notes: get(['notes', 'note']),
            ),
            savedAt: now,
          ),
        );
      }
    }
    for (final c in contacts) {
      validate(c);
    }
    if (contacts.isEmpty) {
      throw const FormatException(
        'No supported contacts found. CSV needs a Name or First Name/Last Name header; vCards need FN.',
      );
    }
    return ContactImportPreview(contacts, warnings);
  }

  static void validate(SavedConnection c) {
    if (c.fullName.trim().isEmpty ||
        c.fullName.length > 200 ||
        c.company.length > 2000 ||
        c.role.length > 2000 ||
        c.email.length > 2000 ||
        c.phone.length > 2000 ||
        c.eventContext.notes.length > 6000 ||
        c.links.length > 20 ||
        c.techStack.length > 30) {
      throw const FormatException(
        'A contact has missing or oversized fields. Review the source file.',
      );
    }
  }
}
