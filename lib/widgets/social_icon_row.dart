import 'package:flutter/material.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'package:url_launcher/url_launcher.dart';
import '../models/card_link.dart';

class SocialIconRow extends StatelessWidget {
  final List<CardLink> links;
  final Color? color;
  const SocialIconRow({super.key, required this.links, this.color});

  Future<void> _open(BuildContext context, CardLink link) async {
    try {
      final uri = Uri.parse(CardLink.normalizeInput(link.type, link.url));
      if (!await launchUrl(uri, mode: LaunchMode.externalApplication) &&
          context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Unable to open this profile.')),
        );
      }
    } catch (_) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Check this profile in the card editor.'),
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) => Wrap(
    spacing: 0,
    runSpacing: 0,
    children: [
      for (final link in links)
        IconButton(
          tooltip: link.platform.label,
          icon: FaIcon(link.defaultIcon, size: 18, color: color),
          onPressed: () => _open(context, link),
        ),
    ],
  );
}
