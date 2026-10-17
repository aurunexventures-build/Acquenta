import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';
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
            color: card.isDefault ? accentColor : theme.dividerColor.withValues(alpha: 0.3),
            width: card.isDefault ? 2 : 1,
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
                  colors: [
                    accentColor,
                    accentColor.withValues(alpha: 0.6),
                  ],
                ),
              ),
            ),

            Padding(
              padding: const EdgeInsets.all(18),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Category Badge & Actions Row
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                        decoration: BoxDecoration(
                          color: accentColor.withValues(alpha: 0.12),
                          borderRadius: BorderRadius.circular(20),
                        ),
                        child: Text(
                          card.title.isNotEmpty ? card.title : card.category.displayName,
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.bold,
                            color: accentColor,
                          ),
                        ),
                      ),
                      if (card.isDefault) ...[
                        const SizedBox(width: 8),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                          decoration: BoxDecoration(
                            color: Colors.amber.withValues(alpha: 0.15),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: const Row(
                            children: [
                              Icon(Icons.star, size: 12, color: Colors.amber),
                              SizedBox(width: 3),
                              Text(
                                'Primary',
                                style: TextStyle(
                                  fontSize: 11,
                                  fontWeight: FontWeight.bold,
                                  color: Colors.amber,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                      const Spacer(),
                      if (onShare != null)
                        IconButton(
                          icon: const Icon(Icons.qr_code_2_rounded),
                          tooltip: 'Share Card QR',
                          color: accentColor,
                          onPressed: onShare,
                        ),
                      if (onEdit != null || onDelete != null)
                        PopupMenuButton<String>(
                          icon: const Icon(Icons.more_vert, size: 20),
                          onSelected: (val) {
                            if (val == 'edit') onEdit?.call();
                            if (val == 'delete') onDelete?.call();
                          },
                          itemBuilder: (context) => [
                            if (onEdit != null)
                              const PopupMenuItem(
                                value: 'edit',
                                child: Row(
                                  children: [
                                    Icon(Icons.edit, size: 18),
                                    SizedBox(width: 8),
                                    Text('Edit Card'),
                                  ],
                                ),
                              ),
                            if (onDelete != null)
                              const PopupMenuItem(
                                value: 'delete',
                                child: Row(
                                  children: [
                                    Icon(Icons.delete_outline, size: 18, color: Colors.red),
                                    SizedBox(width: 8),
                                    Text('Delete Card', style: TextStyle(color: Colors.red)),
                                  ],
                                ),
                              ),
                          ],
                        ),
                    ],
                  ),

                  const SizedBox(height: 14),

                  // Avatar & Name Row
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.center,
                    children: [
                      CircleAvatar(
                        radius: 28,
                        backgroundColor: accentColor.withValues(alpha: 0.15),
                        child: Text(
                          card.fullName.isNotEmpty
                              ? card.fullName.trim().split(' ').map((e) => e.isNotEmpty ? e[0] : '').take(2).join()
                              : '?',
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                            color: accentColor,
                          ),
                        ),
                      ),
                      const SizedBox(width: 14),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              card.fullName,
                              style: theme.textTheme.titleLarge?.copyWith(
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            if (card.role.isNotEmpty || card.company.isNotEmpty)
                              Text(
                                [
                                  if (card.role.isNotEmpty) card.role,
                                  if (card.company.isNotEmpty) card.company,
                                ].join(' @ '),
                                style: TextStyle(
                                  fontSize: 13,
                                  color: theme.textTheme.bodyMedium?.color?.withValues(alpha: 0.8),
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                          ],
                        ),
                      ),
                    ],
                  ),

                  if (card.headline.isNotEmpty) ...[
                    const SizedBox(height: 12),
                    Text(
                      card.headline,
                      style: TextStyle(
                        fontSize: 13,
                        color: theme.textTheme.bodyMedium?.color?.withValues(alpha: 0.85),
                      ),
                      maxLines: isCompact ? 2 : 3,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],

                  // Tech Stack / Skills Tags
                  if (card.techStack.isNotEmpty) ...[
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

                  if (!isCompact && card.links.isNotEmpty) ...[
                    const SizedBox(height: 14),
                    const Divider(height: 1),
                    const SizedBox(height: 10),
                    // Links Wrap
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: card.links.map((link) {
                        return ActionChip(
                          avatar: Icon(link.defaultIcon, size: 16, color: accentColor),
                          label: Text(
                            link.title,
                            style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w500),
                          ),
                          onPressed: () async {
                            final uri = Uri.tryParse(link.url);
                            if (uri != null && await canLaunchUrl(uri)) {
                              await launchUrl(uri);
                            }
                          },
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
