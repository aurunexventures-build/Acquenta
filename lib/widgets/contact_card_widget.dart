import 'social_icon_row.dart';
import 'face_avatar.dart';
import 'package:flutter/material.dart';
import '../models/contact_card.dart';
import 'tag_chip.dart';

class ContactCardWidget extends StatelessWidget {
  final ContactCard card;
  final VoidCallback? onTap;
  final VoidCallback? onShare;
  final VoidCallback? onEdit;
  final VoidCallback? onDelete;
  final bool isCompact;

  const ContactCardWidget({
    super.key,
    required this.card,
    this.onTap,
    this.onShare,
    this.onEdit,
    this.onDelete,
    this.isCompact = false,
  });

  Color _parseColor(String hex) {
    try {
      final clean = hex.replaceAll('#', '');
      return Color(int.parse('FF$clean', radix: 16));
    } catch (_) {
      return const Color(0xFF2563EB);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final accentColor = _parseColor(card.themeColorHex);

    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(20),
      child: Container(
        decoration: BoxDecoration(
          color: theme.cardColor,
          borderRadius: BorderRadius.circular(20),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.06),
              blurRadius: 16,
              offset: const Offset(0, 4),
            ),
          ],
          border: Border.all(
            color: theme.dividerColor.withValues(alpha: 0.3),
            width: 1,
          ),
        ),
        clipBehavior: Clip.antiAlias,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Top Accent Ribbon
            Container(
              height: 8,
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [accentColor, accentColor.withValues(alpha: 0.6)],
                ),
              ),
            ),

            Padding(
              padding: const EdgeInsets.all(18),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Avatar & Name Row
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.center,
                    children: [
                      FaceAvatar(
                        name: card.fullName,
                        photo: card.avatarUrl,
                        radius: 28,
                        backgroundColor: Colors.blue.withValues(alpha: .15),
                        foregroundColor: Colors.blue,
                      ),
                      const SizedBox(width: 14),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                Flexible(
                                  child: Text(
                                    card.fullName,
                                    style: theme.textTheme.titleLarge?.copyWith(
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                ),
                                if (card.links.isNotEmpty &&
                                    card.links.length <= 2)
                                  Flexible(
                                    child: SocialIconRow(
                                      links: card.links,
                                      color: accentColor,
                                    ),
                                  ),
                              ],
                            ),
                            if (card.links.length > 2)
                              SocialIconRow(
                                links: card.links,
                                color: accentColor,
                              ),
                            if (card.role.isNotEmpty || card.company.isNotEmpty)
                              Text(
                                [
                                  if (card.role.isNotEmpty) card.role,
                                  if (card.company.isNotEmpty) card.company,
                                ].join(' @ '),
                                style: TextStyle(
                                  fontSize: 13,
                                  color: theme.textTheme.bodyMedium?.color
                                      ?.withValues(alpha: 0.8),
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                          ],
                        ),
                      ),
                    ],
                  ),

                  if (!isCompact && card.headline.isNotEmpty) ...[
                    const SizedBox(height: 12),
                    Text(
                      card.headline,
                      style: TextStyle(
                        fontSize: 13,
                        color: theme.textTheme.bodyMedium?.color?.withValues(
                          alpha: 0.85,
                        ),
                      ),
                      maxLines: isCompact ? 2 : 3,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],

                  // Tech Stack / Skills Tags
                  if (!isCompact && card.techStack.isNotEmpty) ...[
                    const SizedBox(height: 12),
                    Wrap(
                      spacing: 6,
                      runSpacing: 6,
                      children: card.techStack.map((tech) {
                        return TagChip(
                          label: tech,
                          backgroundColor: accentColor.withValues(alpha: 0.08),
                          textColor: accentColor,
                        );
                      }).toList(),
                    ),
                  ],
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
