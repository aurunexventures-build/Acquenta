import 'face_avatar.dart';
import 'social_icon_row.dart';
import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';
import '../models/saved_connection.dart';
import '../screens/connection_detail_screen.dart';

class ConnectionsWalletStack extends StatefulWidget {
  final List<SavedConnection> connections;
  final VoidCallback onAddConnection;

  const ConnectionsWalletStack({
    super.key,
    required this.connections,
    required this.onAddConnection,
  });

  @override
  State<ConnectionsWalletStack> createState() => _ConnectionsWalletStackState();
}

class _ConnectionsWalletStackState extends State<ConnectionsWalletStack> {
  int? _expandedIndex;
  final String _filterQuery = '';

  List<SavedConnection> get _filteredConnections {
    if (_filterQuery.trim().isEmpty) return widget.connections;
    final q = _filterQuery.toLowerCase();
    return widget.connections.where((c) {
      return c.fullName.toLowerCase().contains(q) ||
          c.eventContext.eventName.toLowerCase().contains(q) ||
          c.techStack.any((t) => t.toLowerCase().contains(q));
    }).toList();
  }

  void _expandCard(int index) {
    setState(() {
      _expandedIndex = index;
    });
  }

  void _collapseStack() {
    setState(() {
      _expandedIndex = null;
    });
  }

  // Generate distinct luxury card material gradients based on index
  _ConnectionTheme _getCardTheme(int index, String name) {
    final themes = [
      _ConnectionTheme(
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Color(0xFF1E2430), Color(0xFF131720)],
        ),
        accentColor: const Color(0xFF60A5FA),
        borderColor: const Color(0x3360A5FA),
        avatarGradient: const LinearGradient(
          colors: [Color(0xFF2563EB), Color(0xFF1D4ED8)],
        ),
      ),
      _ConnectionTheme(
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Color(0xFF0F281E), Color(0xFF081912)],
        ),
        accentColor: const Color(0xFF34D399),
        borderColor: const Color(0x3334D399),
        avatarGradient: const LinearGradient(
          colors: [Color(0xFF059669), Color(0xFF047857)],
        ),
      ),
      _ConnectionTheme(
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Color(0xFF231633), Color(0xFF130C1C)],
        ),
        accentColor: const Color(0xFFA78BFA),
        borderColor: const Color(0x33A78BFA),
        avatarGradient: const LinearGradient(
          colors: [Color(0xFF7C3AED), Color(0xFF6D28D9)],
        ),
      ),
      _ConnectionTheme(
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Color(0xFF2B1D11), Color(0xFF160E08)],
        ),
        accentColor: const Color(0xFFFBBF24),
        borderColor: const Color(0x33FBBF24),
        avatarGradient: const LinearGradient(
          colors: [Color(0xFFD97706), Color(0xFFB45309)],
        ),
      ),
      _ConnectionTheme(
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Color(0xFF1E1E24), Color(0xFF121216)],
        ),
        accentColor: const Color(0xFFE2E8F0),
        borderColor: const Color(0x26FFFFFF),
        avatarGradient: const LinearGradient(
          colors: [Color(0xFF475569), Color(0xFF334155)],
        ),
      ),
    ];
    return themes[index % themes.length];
  }

  @override
  Widget build(BuildContext context) {
    final connections = _filteredConnections;

    if (connections.isEmpty) {
      return _buildEmptyState(context);
    }

    final isExpanded =
        _expandedIndex != null && _expandedIndex! < connections.length;

    return SingleChildScrollView(
      physics: const BouncingScrollPhysics(),
      padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Deck Status Bar
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  Icon(
                    isExpanded
                        ? Icons.badge_rounded
                        : Icons.view_agenda_rounded,
                    size: 16,
                    color: Colors.white70,
                  ),
                  const SizedBox(width: 8),
                  Text(
                    isExpanded
                        ? 'CONNECTION ${_expandedIndex! + 1} OF ${connections.length}'
                        : '${connections.length} CONNECTIONS IN WALLET',
                    style: const TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w700,
                      letterSpacing: 1.0,
                      color: Colors.white60,
                    ),
                  ),
                ],
              ),
              if (isExpanded)
                TextButton.icon(
                  onPressed: _collapseStack,
                  icon: const Icon(
                    Icons.layers_outlined,
                    size: 14,
                    color: Colors.blueAccent,
                  ),
                  label: const Text(
                    'View All Cards',
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      color: Colors.blueAccent,
                    ),
                  ),
                  style: TextButton.styleFrom(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 10,
                      vertical: 4,
                    ),
                    visualDensity: VisualDensity.compact,
                  ),
                )
              else
                Text(
                  'Tap to expand',
                  style: TextStyle(
                    fontSize: 11,
                    color: Colors.white.withValues(alpha: 0.4),
                  ),
                ),
            ],
          ),

          const SizedBox(height: 12),

          // Stacked Deck or Expanded Card
          if (isExpanded)
            _buildExpandedCard(context, connections, _expandedIndex!)
          else
            _buildStackedWallet(context, connections),
        ],
      ),
    );
  }

  Widget _buildStackedWallet(
    BuildContext context,
    List<SavedConnection> connections,
  ) {
    // Each card peeks out by ~66px showing only picture and name
    const double cardPeekOffset = 68.0;
    final double stackHeight =
        180.0 + ((connections.length - 1) * cardPeekOffset);

    return SizedBox(
      height: stackHeight,
      child: Stack(
        clipBehavior: Clip.none,
        children: List.generate(connections.length, (index) {
          final conn = connections[index];
          final theme = _getCardTheme(index, conn.fullName);
          final topOffset = index * cardPeekOffset;

          return Positioned(
            top: topOffset,
            left: 0,
            right: 0,
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 320),
              curve: Curves.easeOutCubic,
              transform: Matrix4.identity()
                ..scaleByDouble(
                  1.0 - (index * 0.012),
                  1.0 - (index * 0.012),
                  1.0 - (index * 0.012),
                  1.0,
                ),
              child: _buildStackedCardItem(
                conn,
                theme,
                () => _expandCard(index),
              ),
            ),
          );
        }),
      ),
    );
  }

  /// Minimalist stacked card showing ONLY picture and name in the peek view!
  Widget _buildStackedCardItem(
    SavedConnection conn,
    _ConnectionTheme theme,
    VoidCallback onTap,
  ) {
    return Container(
      width: double.infinity,
      height: 140,
      decoration: BoxDecoration(
        gradient: theme.gradient,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: theme.borderColor, width: 1.2),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.4),
            offset: const Offset(0, 8),
            blurRadius: 20,
            spreadRadius: -4,
          ),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(20),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 14),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Picture / Avatar
                FaceAvatar(
                  name: conn.fullName,
                  photo: conn.avatarUrl,
                  radius: 22,
                  backgroundColor: theme.avatarGradient.colors.first,
                  foregroundColor: Colors.white,
                ),
                const SizedBox(width: 14),

                // Name and minimal event peek
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(
                            conn.fullName,
                            style: const TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                              color: Colors.white,
                              letterSpacing: -0.3,
                            ),
                          ),
                          if (conn.isFavorite)
                            const Icon(
                              Icons.star_rounded,
                              size: 16,
                              color: Colors.amber,
                            ),
                        ],
                      ),
                      const SizedBox(height: 2),
                      Text(
                        conn.role.isNotEmpty
                            ? (conn.company.isNotEmpty
                                  ? '${conn.role} · ${conn.company}'
                                  : conn.role)
                            : (conn.eventContext.eventName.isNotEmpty
                                  ? 'Met at ${conn.eventContext.eventName}'
                                  : ''),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          fontSize: 11,
                          color: Colors.white.withValues(alpha: 0.5),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  /// Expanded Card showing full context (Event, Discussion, Tech Stack, and 1-tap Actions)
  Widget _buildExpandedCard(
    BuildContext context,
    List<SavedConnection> connections,
    int index,
  ) {
    final conn = connections[index];
    final theme = _getCardTheme(index, conn.fullName);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // Main Luxury Expanded Card
        Container(
          width: double.infinity,
          decoration: BoxDecoration(
            gradient: theme.gradient,
            borderRadius: BorderRadius.circular(22),
            border: Border.all(color: theme.borderColor, width: 1.2),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.45),
                offset: const Offset(0, 12),
                blurRadius: 28,
                spreadRadius: -4,
              ),
            ],
          ),
          child: Padding(
            padding: const EdgeInsets.all(22),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Header with Picture and Name
                Row(
                  children: [
                    FaceAvatar(
                      name: conn.fullName,
                      photo: conn.avatarUrl,
                      radius: 29,
                      backgroundColor: theme.avatarGradient.colors.first,
                      foregroundColor: Colors.white,
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Expanded(
                                child: Text(
                                  conn.fullName,
                                  style: const TextStyle(
                                    fontSize: 22,
                                    fontWeight: FontWeight.w800,
                                    color: Colors.white,
                                    letterSpacing: -0.4,
                                  ),
                                ),
                              ),
                              if (conn.links.isNotEmpty)
                                Flexible(
                                  child: SocialIconRow(
                                    links: conn.links,
                                    color: Colors.white,
                                  ),
                                ),
                              if (conn.isFavorite)
                                const Icon(
                                  Icons.star_rounded,
                                  size: 20,
                                  color: Colors.amber,
                                ),
                            ],
                          ),
                          const SizedBox(height: 3),
                          Text(
                            conn.role.isNotEmpty
                                ? (conn.company.isNotEmpty
                                      ? '${conn.role} · ${conn.company}'
                                      : conn.role)
                                : 'Connection',
                            style: TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w500,
                              color: theme.accentColor,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),

                const SizedBox(height: 18),

                // Event Badge (Where you met)
                if (conn.eventContext.eventName.isNotEmpty)
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 6,
                    ),
                    decoration: BoxDecoration(
                      color: Colors.amber.withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(
                        color: Colors.amber.withValues(alpha: 0.3),
                      ),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(
                          Icons.location_on_rounded,
                          size: 14,
                          color: Colors.amberAccent,
                        ),
                        const SizedBox(width: 6),
                        Text(
                          'Met at ${conn.eventContext.eventName}',
                          style: const TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.bold,
                            color: Colors.amber,
                          ),
                        ),
                      ],
                    ),
                  ),

                if (conn.distinctiveMemory.isNotEmpty ||
                    conn.eventContext.notes.isNotEmpty) ...[
                  const SizedBox(height: 16),
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Icon(
                        Icons.chat_bubble_outline_rounded,
                        size: 18,
                        color: Colors.white54,
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Text(
                          conn.distinctiveMemory.isNotEmpty
                              ? conn.distinctiveMemory
                              : conn.eventContext.notes,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            color: Colors.white70,
                            height: 1.4,
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
                const SizedBox(height: 20),
                const Divider(color: Color(0x1FFFFFFF), height: 1),
                const SizedBox(height: 16),

                // Quick Communication Actions Row
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                  children: [
                    if (conn.phone.isNotEmpty)
                      _buildIconButton(
                        icon: Icons.phone_rounded,
                        label: 'Call',
                        onTap: () => launchUrl(Uri.parse('tel:${conn.phone}')),
                      ),
                    if (conn.phone.isNotEmpty)
                      _buildIconButton(
                        icon: Icons.chat_bubble_rounded,
                        label: 'SMS',
                        onTap: () => launchUrl(Uri.parse('sms:${conn.phone}')),
                      ),
                    if (conn.email.isNotEmpty)
                      _buildIconButton(
                        icon: Icons.email_rounded,
                        label: 'Email',
                        onTap: () =>
                            launchUrl(Uri.parse('mailto:${conn.email}')),
                      ),
                    _buildIconButton(
                      icon: Icons.badge_outlined,
                      label: 'Details',
                      onTap: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (_) =>
                                ConnectionDetailScreen(connectionId: conn.id),
                          ),
                        );
                      },
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),

        const SizedBox(height: 16),

        // Carousel Pager between connections
        if (connections.length > 1)
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              IconButton(
                icon: const Icon(Icons.arrow_back_ios_new_rounded, size: 16),
                color: index > 0 ? Colors.white70 : Colors.white24,
                onPressed: index > 0 ? () => _expandCard(index - 1) : null,
              ),
              const SizedBox(width: 8),
              ...List.generate(connections.length, (dotIndex) {
                return GestureDetector(
                  onTap: () => _expandCard(dotIndex),
                  child: Container(
                    width: dotIndex == index ? 20 : 6,
                    height: 6,
                    margin: const EdgeInsets.symmetric(horizontal: 3),
                    decoration: BoxDecoration(
                      color: dotIndex == index
                          ? Colors.blueAccent
                          : Colors.white24,
                      borderRadius: BorderRadius.circular(3),
                    ),
                  ),
                );
              }),
              const SizedBox(width: 8),
              IconButton(
                icon: const Icon(Icons.arrow_forward_ios_rounded, size: 16),
                color: index < connections.length - 1
                    ? Colors.white70
                    : Colors.white24,
                onPressed: index < connections.length - 1
                    ? () => _expandCard(index + 1)
                    : null,
              ),
            ],
          ),
      ],
    );
  }

  Widget _buildIconButton({
    required IconData icon,
    required String label,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
        child: Column(
          children: [
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.08),
                shape: BoxShape.circle,
              ),
              child: Icon(icon, size: 18, color: Colors.white),
            ),
            const SizedBox(height: 6),
            Text(
              label,
              style: const TextStyle(
                fontSize: 10,
                color: Colors.white70,
                fontWeight: FontWeight.w500,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildEmptyState(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 60, horizontal: 24),
        child: Column(
          children: [
            Container(
              padding: const EdgeInsets.all(22),
              decoration: BoxDecoration(
                color: Colors.blueAccent.withValues(alpha: 0.1),
                shape: BoxShape.circle,
              ),
              child: const Icon(
                Icons.people_outline,
                size: 48,
                color: Colors.blueAccent,
              ),
            ),
            const SizedBox(height: 20),
            const Text(
              'No Connections Yet',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: Colors.white,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Scan a contact QR, speak a memory cue, or add someone you meet at your next event.',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 13,
                color: Colors.white.withValues(alpha: 0.6),
              ),
            ),
            const SizedBox(height: 24),
            ElevatedButton.icon(
              onPressed: widget.onAddConnection,
              icon: const Icon(Icons.person_add_rounded),
              label: const Text('Add Connection'),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.blueAccent,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(
                  horizontal: 24,
                  vertical: 14,
                ),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(14),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ConnectionTheme {
  final LinearGradient gradient;
  final Color accentColor;
  final Color borderColor;
  final LinearGradient avatarGradient;

  _ConnectionTheme({
    required this.gradient,
    required this.accentColor,
    required this.borderColor,
    required this.avatarGradient,
  });
}
