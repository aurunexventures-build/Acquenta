import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';
import '../models/saved_connection.dart';
import '../screens/connection_detail_screen.dart';

enum MeshNodeType {
  person,
  event,
  skill,
  vibe,
}

class MeshNode {
  final String id;
  final MeshNodeType type;
  final String label;
  final String sublabel;
  final Color color;
  final IconData icon;
  final Offset position;
  final String? connectionId;
  final Set<String> connectedNodeIds;

  const MeshNode({
    required this.id,
    required this.type,
    required this.label,
    this.sublabel = '',
    required this.color,
    required this.icon,
    required this.position,
    this.connectionId,
    required this.connectedNodeIds,
  });
}

class MeshEdge {
  final String sourceId;
  final String targetId;
  final Color color;
  final double width;

  const MeshEdge({
    required this.sourceId,
    required this.targetId,
    required this.color,
    this.width = 1.5,
  });
}

class MemoryMeshGraph extends StatefulWidget {
  final List<SavedConnection> connections;
  final String searchQuery;
  final String? selectedEventFilter;
  final String? selectedTechFilter;
  final String? selectedVibeFilter;
  final ValueChanged<String?>? onNodeSelected;

  const MemoryMeshGraph({
    super.key,
    required this.connections,
    this.searchQuery = '',
    this.selectedEventFilter,
    this.selectedTechFilter,
    this.selectedVibeFilter,
    this.onNodeSelected,
  });

  @override
  State<MemoryMeshGraph> createState() => _MemoryMeshGraphState();
}

class _MemoryMeshGraphState extends State<MemoryMeshGraph> with SingleTickerProviderStateMixin {
  late final TransformationController _transformController;
  late final AnimationController _pulseController;

  String? _selectedNodeId;
  SavedConnection? _inspectedConnection;

  late List<MeshNode> _nodes;
  late List<MeshEdge> _edges;
  bool _hasInitializedTransform = false;

  static const double _canvasWidth = 720.0;
  static const double _canvasHeight = 560.0;

  @override
  void initState() {
    super.initState();
    _transformController = TransformationController();
    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 3),
    );

    _buildGraphData();
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
  void didUpdateWidget(covariant MemoryMeshGraph oldWidget) {
    super.didUpdateWidget(oldWidget);
    setState(() {
      _buildGraphData();
    });
  }

  @override
  void dispose() {
    _transformController.dispose();
    _pulseController.dispose();
    super.dispose();
  }

  void _buildGraphData() {
    final nodes = <MeshNode>[];
    final edges = <MeshEdge>[];

    final conns = widget.connections;
    if (conns.isEmpty) {
      _nodes = [];
      _edges = [];
      return;
    }

    final centerX = _canvasWidth / 2;
    final centerY = _canvasHeight / 2;

    // 1. Group connections by event
    final eventMap = <String, List<SavedConnection>>{};
    for (final c in conns) {
      final ev = c.eventContext.eventName.trim().isNotEmpty ? c.eventContext.eventName.trim() : 'General Networking';
      eventMap.putIfAbsent(ev, () => []).add(c);
    }

    final eventKeys = eventMap.keys.toList();
    final eventNodes = <String, MeshNode>{};
    final personNodes = <String, MeshNode>{};
    final skillNodes = <String, MeshNode>{};
    final vibeNodes = <String, MeshNode>{};

    // Global distinct skills and vibes
    final sharedSkills = <String, Set<String>>{}; // skill -> set of connIds
    for (final c in conns) {
      for (final s in c.techStack) {
        sharedSkills.putIfAbsent(s, () => {}).add(c.id);
      }
    }

    // Place events around an ellipse
    final numEvents = eventKeys.length;
    final eventRadiusX = 145.0;
    final eventRadiusY = 100.0;

    for (int i = 0; i < numEvents; i++) {
      final evName = eventKeys[i];
      final angle = (i / numEvents) * 2 * math.pi - (math.pi / 2);
      final evPos = Offset(
        centerX + eventRadiusX * math.cos(angle),
        centerY + eventRadiusY * math.sin(angle),
      );

      final evNode = MeshNode(
        id: 'event-$i',
        type: MeshNodeType.event,
        label: evName,
        sublabel: '${eventMap[evName]!.length} Connections',
        color: const Color(0xFFF59E0B), // Warm amber
        icon: Icons.hub_rounded,
        position: evPos,
        connectedNodeIds: {},
      );
      eventNodes[evName] = evNode;
      nodes.add(evNode);
    }

    // Place persons orbiting their respective event
    for (int eIdx = 0; eIdx < eventKeys.length; eIdx++) {
      final evName = eventKeys[eIdx];
      final evNode = eventNodes[evName]!;
      final peopleInEvent = eventMap[evName]!;
      final count = peopleInEvent.length;

      final orbitRadius = 78.0;

      for (int pIdx = 0; pIdx < count; pIdx++) {
        final c = peopleInEvent[pIdx];
        final pAngle = (pIdx / count) * 2 * math.pi + (eIdx * 0.5);
        final pPos = Offset(
          evNode.position.dx + orbitRadius * math.cos(pAngle),
          evNode.position.dy + orbitRadius * math.sin(pAngle),
        );

        final pNodeId = 'person-${c.id}';
        final connectedIds = <String>{evNode.id};

        final pNode = MeshNode(
          id: pNodeId,
          type: MeshNodeType.person,
          label: c.fullName,
          sublabel: c.role.isNotEmpty ? c.role : c.company,
          color: const Color(0xFF3B82F6), // Royal Blue
          icon: Icons.person_rounded,
          position: pPos,
          connectionId: c.id,
          connectedNodeIds: connectedIds,
        );

        evNode.connectedNodeIds.add(pNodeId);
        personNodes[c.id] = pNode;
        nodes.add(pNode);

        // Edge between Event and Person
        edges.add(MeshEdge(
          sourceId: evNode.id,
          targetId: pNodeId,
          color: const Color(0xFFF59E0B).withValues(alpha: 0.6),
          width: 2.0,
        ));

        // Create Vibe Nodes radiating outward from the person
        final vibes = c.vibeTags;
        for (int vIdx = 0; vIdx < vibes.length; vIdx++) {
          final vibeName = vibes[vIdx];
          final vNodeId = 'vibe-${c.id}-$vIdx';
          final vAngle = pAngle + ((vIdx + 1) * 0.4) - 0.4;
          final vPos = Offset(
            pPos.dx + 48.0 * math.cos(vAngle),
            pPos.dy + 48.0 * math.sin(vAngle),
          );

          final vNode = MeshNode(
            id: vNodeId,
            type: MeshNodeType.vibe,
            label: vibeName,
            color: const Color(0xFFA855F7), // Warm Violet / Sparkle
            icon: Icons.auto_awesome,
            position: vPos,
            connectionId: c.id,
            connectedNodeIds: {pNodeId},
          );
          pNode.connectedNodeIds.add(vNodeId);
          vibeNodes[vNodeId] = vNode;
          nodes.add(vNode);

          edges.add(MeshEdge(
            sourceId: pNodeId,
            targetId: vNodeId,
            color: const Color(0xFFA855F7).withValues(alpha: 0.5),
            width: 1.2,
          ));
        }

        // Skills (Tech Stack)
        final skills = c.techStack.take(3).toList();
        for (int sIdx = 0; sIdx < skills.length; sIdx++) {
          final skillName = skills[sIdx];
          final sNodeId = 'skill-${c.id}-$sIdx';
          final sAngle = pAngle - ((sIdx + 1) * 0.45);
          final sPos = Offset(
            pPos.dx + 45.0 * math.cos(sAngle),
            pPos.dy + 45.0 * math.sin(sAngle),
          );

          final sNode = MeshNode(
            id: sNodeId,
            type: MeshNodeType.skill,
            label: skillName,
            color: const Color(0xFF06B6D4), // Cyan / Teal
            icon: Icons.code_rounded,
            position: sPos,
            connectionId: c.id,
            connectedNodeIds: {pNodeId},
          );
          pNode.connectedNodeIds.add(sNodeId);
          skillNodes[sNodeId] = sNode;
          nodes.add(sNode);

          edges.add(MeshEdge(
            sourceId: pNodeId,
            targetId: sNodeId,
            color: const Color(0xFF06B6D4).withValues(alpha: 0.4),
            width: 1.2,
          ));
        }
      }
    }

    _nodes = nodes;
    _edges = edges;
  }

  void _onTapNode(MeshNode node) {
    setState(() {
      if (_selectedNodeId == node.id) {
        _selectedNodeId = null;
        _inspectedConnection = null;
      } else {
        _selectedNodeId = node.id;
        if (node.connectionId != null) {
          _inspectedConnection = widget.connections.firstWhere(
            (c) => c.id == node.connectionId,
            orElse: () => widget.connections.first,
          );
        } else if (node.type == MeshNodeType.vibe || node.type == MeshNodeType.skill) {
          final pNode = _nodes.firstWhere(
            (n) => n.type == MeshNodeType.person && (n.connectedNodeIds.contains(node.id) || node.connectedNodeIds.contains(n.id)),
            orElse: () => node,
          );
          if (pNode.connectionId != null) {
            _inspectedConnection = widget.connections.firstWhere(
              (c) => c.id == pNode.connectionId,
              orElse: () => widget.connections.first,
            );
          } else {
            _inspectedConnection = null;
          }
        } else {
          _inspectedConnection = null;
        }
      }
    });

    if (widget.onNodeSelected != null) {
      widget.onNodeSelected!(_inspectedConnection?.id);
    }
  }

  bool _isNodeHighlighted(MeshNode node) {
    final q = widget.searchQuery.trim().toLowerCase();
    if (q.isNotEmpty) {
      if (node.label.toLowerCase().contains(q) || node.sublabel.toLowerCase().contains(q)) {
        return true;
      }
      if (node.connectionId != null) {
        final c = widget.connections.firstWhere(
          (item) => item.id == node.connectionId,
          orElse: () => widget.connections.first,
        );
        if (c.futureSelfNote.toLowerCase().contains(q) ||
            c.vibeTags.any((v) => v.toLowerCase().contains(q)) ||
            c.techStack.any((t) => t.toLowerCase().contains(q))) {
          return true;
        }
      }
    }

    if (widget.selectedEventFilter != null && widget.selectedEventFilter!.isNotEmpty) {
      if (node.type == MeshNodeType.event && node.label == widget.selectedEventFilter) return true;
      if (node.connectionId != null) {
        final c = widget.connections.firstWhere((item) => item.id == node.connectionId, orElse: () => widget.connections.first);
        if (c.eventContext.eventName == widget.selectedEventFilter) return true;
      }
    }

    if (widget.selectedTechFilter != null && widget.selectedTechFilter!.isNotEmpty) {
      if (node.type == MeshNodeType.skill && node.label.toLowerCase() == widget.selectedTechFilter!.toLowerCase()) return true;
    }

    if (widget.selectedVibeFilter != null && widget.selectedVibeFilter!.isNotEmpty) {
      if (node.type == MeshNodeType.vibe && node.label.toLowerCase() == widget.selectedVibeFilter!.toLowerCase()) return true;
    }

    if (_selectedNodeId != null) {
      if (node.id == _selectedNodeId) return true;
      final selectedNode = _nodes.firstWhere((n) => n.id == _selectedNodeId, orElse: () => node);
      if (selectedNode.connectedNodeIds.contains(node.id) || node.connectedNodeIds.contains(selectedNode.id)) {
        return true;
      }
      return false;
    }

    return false;
  }

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        if (!_hasInitializedTransform && constraints.maxWidth > 0 && constraints.maxHeight > 0) {
          _hasInitializedTransform = true;
          final scale = math.min(
            constraints.maxWidth / _canvasWidth,
            constraints.maxHeight / _canvasHeight,
          ).clamp(0.55, 1.15);
          final tx = (constraints.maxWidth - _canvasWidth * scale) / 2;
          final ty = (constraints.maxHeight - _canvasHeight * scale) / 2;
          _transformController.value = Matrix4.identity()
            ..translate(tx, ty)
            ..scale(scale);
        }

        return Stack(
          children: [
            // Interactive Graph Canvas
            ClipRect(
              child: InteractiveViewer(
                transformationController: _transformController,
                boundaryMargin: const EdgeInsets.all(500),
                minScale: 0.35,
                maxScale: 2.5,
                child: SizedBox(
                  width: _canvasWidth,
                  height: _canvasHeight,
                  child: AnimatedBuilder(
                animation: _pulseController,
                builder: (context, _) {
                  return Stack(
                    children: [
                      // Canvas with edges and matrix backdrop
                      CustomPaint(
                        size: const Size(_canvasWidth, _canvasHeight),
                        painter: _MeshPainter(
                          nodes: _nodes,
                          edges: _edges,
                          selectedNodeId: _selectedNodeId,
                          pulseValue: _pulseController.value,
                          searchActive: widget.searchQuery.isNotEmpty ||
                              widget.selectedEventFilter != null ||
                              widget.selectedTechFilter != null ||
                              widget.selectedVibeFilter != null,
                          isNodeHighlighted: _isNodeHighlighted,
                        ),
                      ),

                      // Interactive Node widgets positioned on top of the canvas
                      ..._nodes.map((node) {
                        final isSelected = node.id == _selectedNodeId;
                        final isHighlighted = _isNodeHighlighted(node);
                        final hasAnyFocus = _selectedNodeId != null ||
                            widget.searchQuery.isNotEmpty ||
                            widget.selectedEventFilter != null ||
                            widget.selectedTechFilter != null ||
                            widget.selectedVibeFilter != null;

                        final double opacity = (!hasAnyFocus || isHighlighted || isSelected) ? 1.0 : 0.25;

                        return Positioned(
                          left: node.position.dx - 45,
                          top: node.position.dy - 35,
                          child: Opacity(
                            opacity: opacity,
                            child: GestureDetector(
                              behavior: HitTestBehavior.opaque,
                              onTap: () => _onTapNode(node),
                              onTapUp: (_) => _onTapNode(node),
                              child: _buildNodeWidget(node, isSelected, isHighlighted),
                            ),
                          ),
                        );
                      }),
                    ],
                  );
                },
              ),
            ),
          ),
        ),

        // Mesh Legend Overlay
        Positioned(
          top: 12,
          right: 16,
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            decoration: BoxDecoration(
              color: const Color(0xFF131720).withValues(alpha: 0.85),
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: Colors.white12),
              boxShadow: const [
                BoxShadow(color: Colors.black45, blurRadius: 10, offset: Offset(0, 4)),
              ],
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                _buildLegendItem(const Color(0xFFF59E0B), 'Event Cluster'),
                const SizedBox(height: 4),
                _buildLegendItem(const Color(0xFF3B82F6), 'Person'),
                const SizedBox(height: 4),
                _buildLegendItem(const Color(0xFF06B6D4), 'Skill / Superpower'),
                const SizedBox(height: 4),
                _buildLegendItem(const Color(0xFFA855F7), 'Future Self Vibe'),
              ],
            ),
          ),
        ),

        // Quick Controls Overlay (Reset View, Zoom)
        Positioned(
          bottom: _inspectedConnection != null ? 240 : 20,
          right: 16,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              _buildFloatingActionBtn(
                icon: Icons.filter_center_focus_rounded,
                tooltip: 'Center Mesh',
                onPressed: () {
                  final scale = math.min(
                    constraints.maxWidth / _canvasWidth,
                    constraints.maxHeight / _canvasHeight,
                  ).clamp(0.55, 1.15);
                  final tx = (constraints.maxWidth - _canvasWidth * scale) / 2;
                  final ty = (constraints.maxHeight - _canvasHeight * scale) / 2;
                  _transformController.value = Matrix4.identity()
                    ..translate(tx, ty)
                    ..scale(scale);
                },
              ),
              const SizedBox(height: 8),
              _buildFloatingActionBtn(
                icon: Icons.zoom_in_rounded,
                tooltip: 'Zoom In',
                onPressed: () {
                  final matrix = _transformController.value.clone();
                  matrix.scale(1.2);
                  _transformController.value = matrix;
                },
              ),
              const SizedBox(height: 8),
              _buildFloatingActionBtn(
                icon: Icons.zoom_out_rounded,
                tooltip: 'Zoom Out',
                onPressed: () {
                  final matrix = _transformController.value.clone();
                  matrix.scale(0.8);
                  _transformController.value = matrix;
                },
              ),
            ],
          ),
        ),

        // Quick Person Focus Chips (when inspector sheet is closed)
        if (_inspectedConnection == null && widget.connections.isNotEmpty)
          Positioned(
            left: 16,
            right: 70,
            bottom: 16,
            child: SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Row(
                children: [
                  ...widget.connections.take(4).map((conn) {
                    return Padding(
                      padding: const EdgeInsets.only(right: 8),
                      child: ActionChip(
                        avatar: CircleAvatar(
                          radius: 10,
                          backgroundColor: const Color(0xFF3B82F6),
                          child: Text(
                            conn.fullName.isNotEmpty ? conn.fullName[0] : '',
                            style: const TextStyle(fontSize: 10, color: Colors.white, fontWeight: FontWeight.bold),
                          ),
                        ),
                        label: Text(
                          conn.fullName,
                          style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: Colors.white),
                        ),
                        backgroundColor: const Color(0xFF161B22).withValues(alpha: 0.9),
                        side: const BorderSide(color: Colors.white24),
                        onPressed: () {
                          final node = _nodes.firstWhere(
                            (n) => n.connectionId == conn.id,
                            orElse: () => _nodes.first,
                          );
                          _onTapNode(node);
                        },
                      ),
                    );
                  }),
                ],
              ),
            ),
          ),

        // Glassmorphic Inspector Sheet for Selected Person
        if (_inspectedConnection != null)
          Positioned(
            left: 16,
            right: 16,
            bottom: 16,
            child: _buildInspectedPersonSheet(context, _inspectedConnection!),
          ),
      ],
    );
      },
    );
  }

  Widget _buildNodeWidget(MeshNode node, bool isSelected, bool isHighlighted) {
    switch (node.type) {
      case MeshNodeType.person:
        return Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 52,
              height: 52,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [
                    node.color,
                    node.color.withValues(alpha: 0.7),
                  ],
                ),
                border: Border.all(
                  color: isSelected
                      ? Colors.amberAccent
                      : (isHighlighted ? Colors.white : Colors.white54),
                  width: isSelected ? 3.0 : (isHighlighted ? 2.0 : 1.5),
                ),
                boxShadow: [
                  BoxShadow(
                    color: (isSelected ? Colors.amber : node.color).withValues(alpha: 0.5),
                    blurRadius: isSelected ? 18 : 8,
                    spreadRadius: isSelected ? 2 : 0,
                  ),
                ],
              ),
              child: Center(
                child: Text(
                  node.label.trim().split(' ').map((n) => n.isNotEmpty ? n[0] : '').take(2).join(),
                  style: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.w800,
                    fontSize: 16,
                  ),
                ),
              ),
            ),
            const SizedBox(height: 4),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
              decoration: BoxDecoration(
                color: const Color(0xCC0D0F12),
                borderRadius: BorderRadius.circular(6),
                border: Border.all(color: Colors.white10),
              ),
              child: Text(
                node.label,
                style: const TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w700,
                  color: Colors.white,
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ],
        );

      case MeshNodeType.event:
        return Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
              decoration: BoxDecoration(
                color: const Color(0xFF1E222D),
                borderRadius: BorderRadius.circular(14),
                border: Border.all(
                  color: isSelected ? Colors.amberAccent : node.color.withValues(alpha: 0.6),
                  width: isSelected ? 2.5 : 1.5,
                ),
                boxShadow: [
                  BoxShadow(
                    color: node.color.withValues(alpha: 0.35),
                    blurRadius: isSelected ? 16 : 8,
                  ),
                ],
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(node.icon, size: 14, color: node.color),
                  const SizedBox(width: 6),
                  Text(
                    node.label,
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w800,
                      color: node.color,
                      letterSpacing: -0.2,
                    ),
                  ),
                ],
              ),
            ),
            if (node.sublabel.isNotEmpty) ...[
              const SizedBox(height: 2),
              Text(
                node.sublabel,
                style: const TextStyle(fontSize: 9, color: Colors.white54),
              ),
            ],
          ],
        );

      case MeshNodeType.vibe:
        return Container(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
          decoration: BoxDecoration(
            color: const Color(0xFF1E1030),
            borderRadius: BorderRadius.circular(10),
            border: Border.all(
              color: isSelected ? Colors.amberAccent : node.color.withValues(alpha: 0.6),
              width: isSelected ? 2 : 1,
            ),
            boxShadow: [
              BoxShadow(
                color: node.color.withValues(alpha: 0.3),
                blurRadius: 6,
              ),
            ],
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(node.icon, size: 10, color: const Color(0xFFC084FC)),
              const SizedBox(width: 4),
              Text(
                node.label,
                style: const TextStyle(
                  fontSize: 10,
                  fontWeight: FontWeight.w600,
                  color: Color(0xFFE9D5FF),
                ),
              ),
            ],
          ),
        );

      case MeshNodeType.skill:
        return Container(
          padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
          decoration: BoxDecoration(
            color: const Color(0xFF0C242C),
            borderRadius: BorderRadius.circular(8),
            border: Border.all(
              color: isSelected ? Colors.amberAccent : node.color.withValues(alpha: 0.6),
              width: isSelected ? 2 : 1,
            ),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(node.icon, size: 9, color: node.color),
              const SizedBox(width: 3),
              Text(
                node.label,
                style: TextStyle(
                  fontSize: 9.5,
                  fontWeight: FontWeight.w500,
                  color: node.color,
                ),
              ),
            ],
          ),
        );
    }
  }

  Widget _buildLegendItem(Color color, String label) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 8,
          height: 8,
          decoration: BoxDecoration(
            color: color,
            shape: BoxShape.circle,
          ),
        ),
        const SizedBox(width: 6),
        Text(
          label,
          style: const TextStyle(fontSize: 10, color: Colors.white70, fontWeight: FontWeight.w500),
        ),
      ],
    );
  }

  Widget _buildFloatingActionBtn({
    required IconData icon,
    required String tooltip,
    required VoidCallback onPressed,
  }) {
    return Material(
      color: const Color(0xFF1E222D),
      shape: const CircleBorder(),
      elevation: 4,
      child: InkWell(
        customBorder: const CircleBorder(),
        onTap: onPressed,
        child: Container(
          width: 38,
          height: 38,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            border: Border.all(color: Colors.white12),
          ),
          child: Icon(icon, size: 18, color: Colors.white70),
        ),
      ),
    );
  }

  Widget _buildInspectedPersonSheet(BuildContext context, SavedConnection conn) {
    return Container(
      decoration: BoxDecoration(
        color: const Color(0xFF131720),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: const Color(0xFFFBBF24).withValues(alpha: 0.4), width: 1.2),
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
              CircleAvatar(
                radius: 20,
                backgroundColor: const Color(0xFF2563EB),
                child: Text(
                  conn.fullName.trim().split(' ').map((n) => n.isNotEmpty ? n[0] : '').take(2).join(),
                  style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.white, fontSize: 14),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      conn.fullName,
                      style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.white),
                    ),
                    Text(
                      conn.role.isNotEmpty ? (conn.company.isNotEmpty ? '${conn.role} · ${conn.company}' : conn.role) : 'Connection',
                      style: const TextStyle(fontSize: 12, color: Color(0xFF93C5FD)),
                    ),
                  ],
                ),
              ),
              IconButton(
                icon: const Icon(Icons.close, size: 18, color: Colors.white60),
                onPressed: () {
                  setState(() {
                    _inspectedConnection = null;
                    _selectedNodeId = null;
                  });
                },
              ),
            ],
          ),

          // Message to Future Self (The Human Touch!)
          if (conn.futureSelfNote.isNotEmpty) ...[
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              decoration: BoxDecoration(
                color: const Color(0xFFD97706).withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: const Color(0xFFFBBF24).withValues(alpha: 0.3)),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Row(
                    children: [
                      Icon(Icons.mail_outline_rounded, size: 12, color: Color(0xFFFBBF24)),
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
                    conn.futureSelfNote.startsWith('Note to Future Self:')
                        ? conn.futureSelfNote.substring(20).trim()
                        : conn.futureSelfNote,
                    style: const TextStyle(
                      fontSize: 12,
                      fontStyle: FontStyle.italic,
                      color: Colors.white,
                      height: 1.35,
                    ),
                  ),
                ],
              ),
            ),
          ],

          // Vibe Badges
          if (conn.vibeTags.isNotEmpty) ...[
            const SizedBox(height: 10),
            Wrap(
              spacing: 6,
              runSpacing: 6,
              children: conn.vibeTags.map((v) {
                return Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                  decoration: BoxDecoration(
                    color: const Color(0xFF8B5CF6).withValues(alpha: 0.18),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: const Color(0xFFA78BFA).withValues(alpha: 0.35)),
                  ),
                  child: Text(
                    '✨ $v',
                    style: const TextStyle(fontSize: 10, color: Color(0xFFDDD6FE), fontWeight: FontWeight.w600),
                  ),
                );
              }).toList(),
            ),
          ],

          const SizedBox(height: 12),
          const Divider(height: 1, color: Colors.white12),
          const SizedBox(height: 10),

          // Actions
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              if (conn.phone.isNotEmpty)
                TextButton.icon(
                  onPressed: () => launchUrl(Uri.parse('tel:${conn.phone}')),
                  icon: const Icon(Icons.phone_rounded, size: 15, color: Color(0xFF60A5FA)),
                  label: const Text('Call', style: TextStyle(color: Color(0xFF60A5FA), fontSize: 12)),
                ),
              if (conn.email.isNotEmpty)
                TextButton.icon(
                  onPressed: () => launchUrl(Uri.parse('mailto:${conn.email}')),
                  icon: const Icon(Icons.email_rounded, size: 15, color: Color(0xFF34D399)),
                  label: const Text('Email', style: TextStyle(color: Color(0xFF34D399), fontSize: 12)),
                ),
              ElevatedButton.icon(
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF2563EB),
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                ),
                onPressed: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => ConnectionDetailScreen(connectionId: conn.id),
                    ),
                  );
                },
                icon: const Icon(Icons.badge_rounded, size: 14, color: Colors.white),
                label: const Text('Full Profile', style: TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.bold)),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _MeshPainter extends CustomPainter {
  final List<MeshNode> nodes;
  final List<MeshEdge> edges;
  final String? selectedNodeId;
  final double pulseValue;
  final bool searchActive;
  final bool Function(MeshNode) isNodeHighlighted;

  _MeshPainter({
    required this.nodes,
    required this.edges,
    required this.selectedNodeId,
    required this.pulseValue,
    required this.searchActive,
    required this.isNodeHighlighted,
  });

  @override
  void paint(Canvas canvas, Size size) {
    // 1. Draw Subtle Space Dot Grid
    final dotPaint = Paint()
      ..color = const Color(0x1AFFFFFF)
      ..style = PaintingStyle.fill;

    const spacing = 36.0;
    for (double x = 0; x < size.width; x += spacing) {
      for (double y = 0; y < size.height; y += spacing) {
        canvas.drawCircle(Offset(x, y), 0.8, dotPaint);
      }
    }

    final nodeMap = {for (final n in nodes) n.id: n};

    // 2. Draw Curved Edges
    for (final edge in edges) {
      final sNode = nodeMap[edge.sourceId];
      final tNode = nodeMap[edge.targetId];
      if (sNode == null || tNode == null) continue;

      final isSourceSelected = edge.sourceId == selectedNodeId;
      final isTargetSelected = edge.targetId == selectedNodeId;
      final isConnectedToSelected = isSourceSelected || isTargetSelected;

      final hasActiveHighlight = searchActive || selectedNodeId != null;
      final isHighlighted = isNodeHighlighted(sNode) && isNodeHighlighted(tNode);

      double opacity = 0.35;
      double width = edge.width;

      if (hasActiveHighlight) {
        if (isConnectedToSelected || isHighlighted) {
          opacity = 0.95;
          width = edge.width * 1.8;
        } else {
          opacity = 0.08;
        }
      }

      final linePaint = Paint()
        ..color = edge.color.withValues(alpha: opacity)
        ..strokeWidth = width
        ..style = PaintingStyle.stroke;

      // Draw gentle cubic/quadratic bezier curve
      final path = Path();
      path.moveTo(sNode.position.dx, sNode.position.dy);

      final midX = (sNode.position.dx + tNode.position.dx) / 2;
      final midY = (sNode.position.dy + tNode.position.dy) / 2;
      // Slight curvature perpendicular to vector
      final dx = tNode.position.dx - sNode.position.dx;
      final dy = tNode.position.dy - sNode.position.dy;
      final norm = math.sqrt(dx * dx + dy * dy);
      final curveOffset = (norm > 0) ? Offset(-dy / norm * 12, dx / norm * 12) : Offset.zero;

      path.quadraticBezierTo(
        midX + curveOffset.dx,
        midY + curveOffset.dy,
        tNode.position.dx,
        tNode.position.dy,
      );

      canvas.drawPath(path, linePaint);

      // Draw moving pulse particle along active edges
      if (isConnectedToSelected || (isHighlighted && searchActive)) {
        final metric = path.computeMetrics().firstOrNull;
        if (metric != null) {
          final t = (pulseValue * 1.5) % 1.0;
          final tangent = metric.getTangentForOffset(metric.length * t);
          if (tangent != null) {
            final particlePaint = Paint()
              ..color = Colors.amberAccent
              ..style = PaintingStyle.fill;
            canvas.drawCircle(tangent.position, 2.5, particlePaint);
          }
        }
      }
    }
  }

  @override
  bool shouldRepaint(covariant _MeshPainter oldDelegate) {
    return oldDelegate.selectedNodeId != selectedNodeId ||
        oldDelegate.pulseValue != pulseValue ||
        oldDelegate.searchActive != searchActive;
  }
}
