import 'package:flutter/material.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';

enum LinkType {
  instagram,
  facebook,
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
    return {'id': id, 'title': title, 'url': url, 'type': type.name};
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

  CardLink copyWith({String? id, String? title, String? url, LinkType? type}) {
    return CardLink(
      id: id ?? this.id,
      title: title ?? this.title,
      url: url ?? this.url,
      type: type ?? this.type,
    );
  }

  LinkType get platform => inferPlatform(url) ?? type;

  static LinkType? inferPlatform(String value) {
    final uri = Uri.tryParse(value.contains('://') ? value : 'https://$value');
    final host = uri?.host.toLowerCase().replaceFirst(RegExp(r'^www\.'), '');
    const hosts = {
      'instagram.com': LinkType.instagram,
      'facebook.com': LinkType.facebook,
      'linkedin.com': LinkType.linkedin,
      'github.com': LinkType.github,
      'x.com': LinkType.twitter,
      'twitter.com': LinkType.twitter,
      'youtube.com': LinkType.youtube,
      'youtu.be': LinkType.youtube,
      't.me': LinkType.telegram,
      'wa.me': LinkType.whatsapp,
    };
    return hosts[host];
  }

  static String normalizeInput(LinkType type, String input) {
    final value = input.trim();
    if (value.isEmpty) throw const FormatException('Enter a username or URL.');
    final parsed = Uri.tryParse(value);
    if (parsed != null && parsed.hasScheme) {
      if (!['https', 'http', 'mailto', 'tel'].contains(parsed.scheme) ||
          (['https', 'http'].contains(parsed.scheme) && parsed.host.isEmpty)) {
        throw const FormatException('Use a valid profile or website URL.');
      }
      return parsed.toString();
    }
    if (inferPlatform(value) != null) return 'https://$value';
    if (type == LinkType.email) return 'mailto:$value';
    if (type == LinkType.phone) return 'tel:$value';
    if (type == LinkType.whatsapp) {
      final number = value.replaceAll(RegExp(r'[^0-9]'), '');
      if (number.isEmpty) {
        throw const FormatException('Enter a phone number with country code.');
      }
      return 'https://wa.me/$number';
    }
    var handle = value.replaceFirst(RegExp(r'^@'), '');
    if (type == LinkType.linkedin) {
      handle = handle.replaceFirst(RegExp(r'^/?in/'), '');
    }
    handle = handle.replaceAll(RegExp(r'/+$'), '');
    const bases = {
      LinkType.instagram: 'https://www.instagram.com/',
      LinkType.facebook: 'https://www.facebook.com/',
      LinkType.linkedin: 'https://www.linkedin.com/in/',
      LinkType.github: 'https://github.com/',
      LinkType.twitter: 'https://x.com/',
      LinkType.telegram: 'https://t.me/',
      LinkType.youtube: 'https://www.youtube.com/@',
    };
    if (bases.containsKey(type)) {
      if (!RegExp(r'^[a-zA-Z0-9_.-]+$').hasMatch(handle)) {
        throw const FormatException(
          'Enter just your username, or paste the full profile URL.',
        );
      }
      return '${bases[type]}$handle';
    }
    final uri = Uri.tryParse('https://$value');
    if (uri == null ||
        !uri.host.contains('.') ||
        value.contains(RegExp(r'\s'))) {
      throw const FormatException('Enter a website such as example.com.');
    }
    return uri.toString();
  }

  IconData get defaultIcon => switch (platform) {
    LinkType.instagram => FontAwesomeIcons.instagram,
    LinkType.facebook => FontAwesomeIcons.facebook,
    LinkType.linkedin => FontAwesomeIcons.linkedin,
    LinkType.github => FontAwesomeIcons.github,
    LinkType.twitter => FontAwesomeIcons.xTwitter,
    LinkType.whatsapp => FontAwesomeIcons.whatsapp,
    LinkType.telegram => FontAwesomeIcons.telegram,
    LinkType.youtube => FontAwesomeIcons.youtube,
    LinkType.email => Icons.email_outlined,
    LinkType.phone => Icons.phone_outlined,
    _ => Icons.language,
  };
}

extension LinkTypeLabel on LinkType {
  String get label => switch (this) {
    LinkType.linkedin => 'LinkedIn',
    LinkType.instagram => 'Instagram',
    LinkType.facebook => 'Facebook',
    LinkType.github => 'GitHub',
    LinkType.twitter => 'X / Twitter',
    LinkType.youtube => 'YouTube',
    LinkType.whatsapp => 'WhatsApp',
    LinkType.telegram => 'Telegram',
    LinkType.email => 'Email',
    LinkType.phone => 'Phone',
    LinkType.website => 'Website',
    LinkType.portfolio => 'Portfolio',
    LinkType.custom => 'Other',
  };
  bool get usesUsername => [
    LinkType.instagram,
    LinkType.facebook,
    LinkType.linkedin,
    LinkType.github,
    LinkType.twitter,
    LinkType.telegram,
    LinkType.youtube,
  ].contains(this);
}
