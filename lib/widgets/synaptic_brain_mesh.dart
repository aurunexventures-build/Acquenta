import 'face_avatar.dart';
import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';
import '../models/saved_connection.dart';
import '../screens/connection_detail_screen.dart';
import '../services/search_service.dart';

class SynapticBrainMesh extends StatefulWidget {
  final List<SavedConnection> connections;
  final String searchQuery;
  final List<SearchResult>? rankedResults;
  final String? selectedEventFilter;
  final String? selectedTechFilter;
  final String? selectedVibeFilter;
  final ValueChanged<String?>? onNodeSelected;
  final ValueChanged<String>? onPromptSelected;

  const SynapticBrainMesh({
    super.key,
    required this.connections,
    this.searchQuery = '',
    this.rankedResults,
    this.selectedEventFilter,
    this.selectedTechFilter,
    this.selectedVibeFilter,
    this.onNodeSelected,
    this.onPromptSelected,
  });

  @override
  State<SynapticBrainMesh> createState() => _SynapticBrainMeshState();
}

class _SynapticBrainMeshState extends State<SynapticBrainMesh>
    with SingleTickerProviderStateMixin {
  late final AnimationController _pulseController;
  SavedConnection? _inspectedConnection;

  @override
  void initState() {
    super.initState();
    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 2400),
    );
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (TickerMode.of(context)) {
      if (!_pulseController.isAnimating) {
        _pulseController.repeat();
      }
    } else {
      if (_pulseController.isAnimating) {
        _pulseController.stop();
      }
    }
  }

  @override
  void dispose() {
    _pulseController.dispose();
    super.dispose();
  }

  bool get _hasActiveQuery =>
      widget.searchQuery.trim().isNotEmpty ||
      (widget.selectedEventFilter != null &&
          widget.selectedEventFilter!.isNotEmpty) ||
      (widget.selectedTechFilter != null &&
          widget.selectedTechFilter!.isNotEmpty) ||
      (widget.selectedVibeFilter != null &&
          widget.selectedVibeFilter!.isNotEmpty);

  /// -----------------------------------------------------------------------
  /// Uses SearchService (Cognitive Semantic Engine) — NOT primitive matching.
  /// This is why "Android developer" correctly finds Anit Singh even though
  /// his role says "Architect": the cognitive engine maps both through the
  /// Mobile App Ecosystem domain and token-level Android skill scoring.
  /// -----------------------------------------------------------------------
  List<SearchResult> _getSearchResults() {
    if (!_hasActiveQuery) return [];
    if (widget.rankedResults != null) {
      return widget.rankedResults!.take(4).toList();
    }
    return SearchService.search(
      connections: widget.connections,
      query: widget.searchQuery,
      filterEvent: widget.selectedEventFilter,
      filterTechStack: widget.selectedTechFilter,
      filterVibe: widget.selectedVibeFilter,
    ).take(4).toList();
  }

  @override
  Widget build(BuildContext context) {
    // ── Use the cognitive engine results everywhere ──
    final searchResults = _getSearchResults();
    final matchedConnections = searchResults.map((r) => r.connection).toList();
    // Build a quick lookup: connectionId → cognitiveReason
    final cognitiveReasons = <String, String>{
      for (final r in searchResults)
        r.connection.id: r.cognitiveReason.isNotEmpty
            ? r.cognitiveReason
            : r.matchReasons.isNotEmpty
            ? r.matchReasons.first
            : '',
    };

    return LayoutBuilder(
      builder: (context, constraints) {
        final width = constraints.maxWidth;
        final height = constraints.maxHeight;

        return Stack(
          children: [
            // Subtle neural background grid/matrix dots
            Positioned.fill(
              child: CustomPaint(painter: _NeuralBackgroundPainter()),
            ),

            if (!_hasActiveQuery)
              // 1. DEFAULT IDLE STATE: THE DORMANT BRAIN WAITING TO CONNECT
              _buildIdleBrainState(width, height)
            else if (matchedConnections.isEmpty)
              // 2. NO MATCHES FOUND STATE
              _buildNoMatchesState(width, height)
            else
              // 3. ACTIVE FIRING STATE: BRAIN CONNECTING WIRES TO MATCHED PEOPLE
              _buildActiveSynapticMesh(
                width,
                height,
                matchedConnections,
                cognitiveReasons,
              ),

            // Glassmorphic Inspector Sheet for Selected Person
            if (_inspectedConnection != null)
              Positioned(
                left: 16,
                right: 16,
                bottom: 16,
                child: _buildInspectedPersonSheet(
                  context,
                  _inspectedConnection!,
                ),
              ),
          ],
        );
      },
    );
  }

  /// ---------------------------------------------------------
  /// 1. IDLE STATE: Sleek Centered Brain with Ripple Rings & Prompts
  /// ---------------------------------------------------------
  Widget _buildIdleBrainState(double width, double height) {
    final centerY = (height * 0.42).clamp(160.0, 320.0);

    return AnimatedBuilder(
      animation: _pulseController,
      builder: (context, _) {
        final pulse = _pulseController.value;
        final auraRadius = 60.0 + (pulse * 24.0);
        final auraOpacity = (1.0 - pulse) * 0.45;

        return SingleChildScrollView(
          physics: const BouncingScrollPhysics(),
          child: SizedBox(
            width: width,
            height: height > 500 ? height : 500,
            child: Column(
              children: [
                SizedBox(height: centerY - 80),

                // Pulsing Brain Core
                SizedBox(
                  width: 160,
                  height: 160,
                  child: Stack(
                    alignment: Alignment.center,
                    children: [
                      // Outer Synaptic Aura Ring
                      Container(
                        width: auraRadius * 2,
                        height: auraRadius * 2,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          border: Border.all(
                            color: const Color(
                              0xFF38BDF8,
                            ).withValues(alpha: auraOpacity),
                            width: 1.5,
                          ),
                        ),
                      ),

                      // Inner Aura Ring
                      Container(
                        width: (auraRadius - 16) * 2,
                        height: (auraRadius - 16) * 2,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          border: Border.all(
                            color: const Color(
                              0xFFA855F7,
                            ).withValues(alpha: auraOpacity * 0.8),
                            width: 1.0,
                          ),
                        ),
                      ),

                      // Glowing Center Brain Orb
                      Container(
                        width: 88,
                        height: 88,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          gradient: const RadialGradient(
                            colors: [Color(0xFF1E293B), Color(0xFF0F172A)],
                          ),
                          border: Border.all(
                            color: const Color(
                              0xFF38BDF8,
                            ).withValues(alpha: 0.6),
                            width: 2.0,
                          ),
                          boxShadow: [
                            BoxShadow(
                              color: const Color(
                                0xFF38BDF8,
                              ).withValues(alpha: 0.35),
                              blurRadius: 28,
                              spreadRadius: 4,
                            ),
                            BoxShadow(
                              color: const Color(
                                0xFFA855F7,
                              ).withValues(alpha: 0.25),
                              blurRadius: 36,
                              spreadRadius: 2,
                            ),
                          ],
                        ),
                        child: Center(
                          child: ShaderMask(
                            shaderCallback: (bounds) => const LinearGradient(
                              colors: [Color(0xFF38BDF8), Color(0xFFC084FC)],
                              begin: Alignment.topLeft,
                              end: Alignment.bottomRight,
                            ).createShader(bounds),
                            child: const Icon(
                              Icons.psychology_rounded,
                              size: 46,
                              color: Colors.white,
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),

                const SizedBox(height: 16),

                // Friendly Status Badge
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 10,
                    vertical: 4,
                  ),
                  decoration: BoxDecoration(
                    color: const Color(0xFF0F172A),
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(color: Colors.white12),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Container(
                        width: 7,
                        height: 7,
                        decoration: const BoxDecoration(
                          color: Color(0xFF38BDF8),
                          shape: BoxShape.circle,
                        ),
                      ),
                      const SizedBox(width: 6),
                      const Text(
                        'NEURAL COPILOT READY',
                        style: TextStyle(
                          fontSize: 10,
                          fontWeight: FontWeight.w700,
                          letterSpacing: 0.8,
                          color: Color(0xFF94A3B8),
                        ),
                      ),
                    ],
                  ),
                ),

                const SizedBox(height: 12),

                // Headline & User-Friendly Prompt Instructions
                const Text(
                  'Acquenta Neural Recall',
                  style: TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.w800,
                    color: Colors.white,
                    letterSpacing: -0.3,
                  ),
                ),
                const SizedBox(height: 6),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 36),
                  child: Text(
                    'Type a skill, event, or intuition above to activate your network connections.',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: 13,
                      height: 1.4,
                      color: Colors.white.withValues(alpha: 0.6),
                    ),
                  ),
                ),

                const SizedBox(height: 28),

                // Interactive Quick Prompts to awaken the brain
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 24),
                  child: Wrap(
                    alignment: WrapAlignment.center,
                    spacing: 8,
                    runSpacing: 8,
                    children: [
                      _buildPromptChip(
                        icon: Icons.bolt_rounded,
                        label: 'Who knows Flutter?',
                        query: 'Flutter',
                        color: const Color(0xFF38BDF8),
                      ),
                      _buildPromptChip(
                        icon: Icons.auto_awesome,
                        label: 'Aspirational founder',
                        query: 'Aspirational founder',
                        color: const Color(0xFFA855F7),
                      ),
                      _buildPromptChip(
                        icon: Icons.event,
                        label: "Cam's Tech Talk",
                        query: "Cam's Tech Talk",
                        color: const Color(0xFFF59E0B),
                      ),
                      _buildPromptChip(
                        icon: Icons.memory,
                        label: 'On-device AI',
                        query: 'On-device AI',
                        color: const Color(0xFF34D399),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildPromptChip({
    required IconData icon,
    required String label,
    required String query,
    required Color color,
  }) {
    return ActionChip(
      avatar: Icon(icon, size: 14, color: color),
      label: Text(
        label,
        style: TextStyle(
          fontSize: 12,
          fontWeight: FontWeight.w600,
          color: Colors.white.withValues(alpha: 0.9),
        ),
      ),
      backgroundColor: const Color(0xFF161B26),
      side: BorderSide(color: color.withValues(alpha: 0.35)),
      padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
      onPressed: () {
        if (widget.onPromptSelected != null) {
          widget.onPromptSelected!(query);
        }
      },
    );
  }

  /// ---------------------------------------------------------
  /// 2. NO MATCHES FOUND STATE
  /// ---------------------------------------------------------
  Widget _buildNoMatchesState(double width, double height) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 72,
              height: 72,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: const Color(0xFF1E293B),
                border: Border.all(color: Colors.white12),
              ),
              child: const Icon(
                Icons.psychology_alt_rounded,
                size: 36,
                color: Colors.grey,
              ),
            ),
            const SizedBox(height: 16),
            Text(
              'No Synaptic Connections Found',
              style: const TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.bold,
                color: Colors.white,
              ),
            ),
            const SizedBox(height: 6),
            Text(
              'No contacts matched "${widget.searchQuery}". Try searching by a skill, company, or vibe tag.',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 12,
                color: Colors.white.withValues(alpha: 0.6),
              ),
            ),
          ],
        ),
      ),
    );
  }

  /// ---------------------------------------------------------
  /// 3. ACTIVE FIRING STATE: Brain Connecting Synaptic Wires Outward
  /// ---------------------------------------------------------
  Widget _buildActiveSynapticMesh(
    double width,
    double height,
    List<SavedConnection> matches,
    Map<String, String> cognitiveReasons,
  ) {
    // Top-centered brain position
    final brainPos = Offset(width / 2, 72.0);

    // Compute positions for each matched person
    final personPositions = <String, Offset>{};
    final count = matches.length;

    if (count == 1) {
      personPositions[matches[0].id] = Offset(width / 2, 250.0);
    } else if (count == 2) {
      const y = 240.0;
      personPositions[matches[0].id] = Offset(width * 0.28, y);
      personPositions[matches[1].id] = Offset(width * 0.72, y);
    } else if (count == 3) {
      personPositions[matches[0].id] = Offset(width * 0.20, 230.0);
      personPositions[matches[1].id] = Offset(width * 0.50, 270.0);
      personPositions[matches[2].id] = Offset(width * 0.80, 230.0);
    } else {
      // 4 matches: 2 on row 1, 2 on row 2
      personPositions[matches[0].id] = Offset(width * 0.28, 210.0);
      personPositions[matches[1].id] = Offset(width * 0.72, 210.0);
      personPositions[matches[2].id] = Offset(width * 0.28, 390.0);
      personPositions[matches[3].id] = Offset(width * 0.72, 390.0);
    }

    return AnimatedBuilder(
      animation: _pulseController,
      builder: (context, _) {
        final pulse = _pulseController.value;

        return Stack(
          children: [
            // Glowing Synapse Wires drawn from Brain to each Person
            CustomPaint(
              size: Size(width, height),
              painter: _SynapticWiresPainter(
                brainPos: brainPos,
                personPositions: personPositions,
                pulseValue: pulse,
                selectedPersonId: _inspectedConnection?.id,
              ),
            ),

            // Top Active Brain Node
            Positioned(
              left: brainPos.dx - 32,
              top: brainPos.dy - 32,
              child: _buildActiveBrainNode(pulse),
            ),

            // Matched Person Cards & Popped-Up Details
            ...matches.map((conn) {
              final pos = personPositions[conn.id] ?? const Offset(100, 200);
              final isSelected = _inspectedConnection?.id == conn.id;
              final reason = cognitiveReasons[conn.id] ?? '';

              return Positioned(
                left: pos.dx - 120,
                top: pos.dy - 30,
                child: SizedBox(
                  width: 240,
                  child: _buildPersonCluster(conn, isSelected, reason),
                ),
              );
            }),
          ],
        );
      },
    );
  }

  /// Active Brain Node at the top of the canvas
  Widget _buildActiveBrainNode(double pulse) {
    return Container(
      width: 64,
      height: 64,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        gradient: const RadialGradient(
          colors: [Color(0xFF1E293B), Color(0xFF0F172A)],
        ),
        border: Border.all(color: const Color(0xFF38BDF8), width: 2.0),
        boxShadow: [
          BoxShadow(
            color: const Color(
              0xFF38BDF8,
            ).withValues(alpha: 0.5 + (pulse * 0.3)),
            blurRadius: 20,
            spreadRadius: 2,
          ),
          BoxShadow(
            color: const Color(0xFFA855F7).withValues(alpha: 0.3),
            blurRadius: 28,
            spreadRadius: 1,
          ),
        ],
      ),
      child: Center(
        child: ShaderMask(
          shaderCallback: (bounds) => const LinearGradient(
            colors: [Color(0xFF38BDF8), Color(0xFFF59E0B)],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ).createShader(bounds),
          child: const Icon(
            Icons.psychology_rounded,
            size: 34,
            color: Colors.white,
          ),
        ),
      ),
    );
  }

  /// Clean, un-messy Person Cluster: Avatar + Name + Relevant Skills + Concept Pathway
  Widget _buildPersonCluster(
    SavedConnection conn,
    bool isSelected,
    String cognitiveReason,
  ) {
    final q = widget.searchQuery.toLowerCase();
    final queryTokens = q
        .split(RegExp(r'\s+'))
        .where((t) => t.length > 1)
        .toSet();

    // Pick skills that match ANY query token (not just the full phrase)
    final matchingSkills = conn.techStack.where((s) {
      final sLow = s.toLowerCase();
      if (queryTokens.any((t) => sLow.contains(t) || t.contains(sLow))) {
        return true;
      }
      return false;
    }).toList();

    final displaySkills = matchingSkills.isNotEmpty
        ? matchingSkills.take(2).toList()
        : conn.techStack.take(2).toList();

    // Pick relevant vibe tag — try any token
    final matchingVibe = conn.vibeTags.firstWhere(
      (v) => queryTokens.any((t) => v.toLowerCase().contains(t)),
      orElse: () => conn.vibeTags.isNotEmpty ? conn.vibeTags.first : '',
    );

    // Trim long cognitive reason for display
    String reasonDisplay = '';
    if (cognitiveReason.isNotEmpty) {
      // Strip "Concept link:" prefix if present for compactness
      reasonDisplay = cognitiveReason
          .replaceFirst(
            RegExp(r'^Concept link:\s*', caseSensitive: false),
            '⚡ ',
          )
          .replaceFirst(
            RegExp(r'^Role association:\s*', caseSensitive: false),
            '🔗 ',
          )
          .replaceFirst(
            RegExp(r'^Skill:\s*', caseSensitive: false),
            '⚡ Skill: ',
          )
          .replaceFirst(RegExp(r'^Vibe:\s*', caseSensitive: false), '✨ ')
          .replaceFirst(
            RegExp(r'^Future Self:\s*', caseSensitive: false),
            '💛 ',
          )
          .replaceFirst(RegExp(r'^Discussion:\s*', caseSensitive: false), '💬 ')
          .replaceFirst(RegExp(r'^Event:\s*', caseSensitive: false), '📍 ');
      if (reasonDisplay.length > 60) {
        reasonDisplay = '${reasonDisplay.substring(0, 57)}…';
      }
    }

    return InkWell(
      onTap: () {
        setState(() {
          if (_inspectedConnection?.id == conn.id) {
            _inspectedConnection = null;
          } else {
            _inspectedConnection = conn;
          }
        });
        if (widget.onNodeSelected != null) {
          widget.onNodeSelected!(_inspectedConnection?.id);
        }
      },
      borderRadius: BorderRadius.circular(16),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Person Avatar with Glow
          Container(
            width: 50,
            height: 50,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              gradient: const LinearGradient(
                colors: [Color(0xFF2563EB), Color(0xFF1D4ED8)],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              border: Border.all(
                color: isSelected
                    ? const Color(0xFFF59E0B)
                    : const Color(0xFF60A5FA),
                width: isSelected ? 2.5 : 1.5,
              ),
              boxShadow: [
                BoxShadow(
                  color:
                      (isSelected
                              ? const Color(0xFFF59E0B)
                              : const Color(0xFF3B82F6))
                          .withValues(alpha: isSelected ? 0.6 : 0.3),
                  blurRadius: isSelected ? 16 : 8,
                ),
              ],
            ),
            child: Center(
              child: Text(
                conn.fullName
                    .trim()
                    .split(' ')
                    .map((n) => n.isNotEmpty ? n[0] : '')
                    .take(2)
                    .join(),
                style: const TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.w800,
                  fontSize: 16,
                ),
              ),
            ),
          ),

          const SizedBox(height: 6),

          // Name and Role
          Text(
            conn.fullName,
            style: const TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w700,
              color: Colors.white,
            ),
          ),
          if (conn.role.isNotEmpty)
            Text(
              conn.role,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                fontSize: 10,
                color: Colors.white.withValues(alpha: 0.65),
              ),
            ),

          const SizedBox(height: 6),

          // Popped-up Relevant Skills (Cyan) & Vibe (Violet) Badges
          Wrap(
            alignment: WrapAlignment.center,
            spacing: 4,
            runSpacing: 4,
            children: [
              ...displaySkills.map((s) {
                return Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 6,
                    vertical: 2,
                  ),
                  decoration: BoxDecoration(
                    color: const Color(0xFF0C242C),
                    borderRadius: BorderRadius.circular(6),
                    border: Border.all(
                      color: const Color(0xFF06B6D4).withValues(alpha: 0.6),
                    ),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(
                        Icons.bolt_rounded,
                        size: 9,
                        color: Color(0xFF06B6D4),
                      ),
                      const SizedBox(width: 3),
                      Text(
                        s,
                        style: const TextStyle(
                          fontSize: 9.5,
                          fontWeight: FontWeight.w600,
                          color: Color(0xFF67E8F9),
                        ),
                      ),
                    ],
                  ),
                );
              }),

              if (matchingVibe.isNotEmpty)
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 6,
                    vertical: 2,
                  ),
                  decoration: BoxDecoration(
                    color: const Color(0xFF26123D),
                    borderRadius: BorderRadius.circular(6),
                    border: Border.all(
                      color: const Color(0xFFA855F7).withValues(alpha: 0.6),
                    ),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(
                        Icons.auto_awesome,
                        size: 9,
                        color: Color(0xFFC084FC),
                      ),
                      const SizedBox(width: 3),
                      Text(
                        matchingVibe,
                        style: const TextStyle(
                          fontSize: 9.5,
                          fontWeight: FontWeight.w600,
                          color: Color(0xFFE9D5FF),
                        ),
                      ),
                    ],
                  ),
                ),
            ],
          ),

          // Cognitive Reasoning Trail — WHY this person was recalled
          if (reasonDisplay.isNotEmpty) ...[
            const SizedBox(height: 5),
            Container(
              constraints: const BoxConstraints(maxWidth: 220),
              padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
              decoration: BoxDecoration(
                color: const Color(0xFF1A1200),
                borderRadius: BorderRadius.circular(6),
                border: Border.all(
                  color: const Color(0xFFFBBF24).withValues(alpha: 0.45),
                ),
              ),
              child: Text(
                reasonDisplay,
                textAlign: TextAlign.center,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  fontSize: 8.5,
                  color: const Color(0xFFFDE68A).withValues(alpha: 0.9),
                  height: 1.3,
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }

  /// Floating Glassmorphic Inspector Sheet for the selected person
  Widget _buildInspectedPersonSheet(
    BuildContext context,
    SavedConnection conn,
  ) {
    return Container(
      decoration: BoxDecoration(
        color: const Color(0xFF131720),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: const Color(0xFFFBBF24).withValues(alpha: 0.4),
          width: 1.2,
        ),
        boxShadow: const [
          BoxShadow(
            color: Colors.black87,
            blurRadius: 24,
            offset: Offset(0, 8),
          ),
        ],
      ),
      padding: const EdgeInsets.all(16),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header with Avatar and Name
          Row(
            children: [
              FaceAvatar(
                name: conn.fullName,
                photo: conn.avatarUrl,
                radius: 20,
                backgroundColor: Colors.blue.withValues(alpha: .15),
                foregroundColor: Colors.blue,
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      conn.fullName,
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                        color: Colors.white,
                      ),
                    ),
                    Text(
                      conn.role.isNotEmpty
                          ? (conn.company.isNotEmpty
                                ? '${conn.role} · ${conn.company}'
                                : conn.role)
                          : 'Connection',
                      style: const TextStyle(
                        fontSize: 12,
                        color: Color(0xFF93C5FD),
                      ),
                    ),
                  ],
                ),
              ),
              IconButton(
                icon: const Icon(Icons.close, size: 18, color: Colors.white60),
                onPressed: () {
                  setState(() {
                    _inspectedConnection = null;
                  });
                },
              ),
            ],
          ),

          // Message to Future Self (The Human Touch)
          if (conn.futureSelfNote.isNotEmpty) ...[
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              decoration: BoxDecoration(
                color: const Color(0xFFD97706).withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color: const Color(0xFFFBBF24).withValues(alpha: 0.3),
                ),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Row(
                    children: [
                      Icon(
                        Icons.mail_outline_rounded,
                        size: 12,
                        color: Color(0xFFFBBF24),
                      ),
                      SizedBox(width: 4),
                      Text(
                        'MESSAGE TO FUTURE SELF',
                        style: TextStyle(
                          fontSize: 9,
                          fontWeight: FontWeight.w800,
                          letterSpacing: 0.8,
                          color: Color(0xFFFBBF24),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 4),
                  Text(
                    conn.futureSelfNote.replaceFirst(
                      RegExp(r'^Note to Future Self:\s*'),
                      '',
                    ),
                    style: const TextStyle(
                      fontSize: 12,
                      fontStyle: FontStyle.italic,
                      height: 1.35,
                      color: Color(0xFFFEF3C7),
                    ),
                  ),
                ],
              ),
            ),
          ],

          // Vibe Tags
          if (conn.vibeTags.isNotEmpty) ...[
            const SizedBox(height: 10),
            Wrap(
              spacing: 6,
              runSpacing: 4,
              children: conn.vibeTags.map((vibe) {
                return Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 3,
                  ),
                  decoration: BoxDecoration(
                    color: const Color(0xFF8B5CF6).withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(
                      color: const Color(0xFF8B5CF6).withValues(alpha: 0.4),
                    ),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(
                        Icons.auto_awesome,
                        size: 10,
                        color: Color(0xFFC084FC),
                      ),
                      const SizedBox(width: 4),
                      Text(
                        vibe,
                        style: const TextStyle(
                          fontSize: 10,
                          fontWeight: FontWeight.w600,
                          color: Color(0xFFE9D5FF),
                        ),
                      ),
                    ],
                  ),
                );
              }).toList(),
            ),
          ],

          // Action Buttons: Call, Email, Profile
          const SizedBox(height: 14),
          Row(
            children: [
              if (conn.phone.isNotEmpty)
                TextButton.icon(
                  icon: const Icon(
                    Icons.phone_rounded,
                    size: 14,
                    color: Colors.blue,
                  ),
                  label: const Text(
                    'Call',
                    style: TextStyle(fontSize: 12, color: Colors.blue),
                  ),
                  onPressed: () => launchUrl(Uri.parse('tel:${conn.phone}')),
                ),
              if (conn.email.isNotEmpty)
                TextButton.icon(
                  icon: const Icon(
                    Icons.email_rounded,
                    size: 14,
                    color: Colors.tealAccent,
                  ),
                  label: const Text(
                    'Email',
                    style: TextStyle(fontSize: 12, color: Colors.tealAccent),
                  ),
                  onPressed: () => launchUrl(Uri.parse('mailto:${conn.email}')),
                ),
              const Spacer(),
              ElevatedButton.icon(
                icon: const Icon(
                  Icons.badge_rounded,
                  size: 14,
                  color: Colors.white,
                ),
                label: const Text(
                  'Full Profile',
                  style: TextStyle(fontSize: 12, color: Colors.white),
                ),
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF2563EB),
                  padding: const EdgeInsets.symmetric(
                    horizontal: 14,
                    vertical: 8,
                  ),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(10),
                  ),
                ),
                onPressed: () {
                  Navigator.of(context).push(
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
    );
  }
}

/// Draws glowing Bezier neural axons connecting the Brain to each person
class _SynapticWiresPainter extends CustomPainter {
  final Offset brainPos;
  final Map<String, Offset> personPositions;
  final double pulseValue;
  final String? selectedPersonId;

  _SynapticWiresPainter({
    required this.brainPos,
    required this.personPositions,
    required this.pulseValue,
    this.selectedPersonId,
  });

  @override
  void paint(Canvas canvas, Size size) {
    for (final entry in personPositions.entries) {
      final personId = entry.key;
      final target = entry.value;
      final isSelected = personId == selectedPersonId;

      // Draw curved Bezier path
      final path = Path();
      path.moveTo(brainPos.dx, brainPos.dy);

      final controlPoint1 = Offset(
        brainPos.dx + (target.dx - brainPos.dx) * 0.1,
        brainPos.dy + (target.dy - brainPos.dy) * 0.6,
      );
      final controlPoint2 = Offset(
        brainPos.dx + (target.dx - brainPos.dx) * 0.9,
        brainPos.dy + (target.dy - brainPos.dy) * 0.4,
      );

      path.cubicTo(
        controlPoint1.dx,
        controlPoint1.dy,
        controlPoint2.dx,
        controlPoint2.dy,
        target.dx,
        target.dy,
      );

      // Base glowing wire
      final wirePaint = Paint()
        ..color =
            (isSelected ? const Color(0xFFF59E0B) : const Color(0xFF38BDF8))
                .withValues(alpha: isSelected ? 0.8 : 0.45)
        ..style = PaintingStyle.stroke
        ..strokeWidth = isSelected ? 3.0 : 1.8;

      canvas.drawPath(path, wirePaint);

      // Animated traveling electric pulse packet
      final metrics = path.computeMetrics().toList();
      if (metrics.isNotEmpty) {
        final metric = metrics.first;
        final distance = metric.length * pulseValue;
        final tangent = metric.getTangentForOffset(distance);

        if (tangent != null) {
          final pulsePaint = Paint()
            ..color = isSelected ? const Color(0xFFFDE68A) : Colors.white
            ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 4);

          canvas.drawCircle(
            tangent.position,
            isSelected ? 4.5 : 3.2,
            pulsePaint,
          );

          final corePaint = Paint()..color = Colors.white;
          canvas.drawCircle(
            tangent.position,
            isSelected ? 2.5 : 1.8,
            corePaint,
          );
        }
      }
    }
  }

  @override
  bool shouldRepaint(covariant _SynapticWiresPainter oldDelegate) => true;
}

/// Subtle grid dots background
class _NeuralBackgroundPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final dotPaint = Paint()..color = Colors.white.withValues(alpha: 0.04);
    const spacing = 28.0;

    for (double x = spacing; x < size.width; x += spacing) {
      for (double y = spacing; y < size.height; y += spacing) {
        canvas.drawCircle(Offset(x, y), 0.9, dotPaint);
      }
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
