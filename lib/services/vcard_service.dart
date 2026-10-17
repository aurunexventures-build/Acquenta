import '../models/contact_card.dart';
import '../models/saved_connection.dart';
import '../models/event_context.dart';
import 'package:intl/intl.dart';
import 'package:share_plus/share_plus.dart';

class VCardService {
  /// Generates a vCard 3.0 string for a user's own ContactCard, optionally
  /// stamping the current event context so the recipient receives it!
  static String generateVCard({
    required ContactCard card,
    EventContext? eventContext,
  }) {
    final buffer = StringBuffer();
    buffer.writeln('BEGIN:VCARD');
    buffer.writeln('VERSION:3.0');
    buffer.writeln('FN:${card.fullName}');
    
    // Split name into Last;First
    final parts = card.fullName.trim().split(' ');
    if (parts.length > 1) {
      final firstName = parts.first;
      final lastName = parts.sublist(1).join(' ');
      buffer.writeln('N:$lastName;$firstName;;;');
    } else {
      buffer.writeln('N:${card.fullName};;;;');
    }

    if (card.company.isNotEmpty) {
      buffer.writeln('ORG:${card.company}');
    }
    if (card.role.isNotEmpty) {
      buffer.writeln('TITLE:${card.role}');
    }
    if (card.phone.isNotEmpty) {
      buffer.writeln('TEL;TYPE=CELL,VOICE:${card.phone}');
    }
    if (card.email.isNotEmpty) {
      buffer.writeln('EMAIL;TYPE=INTERNET,WORK:${card.email}');
    }

    for (final link in card.links) {
      if (link.url.isNotEmpty) {
        buffer.writeln('URL;TYPE=${link.title.replaceAll(' ', '_')}:${link.url}');
      }
    }

    // Build comprehensive note with event context and tech stack
    final noteParts = <String>[];
    if (card.headline.isNotEmpty) {
      noteParts.add(card.headline);
    }
    if (card.bio.isNotEmpty) {
      noteParts.add(card.bio);
    }
    if (card.techStack.isNotEmpty) {
      noteParts.add('Tech Stack: ${card.techStack.join(', ')}');
    }
    if (eventContext != null && eventContext.eventName.isNotEmpty) {
      final dateStr = DateFormat('yyyy-MM-dd').format(eventContext.date);
      noteParts.add('--- Context ---');
      noteParts.add('Met At: ${eventContext.eventName} ($dateStr)');
      if (eventContext.location.isNotEmpty) {
        noteParts.add('Location: ${eventContext.location}');
      }
      if (eventContext.notes.isNotEmpty) {
        noteParts.add('Discussion: ${eventContext.notes}');
      }
    }

    if (noteParts.isNotEmpty) {
      final escapedNote = noteParts.join('\\n').replaceAll('\n', '\\n');
      buffer.writeln('NOTE:$escapedNote');
    }

    // Categories for contact indexing
    final categories = <String>{
      ...card.techStack,
      if (eventContext != null && eventContext.eventName.isNotEmpty)
        eventContext.eventName,
    };
    if (categories.isNotEmpty) {
      buffer.writeln('CATEGORIES:${categories.join(',')}');
    }

    buffer.writeln('END:VCARD');
    return buffer.toString();
  }

  /// Generates a vCard for an existing saved connection
  static String generateConnectionVCard(SavedConnection connection) {
    final buffer = StringBuffer();
    buffer.writeln('BEGIN:VCARD');
    buffer.writeln('VERSION:3.0');
    buffer.writeln('FN:${connection.fullName}');

    final parts = connection.fullName.trim().split(' ');
    if (parts.length > 1) {
      buffer.writeln('N:${parts.sublist(1).join(' ')};${parts.first};;;');
    } else {
      buffer.writeln('N:${connection.fullName};;;;');
    }

    if (connection.company.isNotEmpty) {
      buffer.writeln('ORG:${connection.company}');
    }
    if (connection.role.isNotEmpty) {
      buffer.writeln('TITLE:${connection.role}');
    }
    if (connection.phone.isNotEmpty) {
      buffer.writeln('TEL;TYPE=CELL,VOICE:${connection.phone}');
    }
    if (connection.email.isNotEmpty) {
      buffer.writeln('EMAIL;TYPE=INTERNET,WORK:${connection.email}');
    }

    for (final link in connection.links) {
      if (link.url.isNotEmpty) {
        buffer.writeln('URL;TYPE=${link.title.replaceAll(' ', '_')}:${link.url}');
      }
    }

    final noteParts = <String>[];
    if (connection.headline.isNotEmpty) {
      noteParts.add(connection.headline);
    }
    if (connection.techStack.isNotEmpty) {
      noteParts.add('Tech Stack: ${connection.techStack.join(', ')}');
    }
    
    final ev = connection.eventContext;
    if (ev.eventName.isNotEmpty) {
      final dateStr = DateFormat('yyyy-MM-dd').format(ev.date);
      noteParts.add('--- Event Memory Context ---');
      noteParts.add('Met At: ${ev.eventName} ($dateStr)');
      if (ev.location.isNotEmpty) {
        noteParts.add('Location: ${ev.location}');
      }
      if (ev.notes.isNotEmpty) {
        noteParts.add('Notes: ${ev.notes}');
      }
    }

    if (noteParts.isNotEmpty) {
      final escapedNote = noteParts.join('\\n').replaceAll('\n', '\\n');
      buffer.writeln('NOTE:$escapedNote');
    }

    final categories = <String>{
      ...connection.techStack,
      if (ev.eventName.isNotEmpty) ev.eventName,
      ...ev.tags,
    };
    if (categories.isNotEmpty) {
      buffer.writeln('CATEGORIES:${categories.join(',')}');
    }

    buffer.writeln('END:VCARD');
    return buffer.toString();
  }

  /// Exports and shares the vCard via system share sheet
  static Future<void> shareVCard({
    required ContactCard card,
    EventContext? eventContext,
  }) async {
    final vcard = generateVCard(card: card, eventContext: eventContext);
    await Share.share(
      vcard,
      subject: '${card.fullName} - MetCue Digital Card',
    );
  }
}
