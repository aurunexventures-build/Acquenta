import 'package:flutter/material.dart';

enum LinkType {
  website,
  linkedin,
  github,
  twitter,
  email,
  phone,
  whatsapp,
  telegram,
  youtube,
  portfolio,
  custom,
}

class CardLink {
  final String id;
  final String title;
  final String url;
  final LinkType type;

  const CardLink({
    required this.id,
    required this.title,
    required this.url,
    this.type = LinkType.website,
  });

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'title': title,
      'url': url,
      'type': type.name,
    };
  }

  factory CardLink.fromJson(Map<String, dynamic> json) {
    return CardLink(
      id: json['id'] as String? ?? '',
      title: json['title'] as String? ?? '',
      url: json['url'] as String? ?? '',
      type: LinkType.values.firstWhere(
        (e) => e.name == (json['type'] as String?),
        orElse: () => LinkType.website,
      ),
    );
  }

  CardLink copyWith({
    String? id,
    String? title,
    String? url,
    LinkType? type,
  }) {
    return CardLink(
      id: id ?? this.id,
      title: title ?? this.title,
      url: url ?? this.url,
      type: type ?? this.type,
    );
  }

  IconData get defaultIcon {
    switch (type) {
      case LinkType.linkedin:
        return Icons.business_center;
      case LinkType.github:
        return Icons.code;
      case LinkType.twitter:
        return Icons.chat_bubble_outline;
      case LinkType.email:
        return Icons.email_outlined;
      case LinkType.phone:
        return Icons.phone_outlined;
      case LinkType.whatsapp:
        return Icons.chat;
      case LinkType.telegram:
        return Icons.send_rounded;
      case LinkType.youtube:
        return Icons.play_circle_outline;
      case LinkType.portfolio:
        return Icons.web;
      case LinkType.website:
      case LinkType.custom:
        return Icons.link;
    }
  }
}
