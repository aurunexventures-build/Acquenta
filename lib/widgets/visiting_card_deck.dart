import 'dart:math' as math;
import 'package:flutter/material.dart';
import '../models/contact_card.dart';
import '../models/saved_connection.dart';
import 'face_avatar.dart';

class WalletEntry {
  final String id, name, role, company, pitch, email, phone, photo, label;
  final List<String> details;
  final Color color;
  final bool locked;
  final VoidCallback onOpen;
  final VoidCallback? onSend;
  final Widget? trailing, matchNote;
  WalletEntry({
    required this.id,
    required this.name,
    required this.role,
    this.company = '',
    this.pitch = '',
    this.details = const [],
    this.email = '',
    this.phone = '',
    this.photo = '',
    this.label = '',
    this.color = const Color(0xFF262336),
    this.locked = false,
    required this.onOpen,
    this.onSend,
    this.trailing,
    this.matchNote,
  });
  factory WalletEntry.own(
    ContactCard card, {
    required VoidCallback onOpen,
    VoidCallback? onSend,
    bool locked = false,
  }) => WalletEntry(
    id: card.id,
    locked: locked,
    label:
        '${locked
            ? 'Locked · '
            : card.isDefault
            ? 'Primary · '
            : ''}${card.title}',
    name: card.fullName,
    role: card.role,
    company: card.company,
    pitch: card.headline,
    details: [
      if (card.location.isNotEmpty) card.location,
      ...card.links.take(3).map((link) => '${link.title}: ${link.url}'),
    ],
    email: card.email,
    phone: card.phone,
    photo: card.avatarUrl,
    color: Color(
      int.tryParse('FF${card.themeColorHex.replaceAll('#', '')}', radix: 16) ??
          0xFF262336,
    ),
    onOpen: onOpen,
    onSend: onSend,
  );
  factory WalletEntry.person(
    SavedConnection person, {
    required VoidCallback onOpen,
    Widget? trailing,
    int index = 0,
    Widget? matchNote,
  }) => WalletEntry(
    id: person.id,
    name: person.fullName,
    role: person.role,
    company: person.company,
    pitch: person.headline,
    email: person.email,
    phone: person.phone,
    photo: person.avatarUrl,
    color: const [
      Color(0xFF262336),
      Color(0xFF173B36),
      Color(0xFF373052),
      Color(0xFF43301E),
    ][index % 4],
    onOpen: onOpen,
    trailing: trailing,
    matchNote: matchNote,
  );
}

/// Real overlapping cards. Only the last face is exposed; every header remains tappable.
class VisitingCardDeck extends StatelessWidget {
  final List<WalletEntry> entries;
  final bool compact, ranked;
  final int rankStart;
  const VisitingCardDeck({
    super.key,
    required this.entries,
    this.compact = false,
    this.ranked = false,
    this.rankStart = 1,
  });
  @override
  Widget build(BuildContext context) {
    if (entries.isEmpty) return const SizedBox.shrink();
    if (!compact && (ranked || entries.length == 1)) {
      return Align(
        alignment: Alignment.topLeft,
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 560),
          child: _CardFace(
            key: ValueKey(
              '${ranked ? 'recall-result' : 'wallet-card'}-${entries.first.id}',
            ),
            entry: entries.first,
            compact: false,
            rank: ranked ? rankStart : null,
            naturalHeight: true,
          ),
        ),
      );
    }
    return Align(
      alignment: Alignment.topLeft,
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 560),
        child: LayoutBuilder(
          builder: (context, box) {
            final scale = math.max(
              1.0,
              MediaQuery.textScalerOf(context).scale(14) / 14,
            );
            final notes = entries.any((entry) => entry.matchNote != null);
            final height =
                (compact
                    ? (notes ? 144.0 : 112.0)
                    : math.max(
                        notes ? 270.0 : 240.0,
                        240.0 +
                            entries
                                    .map((e) => e.details.length)
                                    .fold<int>(0, math.max) *
                                34,
                      )) *
                scale;
            final step = (compact ? (notes ? 128.0 : 92.0) : 104.0) * scale;
            if (!compact) {
              return Stack(
                clipBehavior: Clip.none,
                children: [
                  for (var i = 0; i < entries.length - 1; i++)
                    Positioned(
                      top: i * step,
                      left: 0,
                      right: 0,
                      height: height,
                      child: _CardFace(
                        key: ValueKey('wallet-card-${entries[i].id}'),
                        entry: entries[i],
                        compact: false,
                      ),
                    ),
                  Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      SizedBox(height: (entries.length - 1) * step),
                      _CardFace(
                        key: ValueKey('wallet-card-${entries.last.id}'),
                        entry: entries.last,
                        compact: false,
                        naturalHeight: true,
                      ),
                    ],
                  ),
                ],
              );
            }
            return SizedBox(
              height: height + (entries.length - 1) * step,
              child: Stack(
                clipBehavior: Clip.none,
                children: [
                  for (final indexed in entries.asMap().entries)
                    Positioned(
                      top: indexed.key * step,
                      left: 0,
                      right: 0,
                      height: height,
                      child: _CardFace(
                        key: ValueKey(
                          '${ranked ? 'recall-result' : 'wallet-card'}-${indexed.value.id}',
                        ),
                        entry: indexed.value,
                        compact: compact,
                        rank: ranked ? indexed.key + rankStart : null,
                      ),
                    ),
                ],
              ),
            );
          },
        ),
      ),
    );
  }
}

class _CardFace extends StatelessWidget {
  final WalletEntry entry;
  final bool compact;
  final int? rank;
  final bool naturalHeight;
  const _CardFace({
    super.key,
    required this.entry,
    required this.compact,
    this.rank,
    this.naturalHeight = false,
  });
  @override
  Widget build(BuildContext context) {
    // White lettering stays legible even for a bright custom card colour.
    final base = entry.locked
        ? const Color(0xFF77777D)
        : Color.lerp(
            entry.color,
            Colors.black,
            entry.color.computeLuminance() > .22 ? .65 : .18,
          )!;
    final dark = Color.lerp(base, Colors.black, .32)!;
    return Semantics(
      button: true,
      label:
          '${rank == null ? '' : 'Recommendation $rank, '}${entry.name}, ${entry.role}',
      child: Material(
        color: dark,
        borderRadius: BorderRadius.circular(18),
        elevation: 3,
        shadowColor: Colors.black26,
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: entry.onOpen,
          child: Container(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [base, dark],
              ),
              border: Border.all(color: Colors.white24),
              borderRadius: BorderRadius.circular(18),
            ),
            padding: const EdgeInsets.all(16),
            child: Column(
              mainAxisSize: naturalHeight ? MainAxisSize.min : MainAxisSize.max,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (entry.matchNote != null) ...[
                  entry.matchNote!,
                  const SizedBox(height: 10),
                ],
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    if (entry.locked)
                      const Padding(
                        padding: EdgeInsets.only(right: 8),
                        child: Icon(
                          Icons.lock_outline,
                          color: Colors.white70,
                          size: 20,
                        ),
                      ),
                    if (rank != null)
                      Padding(
                        padding: const EdgeInsets.only(right: 10, top: 4),
                        child: Text(
                          '$rank',
                          style: const TextStyle(
                            color: Color(0xFFD8F397),
                            fontSize: 20,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ),
                    ...[
                      FaceAvatar(
                        name: entry.name,
                        photo: entry.photo,
                        radius: naturalHeight ? 25 : 16,
                        backgroundColor: Colors.white12,
                        foregroundColor: Colors.white,
                      ),
                      const SizedBox(width: 12),
                    ],
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          if (entry.label.isNotEmpty)
                            Text(
                              entry.label,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(
                                color: Color(0xFFD8F397),
                                fontSize: 10,
                              ),
                            ),
                          Text(
                            entry.name,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 18,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                          const SizedBox(height: 4),
                          if (entry.role.isNotEmpty || entry.company.isNotEmpty)
                            Text(
                              entry.role.isEmpty ? entry.company : entry.role,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(
                                color: Colors.white70,
                                fontSize: 12,
                              ),
                            ),
                        ],
                      ),
                    ),
                    if (entry.onSend != null)
                      TextButton.icon(
                        onPressed: entry.onSend,
                        style: TextButton.styleFrom(
                          foregroundColor: const Color(0xFFD8F397),
                          padding: const EdgeInsets.symmetric(horizontal: 8),
                          minimumSize: const Size(48, 44),
                        ),
                        icon: const Icon(Icons.ios_share_rounded, size: 16),
                        label: const Text('Send'),
                      ),
                    if (entry.trailing != null) entry.trailing!,
                    if (entry.onSend == null && entry.trailing == null)
                      const Icon(Icons.chevron_right, color: Colors.white70),
                  ],
                ),
                if (!compact) ...[
                  const SizedBox(height: 12),
                  if (entry.company.isNotEmpty)
                    Text(
                      entry.company,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        color: Color(0xFFD8F397),
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  if (entry.pitch.isNotEmpty)
                    Padding(
                      padding: const EdgeInsets.only(top: 7),
                      child: Text(
                        entry.pitch,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 13,
                          height: 1.3,
                        ),
                      ),
                    ),
                  for (final detail in entry.details)
                    Padding(
                      padding: const EdgeInsets.only(top: 8),
                      child: Text(
                        detail,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          color: Colors.white70,
                          fontSize: 12,
                        ),
                      ),
                    ),
                  if (entry.email.isNotEmpty || entry.phone.isNotEmpty) ...[
                    const SizedBox(height: 10),
                    Text(
                      [
                        entry.email,
                        entry.phone,
                      ].where((s) => s.isNotEmpty).join('  ·  '),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        color: Colors.white60,
                        fontSize: 10,
                      ),
                    ),
                  ],
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }
}
