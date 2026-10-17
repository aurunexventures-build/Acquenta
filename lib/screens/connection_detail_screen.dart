import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import 'package:share_plus/share_plus.dart';
import 'package:url_launcher/url_launcher.dart';
import '../models/saved_connection.dart';
import '../models/event_context.dart';
import '../providers/connections_provider.dart';
import '../services/vcard_service.dart';
import '../widgets/tag_chip.dart';
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
                  content: Text('Remove ${conn.fullName} from your connections?'),
                  actions: [
                    TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
                    ElevatedButton(
                      style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
                      onPressed: () {
                        provider.deleteConnection(conn.id);
                        Navigator.pop(ctx);
                        Navigator.pop(context);
                      },
                      child: const Text('Delete', style: TextStyle(color: Colors.white)),
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
            // Header Card
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: theme.cardColor,
                borderRadius: BorderRadius.circular(20),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.05),
                    blurRadius: 14,
                    offset: const Offset(0, 4),
                  ),
                ],
              ),
              child: Column(
                children: [
                  CircleAvatar(
                    radius: 36,
                    backgroundColor: Colors.blue.withValues(alpha: 0.15),
                    child: Text(
                      conn.fullName.isNotEmpty
                          ? conn.fullName.trim().split(' ').map((e) => e.isNotEmpty ? e[0] : '').take(2).join()
                          : '?',
                      style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold, color: Colors.blue),
                    ),
                  ),
                  const SizedBox(height: 12),
                  Text(
                    conn.fullName,
                    style: theme.textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.bold),
                  ),
                  if (conn.role.isNotEmpty || conn.company.isNotEmpty) ...[
                    const SizedBox(height: 4),
                    Text(
                      [if (conn.role.isNotEmpty) conn.role, if (conn.company.isNotEmpty) conn.company].join(' @ '),
                      style: TextStyle(fontSize: 14, color: theme.hintColor, fontWeight: FontWeight.w500),
                    ),
                  ],
                  if (conn.headline.isNotEmpty) ...[
                    const SizedBox(height: 10),
                    Text(
                      conn.headline,
                      textAlign: TextAlign.center,
                      style: const TextStyle(fontSize: 13),
                    ),
                  ],
                ],
              ),
            ),

            const SizedBox(height: 20),

            // Event Memory Block (Context Recall)
            Container(
              padding: const EdgeInsets.all(18),
              decoration: BoxDecoration(
                color: Colors.amber.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(20),
                border: Border.all(color: Colors.amber.withValues(alpha: 0.4)),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      const Icon(Icons.psychology_alt_rounded, color: Colors.amber, size: 22),
                      const SizedBox(width: 8),
                      Text(
                        'Meeting Memory Context',
                        style: theme.textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.bold,
                          color: Colors.amber.shade900,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      const Icon(Icons.event, size: 16, color: Colors.amber),
                      const SizedBox(width: 6),
                      Text(
                        ev.eventName.isNotEmpty ? ev.eventName : 'Met at Networking',
                        style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
                      ),
                      const Spacer(),
                      Text(
                        DateFormat('MMM d, y').format(ev.date),
                        style: TextStyle(fontSize: 12, color: theme.hintColor),
                      ),
                    ],
                  ),
                  if (ev.location.isNotEmpty) ...[
                    const SizedBox(height: 6),
                    Row(
                      children: [
                        Icon(Icons.location_on_outlined, size: 16, color: theme.hintColor),
                        const SizedBox(width: 6),
                        Text(ev.location, style: TextStyle(fontSize: 12, color: theme.hintColor)),
                      ],
                    ),
                  ],
                  if (ev.notes.isNotEmpty) ...[
                    const SizedBox(height: 12),
                    const Divider(height: 1),
                    const SizedBox(height: 10),
                    const Text(
                      'Discussion / What They Do:',
                      style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12),
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
                    color: Colors.amber.withValues(alpha: 0.35),
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
                          const Icon(Icons.mail_outline_rounded, size: 18, color: Colors.amber),
                          const SizedBox(width: 8),
                          Text(
                            'Message to My Future Self',
                            style: theme.textTheme.titleMedium?.copyWith(
                              fontWeight: FontWeight.bold,
                              color: Colors.amber,
                            ),
                          ),
                        ],
                      ),
                      if (conn.futureSelfNote.isNotEmpty) ...[
                        const SizedBox(height: 10),
                        Container(
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: Colors.amber.withValues(alpha: 0.06),
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(color: Colors.amber.withValues(alpha: 0.15)),
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
                              backgroundColor: Colors.purple.withValues(alpha: 0.12),
                              textColor: Colors.purple.shade300,
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
            if (conn.distinctiveMemory.isNotEmpty || conn.microContext.isNotEmpty || conn.callWhen.isNotEmpty) ...[
              const SizedBox(height: 18),
              Card(
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16),
                  side: BorderSide(
                    color: Colors.indigo.withValues(alpha: 0.35),
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
                          const Icon(Icons.hub_rounded, size: 18, color: Colors.indigo),
                          const SizedBox(width: 8),
                          Text(
                            'Cognitive Recall Anchors',
                            style: theme.textTheme.titleMedium?.copyWith(
                              fontWeight: FontWeight.bold,
                              color: Colors.indigo,
                            ),
                          ),
                        ],
                      ),
                      if (conn.distinctiveMemory.isNotEmpty) ...[
                        const SizedBox(height: 12),
                        const Text(
                          'Visual & Sensory Quirk (Memory Cue):',
                          style: TextStyle(fontWeight: FontWeight.bold, fontSize: 11, color: Colors.grey),
                        ),
                        const SizedBox(height: 4),
                        Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Icon(Icons.visibility_outlined, size: 15, color: Colors.indigo),
                            const SizedBox(width: 6),
                            Expanded(
                              child: Text(
                                conn.distinctiveMemory,
                                style: const TextStyle(fontSize: 13, height: 1.35),
                              ),
                            ),
                          ],
                        ),
                      ],
                      if (conn.microContext.isNotEmpty) ...[
                        const SizedBox(height: 12),
                        const Text(
                          'Micro-Scene Context:',
                          style: TextStyle(fontWeight: FontWeight.bold, fontSize: 11, color: Colors.grey),
                        ),
                        const SizedBox(height: 4),
                        Row(
                          children: [
                            const Icon(Icons.place_outlined, size: 15, color: Colors.indigo),
                            const SizedBox(width: 6),
                            Text(
                              conn.microContext,
                              style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w500),
                            ),
                          ],
                        ),
                      ],
                      if (conn.callWhen.isNotEmpty) ...[
                        const SizedBox(height: 12),
                        const Text(
                          'Situational "Call When..." Triggers:',
                          style: TextStyle(fontWeight: FontWeight.bold, fontSize: 11, color: Colors.grey),
                        ),
                        const SizedBox(height: 6),
                        Wrap(
                          spacing: 6,
                          runSpacing: 6,
                          children: conn.callWhen.map((trigger) {
                            return TagChip(
                              label: '📞 $trigger',
                              backgroundColor: Colors.teal.withValues(alpha: 0.12),
                              textColor: Colors.teal.shade300,
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

            // Tech Stack & Skills
            if (conn.techStack.isNotEmpty || ev.tags.isNotEmpty) ...[
              Card(
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Tech Stack & Skills',
                        style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
                      ),
                      const SizedBox(height: 10),
                      Wrap(
                        spacing: 8,
                        runSpacing: 8,
                        children: {
                          ...conn.techStack,
                          ...ev.tags,
                        }.map((t) => TagChip(label: t, backgroundColor: Colors.blue.withValues(alpha: 0.1), textColor: Colors.blue)).toList(),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 20),
            ],

            // Direct Communication Actions
            Card(
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text('Contact & Connect', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
                    const SizedBox(height: 12),
                    if (conn.phone.isNotEmpty)
                      ListTile(
                        contentPadding: EdgeInsets.zero,
                        leading: const CircleAvatar(child: Icon(Icons.phone, size: 18)),
                        title: Text(conn.phone),
                        subtitle: const Text('Phone Number'),
                        trailing: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            IconButton(
                              icon: const Icon(Icons.call, color: Colors.green),
                              onPressed: () => launchUrl(Uri.parse('tel:${conn.phone}')),
                            ),
                            IconButton(
                              icon: const Icon(Icons.sms, color: Colors.blue),
                              onPressed: () => launchUrl(Uri.parse('sms:${conn.phone}')),
                            ),
                          ],
                        ),
                      ),
                    if (conn.email.isNotEmpty)
                      ListTile(
                        contentPadding: EdgeInsets.zero,
                        leading: const CircleAvatar(child: Icon(Icons.email, size: 18)),
                        title: Text(conn.email),
                        subtitle: const Text('Email Address'),
                        trailing: IconButton(
                          icon: const Icon(Icons.send_rounded, color: Colors.blue),
                          onPressed: () => launchUrl(Uri.parse('mailto:${conn.email}')),
                        ),
                      ),
                    ...conn.links.map((link) {
                      return ListTile(
                        contentPadding: EdgeInsets.zero,
                        leading: CircleAvatar(child: Icon(link.defaultIcon, size: 18)),
                        title: Text(link.title),
                        subtitle: Text(link.url, maxLines: 1, overflow: TextOverflow.ellipsis),
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

            const SizedBox(height: 24),

            // Export to Phone Contacts (vCard)
            ElevatedButton.icon(
              style: ElevatedButton.styleFrom(
                padding: const EdgeInsets.symmetric(vertical: 14),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
              ),
              icon: const Icon(Icons.person_add_alt_1_rounded),
              label: const Text('Export vCard to Phone Contacts', style: TextStyle(fontWeight: FontWeight.bold)),
              onPressed: () {
                final vcard = VCardService.generateConnectionVCard(conn);
                Clipboard.setData(ClipboardData(text: vcard));
                Share.share(
                  vcard,
                  subject: '${conn.fullName} - vCard',
                );
              },
            ),

            const SizedBox(height: 40),
          ],
        ),
      ),
    );
  }
}
