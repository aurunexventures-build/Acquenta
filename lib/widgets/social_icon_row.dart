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
      ...links
          .take(2)
          .map(
            (link) => IconButton(
              tooltip: link.platform.label,
              icon: FaIcon(link.defaultIcon, size: 18, color: color),
              onPressed: () => _open(context, link),
            ),
          ),
      if (links.length > 2)
        PopupMenuButton<CardLink>(
          tooltip: 'More profiles',
          icon: Icon(Icons.more_horiz, color: color),
          onSelected: (link) => _open(context, link),
          itemBuilder: (_) => links
              .skip(2)
              .map(
                (link) => PopupMenuItem(
                  value: link,
                  child: Row(
                    children: [
                      FaIcon(link.defaultIcon, size: 18),
                      const SizedBox(width: 12),
                      Text(link.platform.label),
                    ],
                  ),
                ),
              )
              .toList(),
        ),
    ],
  );
}
