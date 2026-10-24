import 'package:flutter/material.dart';

/// Account identity only; card portraits remain independently editable.
class AccountAvatar extends StatelessWidget {
  final String name, photoUrl;
  const AccountAvatar({super.key, required this.name, this.photoUrl = ''});
  @override
  Widget build(BuildContext context) {
    final initials = name
        .trim()
        .split(RegExp(r'\s+'))
        .where((s) => s.isNotEmpty && s != '@')
        .take(2)
        .map((s) => s.characters.first)
        .join()
        .toUpperCase();
    final fallback = initials.isEmpty
        ? const Icon(
            Icons.person_outline_rounded,
            color: Color(0xFF2563EB),
            size: 20,
          )
        : Text(
            initials,
            style: const TextStyle(
              color: Color(0xFF2563EB),
              fontSize: 12,
              fontWeight: FontWeight.w700,
            ),
          );
    final uri = Uri.tryParse(photoUrl);
    final hasPhoto = uri?.scheme == 'https' && (uri?.host.isNotEmpty ?? false);
    return CircleAvatar(
      radius: 17,
      backgroundColor: const Color(0xFFE6EEFF),
      child: hasPhoto
          ? ClipOval(
              child: Image.network(
                photoUrl,
                width: 34,
                height: 34,
                fit: BoxFit.cover,
                excludeFromSemantics: true,
                webHtmlElementStrategy: WebHtmlElementStrategy.fallback,
                frameBuilder: (_, image, frame, loaded) =>
                    loaded || frame != null ? image : fallback,
                errorBuilder: (_, error, stack) => fallback,
              ),
            )
          : fallback,
    );
  }
}
