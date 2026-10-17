class EventContext {
  final String eventName;
  final String location;
  final DateTime date;
  final String notes;
  final List<String> tags; // e.g. ["Flutter", "Android", "AI Agents", "Cloudflare"]

  const EventContext({
    required this.eventName,
    this.location = '',
    required this.date,
    this.notes = '',
    this.tags = const [],
  });

  Map<String, dynamic> toJson() {
    return {
      'eventName': eventName,
      'location': location,
      'date': date.toIso8601String(),
      'notes': notes,
      'tags': tags,
    };
  }

  factory EventContext.fromJson(Map<String, dynamic> json) {
    return EventContext(
      eventName: json['eventName'] as String? ?? 'General Meetup',
      location: json['location'] as String? ?? '',
      date: json['date'] != null
          ? DateTime.tryParse(json['date'] as String) ?? DateTime.now()
          : DateTime.now(),
      notes: json['notes'] as String? ?? '',
      tags: (json['tags'] as List<dynamic>?)
              ?.map((e) => e.toString().trim())
              .where((e) => e.isNotEmpty)
              .toList() ??
          const [],
    );
  }

  EventContext copyWith({
    String? eventName,
    String? location,
    DateTime? date,
    String? notes,
    List<String>? tags,
  }) {
    return EventContext(
      eventName: eventName ?? this.eventName,
      location: location ?? this.location,
      date: date ?? this.date,
      notes: notes ?? this.notes,
      tags: tags ?? this.tags,
    );
  }
}
