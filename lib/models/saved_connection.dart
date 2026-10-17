import 'card_link.dart';
import 'event_context.dart';

class SavedConnection {
  final String id;
  final String fullName;
  final String role;
  final String company;
  final String headline;
  final String email;
  final String phone;
  final String avatarUrl;
  final List<String> techStack;
  final List<CardLink> links;
  final EventContext eventContext;
  final String futureSelfNote; // "Message to Future Self": human vibe, personal impression, collaboration intent
  final List<String> vibeTags; // e.g. ["Aspirational", "Great Energy", "Future Co-founder", "Sharp Thinker"]
  // Cognitive Episodic Memory Anchors (for 1-year human recall)
  final String distinctiveMemory; // Quirky or visual anchor e.g. "Tall guy with yellow backpack", "Carried retro Leica"
  final String microContext; // Micro-environment e.g. "Over matcha latte at coffee break", "Hallway after Cam's talk"
  final List<String> callWhen; // Situational triggers e.g. ["Need Mobile App", "On-device AI", "Seed Round", "Design Critique"]
  final DateTime savedAt;
  final bool isFavorite;

  const SavedConnection({
    required this.id,
    required this.fullName,
    this.role = '',
    this.company = '',
    this.headline = '',
    this.email = '',
    this.phone = '',
    this.avatarUrl = '',
    this.techStack = const [],
    this.links = const [],
    required this.eventContext,
    this.futureSelfNote = '',
    this.vibeTags = const [],
    this.distinctiveMemory = '',
    this.microContext = '',
    this.callWhen = const [],
    required this.savedAt,
    this.isFavorite = false,
  });

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'fullName': fullName,
      'role': role,
      'company': company,
      'headline': headline,
      'email': email,
      'phone': phone,
      'avatarUrl': avatarUrl,
      'techStack': techStack,
      'links': links.map((l) => l.toJson()).toList(),
      'eventContext': eventContext.toJson(),
      'futureSelfNote': futureSelfNote,
      'vibeTags': vibeTags,
      'distinctiveMemory': distinctiveMemory,
      'microContext': microContext,
      'callWhen': callWhen,
      'savedAt': savedAt.toIso8601String(),
      'isFavorite': isFavorite,
    };
  }

  factory SavedConnection.fromJson(Map<String, dynamic> json) {
    return SavedConnection(
      id: json['id'] as String? ?? '',
      fullName: json['fullName'] as String? ?? 'Unnamed Connection',
      role: json['role'] as String? ?? '',
      company: json['company'] as String? ?? '',
      headline: json['headline'] as String? ?? '',
      email: json['email'] as String? ?? '',
      phone: json['phone'] as String? ?? '',
      avatarUrl: json['avatarUrl'] as String? ?? '',
      techStack: (json['techStack'] as List<dynamic>?)
              ?.map((e) => e.toString().trim())
              .where((e) => e.isNotEmpty)
              .toList() ??
          const [],
      links: (json['links'] as List<dynamic>?)
              ?.map((e) => CardLink.fromJson(e as Map<String, dynamic>))
              .toList() ??
          const [],
      eventContext: json['eventContext'] != null
          ? EventContext.fromJson(json['eventContext'] as Map<String, dynamic>)
          : EventContext(
              eventName: 'Networking Event',
              date: DateTime.now(),
            ),
      futureSelfNote: json['futureSelfNote'] as String? ?? '',
      vibeTags: (json['vibeTags'] as List<dynamic>?)
              ?.map((e) => e.toString().trim())
              .where((e) => e.isNotEmpty)
              .toList() ??
          const [],
      distinctiveMemory: json['distinctiveMemory'] as String? ?? '',
      microContext: json['microContext'] as String? ?? '',
      callWhen: (json['callWhen'] as List<dynamic>?)
              ?.map((e) => e.toString().trim())
              .where((e) => e.isNotEmpty)
              .toList() ??
          const [],
      savedAt: json['savedAt'] != null
          ? DateTime.tryParse(json['savedAt'] as String) ?? DateTime.now()
          : DateTime.now(),
      isFavorite: json['isFavorite'] as bool? ?? false,
    );
  }

  SavedConnection copyWith({
    String? id,
    String? fullName,
    String? role,
    String? company,
    String? headline,
    String? email,
    String? phone,
    String? avatarUrl,
    List<String>? techStack,
    List<CardLink>? links,
    EventContext? eventContext,
    String? futureSelfNote,
    List<String>? vibeTags,
    String? distinctiveMemory,
    String? microContext,
    List<String>? callWhen,
    DateTime? savedAt,
    bool? isFavorite,
  }) {
    return SavedConnection(
      id: id ?? this.id,
      fullName: fullName ?? this.fullName,
      role: role ?? this.role,
      company: company ?? this.company,
      headline: headline ?? this.headline,
      email: email ?? this.email,
      phone: phone ?? this.phone,
      avatarUrl: avatarUrl ?? this.avatarUrl,
      techStack: techStack ?? this.techStack,
      links: links ?? this.links,
      eventContext: eventContext ?? this.eventContext,
      futureSelfNote: futureSelfNote ?? this.futureSelfNote,
      vibeTags: vibeTags ?? this.vibeTags,
      distinctiveMemory: distinctiveMemory ?? this.distinctiveMemory,
      microContext: microContext ?? this.microContext,
      callWhen: callWhen ?? this.callWhen,
      savedAt: savedAt ?? this.savedAt,
      isFavorite: isFavorite ?? this.isFavorite,
    );
  }
}
