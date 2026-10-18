import 'card_link.dart';

enum CardCategory { professional, personal, sideProject, event, custom }

extension CardCategoryExtension on CardCategory {
  String get displayName {
    switch (this) {
      case CardCategory.professional:
        return 'Professional';
      case CardCategory.personal:
        return 'Personal';
      case CardCategory.sideProject:
        return 'Side Project';
      case CardCategory.event:
        return 'Event Specific';
      case CardCategory.custom:
        return 'Custom';
    }
  }
}

class ContactCard {
  final String id;
  final String avatarUrl;
  final String
  title; // Card label, e.g. "Lead Flutter Dev", "Side Project Creator"
  final CardCategory category;
  final String fullName;
  final String headline;
  final String company;
  final String role;
  final String email;
  final String phone;
  final String location;
  final String bio;
  final List<String>
  techStack; // e.g. ["Flutter", "Dart", "Android", "Firebase"]
  final List<CardLink> links;
  final String themeColorHex;
  final bool isDefault;
  final DateTime createdAt;
  final DateTime updatedAt;

  const ContactCard({
    required this.id,
    this.avatarUrl = '',
    required this.title,
    this.category = CardCategory.professional,
    required this.fullName,
    this.headline = '',
    this.company = '',
    this.role = '',
    this.email = '',
    this.phone = '',
    this.location = '',
    this.bio = '',
    this.techStack = const [],
    this.links = const [],
    this.themeColorHex = '#3B82F6',
    this.isDefault = false,
    required this.createdAt,
    required this.updatedAt,
  });

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'avatarUrl': avatarUrl,
      'title': title,
      'category': category.name,
      'fullName': fullName,
      'headline': headline,
      'company': company,
      'role': role,
      'email': email,
      'phone': phone,
      'location': location,
      'bio': bio,
      'techStack': techStack,
      'links': links.map((l) => l.toJson()).toList(),
      'themeColorHex': themeColorHex,
      'isDefault': isDefault,
      'createdAt': createdAt.toIso8601String(),
      'updatedAt': updatedAt.toIso8601String(),
    };
  }

  factory ContactCard.fromJson(Map<String, dynamic> json) {
    return ContactCard(
      id: json['id'] as String? ?? '',
      avatarUrl: json['avatarUrl'] as String? ?? '',
      title: json['title'] as String? ?? 'My Card',
      category: CardCategory.values.firstWhere(
        (e) => e.name == (json['category'] as String?),
        orElse: () => CardCategory.professional,
      ),
      fullName: json['fullName'] as String? ?? '',
      headline: json['headline'] as String? ?? '',
      company: json['company'] as String? ?? '',
      role: json['role'] as String? ?? '',
      email: json['email'] as String? ?? '',
      phone: json['phone'] as String? ?? '',
      location: json['location'] as String? ?? '',
      bio: json['bio'] as String? ?? '',
      techStack:
          (json['techStack'] as List<dynamic>?)
              ?.map((e) => e.toString().trim())
              .where((e) => e.isNotEmpty)
              .toList() ??
          const [],
      links:
          (json['links'] as List<dynamic>?)
              ?.map((e) => CardLink.fromJson(e as Map<String, dynamic>))
              .toList() ??
          const [],
      themeColorHex: json['themeColorHex'] as String? ?? '#3B82F6',
      isDefault: json['isDefault'] as bool? ?? false,
      createdAt: json['createdAt'] != null
          ? DateTime.tryParse(json['createdAt'] as String) ?? DateTime.now()
          : DateTime.now(),
      updatedAt: json['updatedAt'] != null
          ? DateTime.tryParse(json['updatedAt'] as String) ?? DateTime.now()
          : DateTime.now(),
    );
  }

  ContactCard copyWith({
    String? id,
    String? avatarUrl,
    String? title,
    CardCategory? category,
    String? fullName,
    String? headline,
    String? company,
    String? role,
    String? email,
    String? phone,
    String? location,
    String? bio,
    List<String>? techStack,
    List<CardLink>? links,
    String? themeColorHex,
    bool? isDefault,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return ContactCard(
      id: id ?? this.id,
      avatarUrl: avatarUrl ?? this.avatarUrl,
      title: title ?? this.title,
      category: category ?? this.category,
      fullName: fullName ?? this.fullName,
      headline: headline ?? this.headline,
      company: company ?? this.company,
      role: role ?? this.role,
      email: email ?? this.email,
      phone: phone ?? this.phone,
      location: location ?? this.location,
      bio: bio ?? this.bio,
      techStack: techStack ?? this.techStack,
      links: links ?? this.links,
      themeColorHex: themeColorHex ?? this.themeColorHex,
      isDefault: isDefault ?? this.isDefault,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }
}
