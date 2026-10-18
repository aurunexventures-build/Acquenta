import '../models/saved_connection.dart';

/// Editable, offline suggestions drawn only from saved context.
class ReconnectService {
  static String draft(SavedConnection person) {
    final name = person.fullName.trim();
    final event = person.eventContext.eventName.trim();
    return 'Hi ${name.isEmpty ? 'there' : name}, hope you’re well!'
        '${event.isEmpty || ['Networking', 'General Networking', 'Networking Event'].contains(event) ? '' : ' We connected at $event.'}'
        ' It would be lovely to catch up. Would you be free sometime soon?';
  }

  static List<String> prompts(SavedConnection person) => [
    if (person.followUpNote.trim().isNotEmpty && !person.followUpCompleted)
      'Your planned follow-up: ${person.followUpNote}',
    if (person.eventContext.notes.trim().isNotEmpty)
      'Revisit your conversation: ${person.eventContext.notes}',
    if (person.callWhen.isNotEmpty)
      'Possible reason to reconnect: ${person.callWhen.first}',
    if (person.interactions.isNotEmpty)
      'Review your latest saved interaction before reaching out.',
    if (person.eventContext.notes.trim().isEmpty && person.callWhen.isEmpty)
      'Ask what they have been working on recently.',
  ];
}
