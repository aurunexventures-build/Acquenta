import '../theme/metcue_theme.dart';
import '../widgets/face_avatar.dart';
import '../widgets/follow_up_card.dart';
import '../widgets/relationship_tools.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import 'package:url_launcher/url_launcher.dart';
import '../models/saved_connection.dart';
import '../models/event_context.dart';
import '../providers/connections_provider.dart';
import '../services/vcard_service.dart';
import '../widgets/tag_chip.dart';
import '../widgets/voice_capture_dialog.dart';
import 'add_connection_screen.dart';

class ConnectionDetailScreen extends StatelessWidget {
  final String connectionId;

  const ConnectionDetailScreen({super.key, required this.connectionId});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final provider = Provider.of<ConnectionsProvider>(context);
    final conn = provider.connections.firstWhere(
      (c) => c.id == connectionId,
      orElse: () => SavedConnection(
        id: '',
        fullName: 'Unknown',
        eventContext: EventContext(eventName: '', date: DateTime.now()),
        savedAt: DateTime.now(),
      ),
    );

    if (conn.id.isEmpty) {
      return Scaffold(
        appBar: AppBar(title: const Text('Connection unavailable')),
        body: const Center(
          child: Text(
            'This connection was removed or belongs to another account.',
          ),
        ),
      );
    }
    final ev = conn.eventContext;

    return Scaffold(
      appBar: AppBar(
        title: Text(conn.fullName),
        actions: [
          IconButton(
            icon: Icon(
              conn.isFavorite ? Icons.star : Icons.star_border,
              color: conn.isFavorite ? Colors.amber : null,
            ),
            tooltip: 'Favorite',
            onPressed: () => provider.toggleFavorite(conn.id),
          ),
          IconButton(
            icon: const Icon(Icons.edit_outlined),
            tooltip: 'Edit',
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => AddConnectionScreen(initialConnection: conn),
                ),
              );
            },
          ),
          IconButton(
            icon: const Icon(Icons.delete_outline, color: Colors.red),
            tooltip: 'Delete',
            onPressed: () {
              showDialog(
                context: context,
                builder: (ctx) => AlertDialog(
                  title: const Text('Delete Connection?'),
                  content: Text(
                    'Remove ${conn.fullName} from your connections?',
                  ),
                  actions: [
                    TextButton(
                      onPressed: () => Navigator.pop(ctx),
                      child: const Text('Cancel'),
                    ),
                    ElevatedButton(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.red,
                      ),
                      onPressed: () {
                        provider.deleteConnection(conn.id);
                        Navigator.pop(ctx);
                        Navigator.pop(context);
                      },
                      child: const Text(
                        'Delete',
                        style: TextStyle(color: Colors.white),
                      ),
                    ),
                  ],
                ),
              );
            },
          ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: theme.cardColor,
                borderRadius: BorderRadius.circular(20),
              ),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  FaceAvatar(
                    name: conn.fullName,
                    photo: conn.avatarUrl,
                    radius: 28,
                    backgroundColor: MetCueTheme.purple.withValues(alpha: .15),
                    foregroundColor: MetCueTheme.purple,
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          conn.fullName,
                          style: theme.textTheme.titleLarge?.copyWith(
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        if (conn.role.isNotEmpty || conn.company.isNotEmpty)
                          Padding(
                            padding: const EdgeInsets.only(top: 4),
                            child: Text(
                              [
                                if (conn.role.isNotEmpty) conn.role,
                                if (conn.company.isNotEmpty) conn.company,
                              ].join(' · '),
                              style: theme.textTheme.bodyMedium,
                            ),
                          ),
                        if (conn.headline.isNotEmpty &&
                            conn.headline.trim().toLowerCase() !=
                                conn.role.trim().toLowerCase())
                          Padding(
                            padding: const EdgeInsets.only(top: 8),
                            child: Text(
                              conn.headline,
                              style: theme.textTheme.bodySmall,
                            ),
                          ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 12),
            // Direct Communication Actions
            if (conn.phone.isNotEmpty ||
                conn.email.isNotEmpty ||
                conn.links.isNotEmpty)
              Card(
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Contact & Connect',
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 14,
                        ),
                      ),
                      const SizedBox(height: 12),
                      if (conn.phone.isNotEmpty)
                        ListTile(
                          contentPadding: EdgeInsets.zero,
                          leading: const CircleAvatar(
                            child: Icon(Icons.phone, size: 18),
                          ),
                          title: Text(
                            conn.phone,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                          subtitle: const Text('Phone Number'),
                          trailing: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              IconButton(
                                icon: const Icon(
                                  Icons.call,
                                  color: Colors.green,
                                ),
                                onPressed: () =>
                                    launchUrl(Uri.parse('tel:${conn.phone}')),
                              ),
                              IconButton(
                                icon: const Icon(
                                  Icons.sms,
                                  color: MetCueTheme.purple,
                                ),
                                onPressed: () =>
                                    launchUrl(Uri.parse('sms:${conn.phone}')),
                              ),
                            ],
                          ),
                        ),
                      if (conn.email.isNotEmpty)
                        ListTile(
                          contentPadding: EdgeInsets.zero,
                          leading: const CircleAvatar(
                            child: Icon(Icons.email, size: 18),
                          ),
                          title: Text(
                            conn.email,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                          subtitle: const Text('Email Address'),
                          trailing: IconButton(
                            icon: const Icon(
                              Icons.send_rounded,
                              color: MetCueTheme.purple,
                            ),
                            onPressed: () =>
                                launchUrl(Uri.parse('mailto:${conn.email}')),
                          ),
                        ),
                      ...conn.links.map((link) {
                        return ListTile(
                          contentPadding: EdgeInsets.zero,
                          leading: CircleAvatar(
                            child: Icon(link.defaultIcon, size: 18),
                          ),
                          title: Text(link.title),
                          subtitle: Text(
                            link.url,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                          trailing: const Icon(Icons.open_in_new, size: 18),
                          onTap: () async {
                            final uri = Uri.tryParse(link.url);
                            if (uri != null && await canLaunchUrl(uri)) {
                              await launchUrl(uri);
                            }
                          },
                        );
                      }),
                    ],
                  ),
                ),
              ),

            FilledButton.icon(
              onPressed: () => showDialog(
                context: context,
                builder: (_) => VoiceCaptureDialog(
                  connection: conn,
                  onCaptured: (updated) => provider.updateConnection(
                    updated,
                    expectedVersion: conn.updatedAt,
                  ),
                ),
              ),
              icon: const Icon(Icons.mic),
              label: const Text('Add a memory cue'),
            ),

            // Export to Phone Contacts (vCard)
            ElevatedButton.icon(
              style: ElevatedButton.styleFrom(
                padding: const EdgeInsets.symmetric(vertical: 14),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(14),
                ),
              ),
              icon: const Icon(Icons.person_add_alt_1_rounded),
              label: const Text(
                'Save to phone contacts',
                style: TextStyle(fontWeight: FontWeight.bold),
              ),
              onPressed: () async {
                final box = context.findRenderObject() as RenderBox?;
                try {
                  await VCardService.exportContact(
                    vcard: VCardService.generateConnectionVCard(conn),
                    name: conn.fullName,
                    sharePositionOrigin: box == null
                        ? null
                        : box.localToGlobal(Offset.zero) & box.size,
                  );
                } catch (_) {
                  if (context.mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                        content: Text(
                          'Could not open contacts. Please try again.',
                        ),
                        duration: Duration(seconds: 3),
                      ),
                    );
                  }
                }
              },
            ),

            // Only show meeting context that the user actually saved.
            if (ev.eventName.isNotEmpty ||
                ev.location.isNotEmpty ||
                ev.notes.isNotEmpty)
              Container(
                padding: const EdgeInsets.all(18),
                decoration: BoxDecoration(
                  color: MetCueTheme.purple.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(
                    color: MetCueTheme.purple.withValues(alpha: 0.4),
                  ),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        const Icon(
                          Icons.psychology_alt_rounded,
                          color: MetCueTheme.purple,
                          size: 22,
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            'Where you met',
                            style: theme.textTheme.titleMedium?.copyWith(
                              fontWeight: FontWeight.bold,
                              color: MetCueTheme.purple,
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    Row(
                      children: [
                        const Icon(
                          Icons.event,
                          size: 16,
                          color: MetCueTheme.purple,
                        ),
                        const SizedBox(width: 6),
                        Expanded(
                          child: Text(
                            ev.eventName.isNotEmpty
                                ? ev.eventName
                                : 'Meeting details',
                            style: const TextStyle(
                              fontWeight: FontWeight.bold,
                              fontSize: 14,
                            ),
                          ),
                        ),
                        const SizedBox(width: 8),
                        Text(
                          DateFormat('MMM d, y').format(ev.date),
                          style: TextStyle(
                            fontSize: 12,
                            color: theme.hintColor,
                          ),
                        ),
                      ],
                    ),
                    if (ev.location.isNotEmpty) ...[
                      const SizedBox(height: 6),
                      Row(
                        children: [
                          Icon(
                            Icons.location_on_outlined,
                            size: 16,
                            color: theme.hintColor,
                          ),
                          const SizedBox(width: 6),
                          Expanded(
                            child: Text(
                              ev.location,
                              style: TextStyle(
                                fontSize: 12,
                                color: theme.hintColor,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ],
                    if (ev.notes.isNotEmpty) ...[
                      const SizedBox(height: 12),
                      const Divider(height: 1),
                      const SizedBox(height: 10),
                      const Text(
                        'What you talked about',
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 12,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        ev.notes,
                        style: const TextStyle(fontSize: 13, height: 1.4),
                      ),
                    ],
                  ],
                ),
              ),

            // Message to Future Self
            if (conn.futureSelfNote.isNotEmpty || conn.vibeTags.isNotEmpty) ...[
              const SizedBox(height: 18),
              Card(
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16),
                  side: BorderSide(
                    color: MetCueTheme.purple.withValues(alpha: 0.35),
                    width: 1,
                  ),
                ),
                color: theme.cardColor,
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          const Icon(
                            Icons.mail_outline_rounded,
                            size: 18,
                            color: MetCueTheme.purple,
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              'Message to My Future Self',
                              style: theme.textTheme.titleMedium?.copyWith(
                                fontWeight: FontWeight.bold,
                                color: MetCueTheme.purple,
                              ),
                            ),
                          ),
                        ],
                      ),
                      if (conn.futureSelfNote.isNotEmpty) ...[
                        const SizedBox(height: 10),
                        Container(
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: MetCueTheme.purple.withValues(alpha: 0.06),
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(
                              color: MetCueTheme.purple.withValues(alpha: 0.15),
                            ),
                          ),
                          child: Text(
                            '"${conn.futureSelfNote.startsWith('Note to Future Self:') ? conn.futureSelfNote.substring(20).trim() : conn.futureSelfNote}"',
                            style: const TextStyle(
                              fontSize: 13,
                              fontStyle: FontStyle.italic,
                              height: 1.45,
                            ),
                          ),
                        ),
                      ],
                      if (conn.vibeTags.isNotEmpty) ...[
                        const SizedBox(height: 12),
                        Wrap(
                          spacing: 6,
                          runSpacing: 6,
                          children: conn.vibeTags.map((vibe) {
                            return TagChip(
                              label: '✨ $vibe',
                              backgroundColor: Color(
                                0xFF6554C0,
                              ).withValues(alpha: 0.12),
                              textColor: MetCueTheme.purple,
                            );
                          }).toList(),
                        ),
                      ],
                    ],
                  ),
                ),
              ),
            ],

            // Cognitive Memory Anchors (1-Year Recall)
            if (conn.distinctiveMemory.isNotEmpty ||
                conn.microContext.isNotEmpty ||
                conn.callWhen.isNotEmpty) ...[
              const SizedBox(height: 18),
              Card(
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16),
                  side: BorderSide(
                    color: MetCueTheme.purple.withValues(alpha: 0.35),
                    width: 1,
                  ),
                ),
                color: theme.cardColor,
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          const Icon(
                            Icons.hub_rounded,
                            size: 18,
                            color: MetCueTheme.purple,
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              'Cognitive Recall Anchors',
                              style: theme.textTheme.titleMedium?.copyWith(
                                fontWeight: FontWeight.bold,
                                color: MetCueTheme.purple,
                              ),
                            ),
                          ),
                        ],
                      ),
                      if (conn.distinctiveMemory.isNotEmpty) ...[
                        const SizedBox(height: 12),
                        const Text(
                          'Visual & Sensory Quirk (Memory Cue):',
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 11,
                            color: MetCueTheme.muted,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Icon(
                              Icons.visibility_outlined,
                              size: 15,
                              color: MetCueTheme.purple,
                            ),
                            const SizedBox(width: 6),
                            Expanded(
                              child: Text(
                                conn.distinctiveMemory,
                                style: const TextStyle(
                                  fontSize: 13,
                                  height: 1.35,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ],
                      if (conn.microContext.isNotEmpty) ...[
                        const SizedBox(height: 12),
                        const Text(
                          'What you remember',
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 11,
                            color: MetCueTheme.muted,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Row(
                          children: [
                            const Icon(
                              Icons.place_outlined,
                              size: 15,
                              color: MetCueTheme.purple,
                            ),
                            const SizedBox(width: 6),
                            Expanded(
                              child: Text(
                                conn.microContext,
                                style: const TextStyle(
                                  fontSize: 13,
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ],
                      if (conn.callWhen.isNotEmpty) ...[
                        const SizedBox(height: 12),
                        const Text(
                          'Reach out about',
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 11,
                            color: MetCueTheme.muted,
                          ),
                        ),
                        const SizedBox(height: 6),
                        Wrap(
                          spacing: 6,
                          runSpacing: 6,
                          children: conn.callWhen.map((trigger) {
                            return TagChip(
                              label: '📞 $trigger',
                              backgroundColor: Colors.teal.withValues(
                                alpha: 0.12,
                              ),
                              textColor: Color(0xFF326C68),
                            );
                          }).toList(),
                        ),
                      ],
                    ],
                  ),
                ),
              ),
            ],

            const SizedBox(height: 20),

            // Skills & interests
            if (conn.techStack.isNotEmpty || ev.tags.isNotEmpty) ...[
              Card(
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Skills & interests',
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 14,
                        ),
                      ),
                      const SizedBox(height: 10),
                      Wrap(
                        spacing: 8,
                        runSpacing: 8,
                        children: {...conn.techStack, ...ev.tags}
                            .map(
                              (t) => TagChip(
                                label: t,
                                backgroundColor: Color(
                                  0xFF6554C0,
                                ).withValues(alpha: 0.1),
                                textColor: MetCueTheme.purple,
                              ),
                            )
                            .toList(),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 20),
            ],

            const SizedBox(height: 24),

            ExpansionTile(
              title: const Text('Notes & activity'),
              subtitle: const Text('Memories, conversations and follow-ups'),
              children: [
                const SizedBox(height: 16),
                FollowUpCard(connection: conn),
                RelationshipTools(connection: conn),
                if (conn.rawCue.isNotEmpty)
                  Card(
                    child: Padding(
                      padding: const EdgeInsets.all(16),
                      child: Text('Your original memory\n${conn.rawCue}'),
                    ),
                  ),
                for (final turn in conn.cueConversation)
                  Card(
                    child: Padding(
                      padding: const EdgeInsets.all(16),
                      child: Text('${turn['question']}\n${turn['answer']}'),
                    ),
                  ),
              ],
            ),
            const SizedBox(height: 40),
          ],
        ),
      ),
    );
  }
}
