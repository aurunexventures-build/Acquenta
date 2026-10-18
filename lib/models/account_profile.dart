import 'card_link.dart';

/// Private source details. Cards receive independent, editable copies.
class AccountProfile {
  final String firstName, lastName, phone, role, company, intro;
  final List<String> emails;
  final List<CardLink> links;
  final DateTime updatedAt;
  const AccountProfile({
    required this.firstName,
    this.lastName = '',
    this.phone = '',
    this.role = '',
    this.company = '',
    this.intro = '',
    this.emails = const [],
    this.links = const [],
    required this.updatedAt,
  });
  String get fullName =>
      [firstName, lastName].where((s) => s.isNotEmpty).join(' ');
  String get primaryEmail => emails.firstOrNull ?? '';
  void validate() {
    if (firstName.trim().isEmpty ||
        firstName.length > 100 ||
        lastName.length > 100) {
      throw const FormatException(
        'Enter your first name and check the length of your name.',
      );
    }
    if (phone.length > 100 ||
        role.length > 200 ||
        company.length > 200 ||
        intro.length > 300) {
      throw const FormatException('One of your profile details is too long.');
    }
    if (emails.length > 5 ||
        emails.any(
          (e) =>
              e.length > 320 ||
              !RegExp(r'^[^\s@]+@[^\s@]+\.[^\s@]+$').hasMatch(e),
        ) ||
        emails.map((e) => e.toLowerCase()).toSet().length != emails.length) {
      throw const FormatException(
        'Use up to five different, valid contact email addresses.',
      );
    }
    if (links.length > 20) {
      throw const FormatException('Use up to 20 social profiles or websites.');
    }
  }

  Map<String, dynamic> toJson() => {
    'firstName': firstName,
    'lastName': lastName,
    'phone': phone,
    'role': role,
    'company': company,
    'intro': intro,
    'emails': emails,
    'links': links.map((l) => l.toJson()).toList(),
    'updatedAt': updatedAt.toUtc().toIso8601String(),
  };
  factory AccountProfile.fromJson(Map<String, dynamic> json) => AccountProfile(
    firstName: json['firstName'] as String? ?? '',
    lastName: json['lastName'] as String? ?? '',
    phone: json['phone'] as String? ?? '',
    role: json['role'] as String? ?? '',
    company: json['company'] as String? ?? '',
    intro: json['intro'] as String? ?? '',
    emails: (json['emails'] as List? ?? []).cast<String>(),
    links: (json['links'] as List? ?? [])
        .map((v) => CardLink.fromJson(Map<String, dynamic>.from(v)))
        .toList(),
    updatedAt: DateTime.parse(json['updatedAt'] as String),
  );
}
