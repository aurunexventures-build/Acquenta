import 'card_finish_picker.dart';
import 'social_icon_row.dart';
import '../screens/card_detail_screen.dart';
import 'face_avatar.dart';
import 'dart:math' as math;
import 'dart:convert';
import 'qr_share_dialog.dart';
import 'package:flutter/material.dart';
import 'package:qr_flutter/qr_flutter.dart';
import '../models/contact_card.dart';
import '../models/event_context.dart';
import '../services/vcard_service.dart';

class InteractiveCardView extends StatefulWidget {
  final ContactCard card;
  final EventContext? activeEvent;
  final bool isExpanded;
  final VoidCallback? onCardTapped;
  final VoidCallback? onEditTapped;
  final VoidCallback? onDeleteTapped;

  const InteractiveCardView({
    super.key,
    required this.card,
    this.activeEvent,
    this.isExpanded = false,
    this.onCardTapped,
    this.onEditTapped,
    this.onDeleteTapped,
  });

  @override
  State<InteractiveCardView> createState() => _InteractiveCardViewState();
}

class _InteractiveCardViewState extends State<InteractiveCardView>
    with SingleTickerProviderStateMixin {
  late AnimationController _flipController;
  late Animation<double> _flipAnimation;
  bool _isFront = true;

  @override
  void initState() {
    super.initState();
    _flipController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 500),
    );
    _flipAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _flipController, curve: Curves.easeInOutCubic),
    );
  }

  @override
  void dispose() {
    _flipController.dispose();
    super.dispose();
  }

  void _toggleFlip() {
    if (_isFront) {
      _flipController.forward();
    } else {
      _flipController.reverse();
    }
    setState(() {
      _isFront = !_isFront;
    });
  }

  // Card theme helper
  _CardThemeConfig _getThemeConfig(String hexColor) {
    final colour = Color(
      int.tryParse(hexColor.replaceFirst('#', 'FF'), radix: 16) ?? 0xFF2563EB,
    );
    final base = Color.lerp(
      colour,
      Colors.black,
      colour.computeLuminance() > .22 ? .65 : .08,
    )!;
    return _CardThemeConfig(
      gradient: LinearGradient(
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
        colors: [base, Color.lerp(base, Colors.black, .16)!],
      ),
      accentColor: const Color(0xFFE7EFFF),
      textColor: Colors.white,
      subtextColor: Colors.white70,
      borderColor: Colors.white24,
      badgeBg: Colors.white12,
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = _getThemeConfig(widget.card.themeColorHex);

    return AnimatedBuilder(
      animation: _flipAnimation,
      builder: (context, child) {
        final angle = _flipAnimation.value * math.pi;
        final isFrontSide = angle < (math.pi / 2);

        return Transform(
          transform: Matrix4.identity()
            ..setEntry(3, 2, 0.001) // 3D perspective
            ..rotateY(angle),
          alignment: Alignment.center,
          child: isFrontSide
              ? _buildFrontCard(theme)
              : Transform(
                  transform: Matrix4.identity()..rotateY(math.pi),
                  alignment: Alignment.center,
                  child: _buildBackCard(theme),
                ),
        );
      },
    );
  }

  Widget _buildFrontCard(_CardThemeConfig theme) {
    return Container(
      width: double.infinity,
      constraints: const BoxConstraints(minHeight: 220),
      decoration: BoxDecoration(
        gradient: theme.gradient,
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: theme.borderColor, width: 1.2),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.35),
            offset: const Offset(0, 10),
            blurRadius: 24,
            spreadRadius: -4,
          ),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: () {
            if (widget.isExpanded) {
              _toggleFlip();
            } else {
              widget.onCardTapped?.call();
            }
          },
          borderRadius: BorderRadius.circular(22),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 22, vertical: 20),
            child: CustomPaint(
              painter: CardFinishPainter(
                widget.card.cardFinish,
                widget.card.fullName,
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  // Top Header Row
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Row(
                        children: [
                          // Tap to Flip Prompt
                          if (widget.isExpanded)
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 8,
                                vertical: 4,
                              ),
                              decoration: BoxDecoration(
                                color: Colors.white.withValues(alpha: 0.08),
                                borderRadius: BorderRadius.circular(12),
                              ),
                              child: const Row(
                                children: [
                                  Icon(
                                    Icons.flip_rounded,
                                    size: 12,
                                    color: Colors.white70,
                                  ),
                                ],
                              ),
                            )
                          else
                            Icon(
                              Icons.nfc_rounded,
                              size: 16,
                              color: theme.subtextColor.withValues(alpha: 0.7),
                            ),
                        ],
                      ),
                    ],
                  ),

                  const SizedBox(height: 20),
                  FaceAvatar(
                    name: widget.card.fullName,
                    photo: widget.card.avatarUrl,
                    radius: 32,
                    backgroundColor: theme.badgeBg,
                    foregroundColor: theme.accentColor,
                  ),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      Flexible(
                        child: Text(
                          widget.card.fullName,
                          style: TextStyle(
                            fontSize: 24,
                            fontWeight: FontWeight.w800,
                            letterSpacing: -0.4,
                            color: theme.textColor,
                          ),
                        ),
                      ),
                      if (widget.card.links.isNotEmpty &&
                          widget.card.links.length <= 2)
                        Flexible(
                          child: SocialIconRow(
                            links: widget.card.links,
                            color: theme.textColor,
                          ),
                        ),
                    ],
                  ),
                  if (widget.card.links.length > 2)
                    SocialIconRow(
                      links: widget.card.links,
                      color: theme.textColor,
                    ),
                  const SizedBox(height: 4),
                  Text(
                    widget.card.role,
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w500,
                      color: theme.subtextColor,
                    ),
                  ),

                  if (widget.isExpanded && widget.card.headline.isNotEmpty) ...[
                    const SizedBox(height: 10),
                    Text(
                      widget.card.headline,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontSize: 12,
                        height: 1.4,
                        color: theme.textColor.withValues(alpha: 0.8),
                      ),
                    ),
                  ],

                  // Bottom Footer on expanded card
                  if (widget.isExpanded) ...[
                    const SizedBox(height: 20),
                    const Divider(color: Color(0x1FFFFFFF), height: 1),
                    const SizedBox(height: 14),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        IconButton(
                          tooltip: 'Details',
                          icon: Icon(
                            Icons.info_outline_rounded,
                            color: theme.subtextColor,
                            size: 20,
                          ),
                          onPressed: () => Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (_) =>
                                  CardDetailScreen(cardId: widget.card.id),
                            ),
                          ),
                        ),
                        Row(
                          children: [
                            if (widget.onEditTapped != null)
                              IconButton(
                                icon: const Icon(Icons.edit_outlined, size: 18),
                                color: Colors.white70,
                                onPressed: widget.onEditTapped,
                                visualDensity: VisualDensity.compact,
                                tooltip: 'Edit Card',
                              ),
                            IconButton(
                              icon: const Icon(
                                Icons.qr_code_2_rounded,
                                size: 20,
                              ),
                              color: theme.accentColor,
                              onPressed: _toggleFlip,
                              visualDensity: VisualDensity.compact,
                              tooltip: 'Flip for QR Code',
                            ),
                          ],
                        ),
                      ],
                    ),
                  ],
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildBackCard(_CardThemeConfig theme) {
    final qrData = VCardService.generateVCard(
      card: widget.card,
      eventContext: widget.activeEvent,
    );
    final fitsQr = utf8.encode(qrData).length <= 2000;

    return Container(
      width: double.infinity,
      constraints: const BoxConstraints(minHeight: 280),
      decoration: BoxDecoration(
        gradient: theme.gradient,
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: theme.borderColor, width: 1.2),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.4),
            offset: const Offset(0, 10),
            blurRadius: 24,
            spreadRadius: -4,
          ),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: _toggleFlip,
          borderRadius: BorderRadius.circular(22),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 22, vertical: 20),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                // Back Header
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      'INSTANT BEAM',
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w700,
                        letterSpacing: 1.2,
                        color: theme.accentColor,
                      ),
                    ),
                    IconButton(
                      icon: const Icon(
                        Icons.close_rounded,
                        size: 18,
                        color: Colors.white70,
                      ),
                      onPressed: _toggleFlip,
                      visualDensity: VisualDensity.compact,
                    ),
                  ],
                ),
                const SizedBox(height: 10),

                // QR Code Container
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(16),
                    boxShadow: const [
                      BoxShadow(
                        color: Colors.black26,
                        blurRadius: 10,
                        offset: Offset(0, 4),
                      ),
                    ],
                  ),
                  child: fitsQr
                      ? QrImageView(
                          data: qrData,
                          version: QrVersions.auto,
                          size: 200,
                          eyeStyle: const QrEyeStyle(
                            eyeShape: QrEyeShape.square,
                            color: Color(0xFF0F172A),
                          ),
                          dataModuleStyle: const QrDataModuleStyle(
                            dataModuleShape: QrDataModuleShape.square,
                            color: Color(0xFF0F172A),
                          ),
                        )
                      : const SizedBox(
                          width: 200,
                          child: Text(
                            'Use Share options for a large card or online link.',
                            style: TextStyle(color: Colors.black),
                          ),
                        ),
                ),

                const SizedBox(height: 14),

                if (widget.activeEvent != null)
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 10,
                      vertical: 4,
                    ),
                    decoration: BoxDecoration(
                      color: Colors.amber.withValues(alpha: 0.15),
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Text(
                      '📍 Stamped: ${widget.activeEvent!.eventName}',
                      style: const TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.bold,
                        color: Colors.amber,
                      ),
                    ),
                  )
                else
                  Text(
                    'Scan in Acquenta to save this card offline',
                    style: TextStyle(fontSize: 11, color: theme.subtextColor),
                  ),

                const SizedBox(height: 14),

                TextButton.icon(
                  onPressed: () => showDialog(
                    context: context,
                    builder: (_) => QrShareDialog(
                      card: widget.card,
                      defaultEventContext: widget.activeEvent,
                    ),
                  ),
                  icon: const Icon(Icons.share),
                  label: const Text('Share options'),
                ),
                // Quick Action Bar
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    OutlinedButton.icon(
                      icon: const Icon(Icons.download_rounded, size: 14),
                      label: const Text('Save vCard'),
                      style: OutlinedButton.styleFrom(
                        foregroundColor: Colors.white,
                        side: BorderSide(
                          color: Colors.white.withValues(alpha: 0.2),
                        ),
                        padding: const EdgeInsets.symmetric(
                          horizontal: 12,
                          vertical: 8,
                        ),
                        textStyle: const TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w600,
                        ),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(20),
                        ),
                      ),
                      onPressed: () {
                        VCardService.shareVCard(
                          card: widget.card,
                          eventContext: widget.activeEvent,
                        );
                      },
                    ),
                    const SizedBox(width: 8),
                    OutlinedButton.icon(
                      icon: const Icon(Icons.flip_to_front_rounded, size: 14),
                      label: const Text('Back to Card'),
                      style: OutlinedButton.styleFrom(
                        foregroundColor: theme.accentColor,
                        side: BorderSide(
                          color: theme.accentColor.withValues(alpha: 0.3),
                        ),
                        padding: const EdgeInsets.symmetric(
                          horizontal: 12,
                          vertical: 8,
                        ),
                        textStyle: const TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w600,
                        ),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(20),
                        ),
                      ),
                      onPressed: _toggleFlip,
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _CardThemeConfig {
  final LinearGradient gradient;
  final Color accentColor;
  final Color textColor;
  final Color subtextColor;
  final Color borderColor;
  final Color badgeBg;

  _CardThemeConfig({
    required this.gradient,
    required this.accentColor,
    required this.textColor,
    required this.subtextColor,
    required this.borderColor,
    required this.badgeBg,
  });
}
