import 'dart:convert';
import 'package:intl/intl.dart';
import '../models/saved_connection.dart';

class FollowUpCalendar {
  static String generate(SavedConnection connection) {
    final due = connection.followUpAt!.toUtc();
    String stamp(DateTime d) =>
        DateFormat("yyyyMMdd'T'HHmmss'Z'").format(d.toUtc());
    String escape(String s) => s
        .replaceAll('\\', '\\\\')
        .replaceAll('\r', '')
        .replaceAll('\n', r'\n')
        .replaceAll(';', r'\;')
        .replaceAll(',', r'\,');
    final lines = [
      'BEGIN:VCALENDAR',
      'VERSION:2.0',
      'PRODID:-//Acquenta//Follow-ups//EN',
      'BEGIN:VEVENT',
      'UID:metcue-${connection.id}-${due.millisecondsSinceEpoch}',
      'DTSTAMP:${stamp(DateTime.now())}',
      'DTSTART:${stamp(due)}',
      'DTEND:${stamp(due.add(const Duration(minutes: 15)))}',
      'SUMMARY:${escape('Follow up with ${connection.fullName}')}',
      'DESCRIPTION:${escape(connection.followUpNote)}',
      'BEGIN:VALARM',
      'TRIGGER:-PT10M',
      'ACTION:DISPLAY',
      'DESCRIPTION:Acquenta follow-up',
      'END:VALARM',
      'END:VEVENT',
      'END:VCALENDAR',
      '',
    ];
    return lines.map(_fold).join('\r\n');
  }

  // RFC 5545: fold at 75 UTF-8 octets without splitting a character.
  static String _fold(String line) {
    final out = StringBuffer();
    var octets = 0;
    for (final rune in line.runes) {
      final character = String.fromCharCode(rune);
      final size = utf8.encode(character).length;
      if (octets + size > 75) {
        out.write('\r\n ');
        octets = 1;
      }
      out.write(character);
      octets += size;
    }
    return out.toString();
  }
}
