import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/connections_provider.dart';
import '../widgets/tag_chip.dart';
import '../widgets/synaptic_brain_mesh.dart';
import '../services/search_service.dart';
import 'connection_detail_screen.dart';

enum RecallViewMode {
  mesh,
  cards,
}

class SmartSearchScreen extends StatefulWidget {
  const SmartSearchScreen({super.key});

  @override
  State<SmartSearchScreen> createState() => _SmartSearchScreenState();
}

class _SmartSearchScreenState extends State<SmartSearchScreen> {
  final TextEditingController _searchController = TextEditingController();
  RecallViewMode _viewMode = RecallViewMode.mesh;

  static const List<String> _suggestedQueries = [
    "Aspirational founder",
    "Cam's Tech Talk Flutter",
    "On-device AI matcha",
    "Distributed systems CTO",
    "Aesthetic design system",
  ];

  @override
  void initState() {
    super.initState();
    final provider = Provider.of<ConnectionsProvider>(context, listen: false);
    _searchController.text = provider.searchQuery;
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final provider = Provider.of<ConnectionsProvider>(context);
    final results = provider.searchResults;

    final hasActiveFilter = provider.searchQuery.isNotEmpty ||
        provider.selectedEventFilter != null ||
        provider.selectedTechStackFilter != null ||
        provider.selectedVibeFilter != null;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Smart Memory Recall'),
        actions: [
          if (hasActiveFilter)
            TextButton(
              onPressed: () {
                _searchController.clear();
                provider.clearFilters();
              },
              child: const Text('Reset'),
            ),
        ],
      ),
      body: Column(
        children: [
          // Search & Memory Query Input
          Container(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 12),
            color: theme.scaffoldBackgroundColor,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                TextField(
                  controller: _searchController,
                  decoration: InputDecoration(
                    hintText: 'e.g. "Aspirational founder", "Cam\'s Tech Talk Flutter", "matcha"',
                    hintStyle: TextStyle(fontSize: 13, color: theme.hintColor),
                    prefixIcon: const Icon(Icons.psychology_rounded, color: Colors.amber),
                    suffixIcon: _searchController.text.isNotEmpty
                        ? IconButton(
                            icon: const Icon(Icons.clear, size: 18),
                            onPressed: () {
                              _searchController.clear();
                              provider.setSearchQuery('');
                            },
                          )
                        : null,
                    filled: true,
                    fillColor: theme.cardColor,
                    contentPadding: const EdgeInsets.symmetric(vertical: 12),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(16),
                      borderSide: BorderSide(color: theme.dividerColor.withValues(alpha: 0.3)),
                    ),
                  ),
                  onChanged: (val) => provider.setSearchQuery(val),
                ),

                const SizedBox(height: 10),

                // View Mode Segmented Control
                Container(
                  height: 38,
                  padding: const EdgeInsets.all(3),
                  decoration: BoxDecoration(
                    color: const Color(0xFF161B22),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: Colors.white12),
                  ),
                  child: Row(
                    children: [
                      Expanded(
                        child: Material(
                          color: Colors.transparent,
                          child: InkWell(
                            borderRadius: BorderRadius.circular(9),
                            onTap: () => setState(() => _viewMode = RecallViewMode.mesh),
                            child: Container(
                              decoration: BoxDecoration(
                                color: _viewMode == RecallViewMode.mesh
                                    ? const Color(0xFF2563EB)
                                    : Colors.transparent,
                                borderRadius: BorderRadius.circular(9),
                              ),
                              alignment: Alignment.center,
                              child: Row(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  Icon(
                                    Icons.psychology_rounded,
                                    size: 16,
                                    color: _viewMode == RecallViewMode.mesh ? Colors.white : Colors.white60,
                                  ),
                                  const SizedBox(width: 6),
                                  Text(
                                    'Neural Brain',
                                    style: TextStyle(
                                      fontSize: 12,
                                      fontWeight: FontWeight.w700,
                                      color: _viewMode == RecallViewMode.mesh ? Colors.white : Colors.white60,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ),
                      ),
                      Expanded(
                        child: Material(
                          color: Colors.transparent,
                          child: InkWell(
                            borderRadius: BorderRadius.circular(9),
                            onTap: () => setState(() => _viewMode = RecallViewMode.cards),
                            child: Container(
                              decoration: BoxDecoration(
                                color: _viewMode == RecallViewMode.cards
                                    ? const Color(0xFF2563EB)
                                    : Colors.transparent,
                                borderRadius: BorderRadius.circular(9),
                              ),
                              alignment: Alignment.center,
                              child: Row(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  Icon(
                                    Icons.view_agenda_rounded,
                                    size: 15,
                                    color: _viewMode == RecallViewMode.cards ? Colors.white : Colors.white60,
                                  ),
                                  const SizedBox(width: 6),
                                  Text(
                                    'Ranked Cards',
                                    style: TextStyle(
                                      fontSize: 12,
                                      fontWeight: FontWeight.w700,
                                      color: _viewMode == RecallViewMode.cards ? Colors.white : Colors.white60,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),

                // Quick Prompt Suggestions (only shown in Ranked Cards mode for quick filtering)
                if (_viewMode == RecallViewMode.cards) ...[
                  const SizedBox(height: 10),
                  SingleChildScrollView(
                    scrollDirection: Axis.horizontal,
                    child: Row(
                      children: [
                        const Text(
                          'Recall cue: ',
                          style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Colors.grey),
                        ),
                        ..._suggestedQueries.map((q) {
                          return Padding(
                            padding: const EdgeInsets.only(right: 6),
                            child: ActionChip(
                              label: Text(
                                q,
                                style: TextStyle(
                                  fontSize: 11,
                                  color: Colors.amber.shade700,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                              backgroundColor: Colors.amber.withValues(alpha: 0.1),
                              side: BorderSide(color: Colors.amber.withValues(alpha: 0.3)),
                              padding: const EdgeInsets.symmetric(horizontal: 2, vertical: 0),
                              onPressed: () {
                                _searchController.text = q;
                                provider.setSearchQuery(q);
                              },
                            ),
                          );
                        }),
                      ],
                    ),
                  ),
                ],
              ],
            ),
          ),

          const Divider(height: 1),

          // Main Content: Synaptic Brain Mesh OR Ranked Cards List
          Expanded(
            child: _viewMode == RecallViewMode.mesh
                ? SynapticBrainMesh(
                    connections: provider.connections,
                    searchQuery: provider.searchQuery,
                    selectedEventFilter: provider.selectedEventFilter,
                    selectedTechFilter: provider.selectedTechStackFilter,
                    selectedVibeFilter: provider.selectedVibeFilter,
                    onPromptSelected: (prompt) {
                      _searchController.text = prompt;
                      provider.setSearchQuery(prompt);
                    },
                  )
                : _buildCardsList(context, results, theme),
          ),
        ],
      ),
    );
  }

  Widget _buildCardsList(BuildContext context, List<SearchResult> results, ThemeData theme) {
    if (results.isEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.person_search_outlined, size: 64, color: theme.hintColor.withValues(alpha: 0.4)),
              const SizedBox(height: 16),
              Text(
                'No connections match your query',
                style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 8),
              Text(
                'Try searching by event name, vibes (e.g. "aspirational"), or discussions.',
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 13, color: theme.hintColor),
              ),
            ],
          ),
        ),
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: results.length,
      itemBuilder: (ctx, i) {
        final item = results[i];
        final conn = item.connection;
        final ev = conn.eventContext;

        return Card(
          margin: const EdgeInsets.only(bottom: 14),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(18),
            side: BorderSide(
              color: item.score > 30
                  ? Colors.amber.withValues(alpha: 0.5)
                  : theme.dividerColor.withValues(alpha: 0.2),
              width: item.score > 30 ? 1.5 : 1,
            ),
          ),
          child: InkWell(
            onTap: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => ConnectionDetailScreen(connectionId: conn.id),
                ),
              );
            },
            borderRadius: BorderRadius.circular(18),
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Match Reason Banner (Explains WHY this person was recalled)
                  if (item.matchReasons.isNotEmpty)
                    Container(
                      margin: const EdgeInsets.only(bottom: 12),
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                      decoration: BoxDecoration(
                        color: Colors.amber.withValues(alpha: 0.15),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Row(
                        children: [
                          const Icon(Icons.auto_awesome, size: 14, color: Colors.amber),
                          const SizedBox(width: 6),
                          Expanded(
                            child: Text(
                              item.matchReasons.join(' • '),
                              style: TextStyle(
                                fontSize: 11,
                                fontWeight: FontWeight.bold,
                                color: Colors.amber.shade900,
                              ),
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                        ],
                      ),
                    ),

                  // Profile Header Row
                  Row(
                    children: [
                      CircleAvatar(
                        radius: 22,
                        backgroundColor: Colors.blue.withValues(alpha: 0.15),
                        child: Text(
                          conn.fullName.isNotEmpty
                              ? conn.fullName.trim().split(' ').map((e) => e.isNotEmpty ? e[0] : '').take(2).join()
                              : '?',
                          style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.blue),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              conn.fullName,
                              style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                            ),
                            if (conn.role.isNotEmpty || conn.company.isNotEmpty)
                              Text(
                                [if (conn.role.isNotEmpty) conn.role, if (conn.company.isNotEmpty) conn.company].join(' @ '),
                                style: TextStyle(fontSize: 12, color: theme.hintColor),
                              ),
                          ],
                        ),
                      ),
                      const Icon(Icons.arrow_forward_ios, size: 14, color: Colors.grey),
                    ],
                  ),

                  // Message to Future Self (The Human Touch!)
                  if (conn.futureSelfNote.isNotEmpty) ...[
                    const SizedBox(height: 10),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                      decoration: BoxDecoration(
                        color: Colors.amber.withValues(alpha: 0.08),
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(color: Colors.amber.withValues(alpha: 0.2)),
                      ),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Icon(Icons.mark_email_read_rounded, size: 14, color: Colors.amber),
                          const SizedBox(width: 6),
                          Expanded(
                            child: Text(
                              conn.futureSelfNote.startsWith('Note to Future Self:')
                                  ? conn.futureSelfNote.substring(20).trim()
                                  : conn.futureSelfNote,
                              style: const TextStyle(
                                fontSize: 12,
                                fontStyle: FontStyle.italic,
                                color: Colors.amber,
                                height: 1.3,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],

                  // Vibe Badges
                  if (conn.vibeTags.isNotEmpty) ...[
                    const SizedBox(height: 8),
                    Wrap(
                      spacing: 6,
                      runSpacing: 4,
                      children: conn.vibeTags.map<Widget>((vibe) {
                        return TagChip(
                          label: '✨ $vibe',
                          backgroundColor: Colors.purple.withValues(alpha: 0.12),
                          textColor: Colors.purple.shade300,
                        );
                      }).toList(),
                    ),
                  ],

                  const SizedBox(height: 10),

                  // Event Context Row
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                    decoration: BoxDecoration(
                      color: theme.scaffoldBackgroundColor,
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Row(
                      children: [
                        const Icon(Icons.location_on_rounded, size: 14, color: Colors.amber),
                        const SizedBox(width: 4),
                        Expanded(
                          child: Text(
                            'Met at: ${ev.eventName}',
                            style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600),
                          ),
                        ),
                      ],
                    ),
                  ),

                  if (ev.notes.isNotEmpty) ...[
                    const SizedBox(height: 8),
                    Text(
                      ev.notes,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(fontSize: 12, color: theme.textTheme.bodyMedium?.color?.withValues(alpha: 0.85)),
                    ),
                  ],

                  // Tech Stack Tags
                  if (conn.techStack.isNotEmpty) ...[
                    const SizedBox(height: 10),
                    Wrap(
                      spacing: 6,
                      runSpacing: 6,
                      children: conn.techStack.take(5).map<Widget>((t) {
                        return TagChip(
                          label: t,
                          backgroundColor: Colors.blue.withValues(alpha: 0.08),
                          textColor: Colors.blue,
                        );
                      }).toList(),
                    ),
                  ],
                ],
              ),
            ),
          ),
        );
      },
    );
  }
}
