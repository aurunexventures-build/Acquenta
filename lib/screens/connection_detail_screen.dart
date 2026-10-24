import '../widgets/card_finish_picker.dart';
import '../services/connection_insights.dart';
import '../widgets/social_icon_row.dart';
import '../widgets/acquenta_bot_icon.dart';
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
    final colour = Color(
      int.tryParse(conn.themeColorHex.replaceFirst('#', 'FF'), radix: 16) ??
          0xFF243E65,
    );
    final surface = colour.computeLuminance() > .22
        ? Color.lerp(colour, Colors.black, .65)!
        : colour;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Connection'),
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
      body: SafeArea(
        top: false,
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(20, 12, 20, 32),
          child: Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 640),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Container(
                    padding: const EdgeInsets.all(20),
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                        colors: [
                          surface,
                          Color.lerp(surface, Colors.black, .16)!,
                        ],
                      ),
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: CustomPaint(
                      painter: CardFinishPainter(
                        conn.cardFinish,
                        conn.fullName,
                      ),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          FaceAvatar(
                            name: conn.fullName,
                            photo: conn.avatarUrl,
                            radius: 28,
                            backgroundColor: Colors.white12,
                            foregroundColor: Colors.white,
                          ),
                          const SizedBox(width: 16),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  conn.fullName,
                                  style: theme.textTheme.titleLarge?.copyWith(
                                    fontWeight: FontWeight.bold,
                                    color: Colors.white,
                                  ),
                                ),
                                if (conn.role.isNotEmpty)
                                  Padding(
                                    padding: const EdgeInsets.only(top: 4),
                                    child: Text(
                                      conn.role,
                                      style: theme.textTheme.bodyMedium
                                          ?.copyWith(color: Colors.white70),
                                    ),
                                  ),
                                if (conn.company.isNotEmpty)
                                  Padding(
                                    padding: const EdgeInsets.only(top: 3),
                                    child: Text(
                                      conn.company,
                                      style: theme.textTheme.bodySmall
                                          ?.copyWith(color: Colors.white70),
                                    ),
                                  ),
                                if (conn.headline.isNotEmpty &&
                                    conn.headline.trim().toLowerCase() !=
                                        conn.role.trim().toLowerCase())
                                  Padding(
                                    padding: const EdgeInsets.only(top: 10),
                                    child: Text(
                                      conn.headline,
                                      style: theme.textTheme.bodyMedium
                                          ?.copyWith(
                                            height: 1.4,
                                            color: Colors.white,
                                          ),
                                    ),
                                  ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                  if (conn.phone.isNotEmpty ||
                      conn.email.isNotEmpty ||
                      conn.links.isNotEmpty) ...[
                    const SizedBox(height: 16),
                    Text('Contact', style: theme.textTheme.titleSmall),
                    const SizedBox(height: 8),
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: [
                        if (conn.phone.isNotEmpty)
                          OutlinedButton.icon(
                            onPressed: () => _openContact(
                              context,
                              Uri(scheme: 'tel', path: conn.phone),
                            ),
                            icon: const Icon(Icons.call_outlined, size: 18),
                            label: const Text('Call'),
                          ),
                        if (conn.phone.isNotEmpty)
                          OutlinedButton.icon(
                            onPressed: () => _openContact(
                              context,
                              Uri(scheme: 'sms', path: conn.phone),
                            ),
                            icon: const Icon(
                              Icons.chat_bubble_outline,
                              size: 18,
                            ),
                            label: const Text('Message'),
                          ),
                        if (conn.email.isNotEmpty)
                          OutlinedButton.icon(
                            onPressed: () => _openContact(
                              context,
                              Uri(scheme: 'mailto', path: conn.email),
                            ),
                            icon: const Icon(Icons.mail_outline, size: 18),
                            label: const Text('Email'),
                          ),
                      ],
                    ),
                    if (conn.links.isNotEmpty)
                      SocialIconRow(
                        links: conn.links,
                        color: MetCueTheme.purple,
                      ),
                    if (conn.phone.isNotEmpty || conn.email.isNotEmpty)
                      ExpansionTile(
                        tilePadding: EdgeInsets.zero,
                        title: const Text(
                          'Contact details',
                          style: TextStyle(fontSize: 14),
                        ),
                        childrenPadding: const EdgeInsets.only(bottom: 12),
                        children: [
                          if (conn.phone.isNotEmpty)
                            ListTile(
                              contentPadding: EdgeInsets.zero,
                              leading: const Icon(Icons.phone_outlined),
                              title: SelectableText(conn.phone),
                            ),
                          if (conn.email.isNotEmpty)
                            ListTile(
                              contentPadding: EdgeInsets.zero,
                              leading: const Icon(Icons.mail_outline),
                              title: SelectableText(conn.email),
                            ),
                        ],
                      ),
                  ],
                  const SizedBox(height: 24),
                  FilledButton.icon(
                    style: FilledButton.styleFrom(
                      minimumSize: const Size.fromHeight(52),
                    ),
                    key: const ValueKey('add-connection-memory'),
                    onPressed: () => showDialog(
                      context: context,
                      builder: (_) => VoiceCaptureDialog(
                        guided: true,
                        connection: conn,
                        onCaptured: (updated) => provider.updateConnection(
                          updated,
                          expectedVersion: conn.updatedAt,
                        ),
                      ),
                    ),
                    icon: const AcquentaBotIcon(size: 24),
                    label: const Text('Talk to Acquenta AI'),
                  ),
                  const SizedBox(height: 24),
                  if (ev.eventName.isNotEmpty || ev.location.isNotEmpty) ...[
                    Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: MetCueTheme.purple.withValues(alpha: .05),
                        borderRadius: BorderRadius.circular(16),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            'Where you met',
                            style: TextStyle(fontWeight: FontWeight.w600),
                          ),
                          const SizedBox(height: 6),
                          if (ev.eventName.isNotEmpty) Text(ev.eventName),
                          if (ev.location.isNotEmpty)
                            Padding(
                              padding: const EdgeInsets.only(top: 4),
                              child: Text(
                                ev.location,
                                style: theme.textTheme.bodySmall,
                              ),
                            ),
                          const SizedBox(height: 4),
                          Text(
                            DateFormat('d MMM y').format(ev.date),
                            style: theme.textTheme.bodySmall,
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 20),
                  ],
                  if (ConnectionInsights.topics(conn).isNotEmpty) ...[
                    _sharedCardPanel(context, conn),
                    const SizedBox(height: 20),
                  ],
                  FollowUpCard(connection: conn),
                  ExpansionTile(
                    key: const ValueKey('connection-notes'),
                    tilePadding: EdgeInsets.zero,
                    title: const Text('Notes & activity'),
                    childrenPadding: const EdgeInsets.only(bottom: 16),
                    children: [
                      Align(
                        alignment: Alignment.centerLeft,
                        child: TextButton.icon(
                          icon: const Icon(Icons.edit_note),
                          label: const Text('Edit notes'),
                          onPressed: () => showDialog(
                            context: context,
                            builder: (_) => VoiceCaptureDialog(
                              editOnly: true,
                              connection: conn,
                              onCaptured: (updated) =>
                                  provider.updateConnection(
                                    updated,
                                    expectedVersion: conn.updatedAt,
                                  ),
                            ),
                          ),
                        ),
                      ),
                      _note(context, 'What you talked about', ev.notes),
                      _note(
                        context,
                        'Your note',
                        conn.futureSelfNote.startsWith('Note to Future Self:')
                            ? conn.futureSelfNote.substring(20).trim()
                            : conn.futureSelfNote,
                      ),
                      _note(context, 'What stood out', conn.distinctiveMemory),
                      _note(context, 'The moment', conn.microContext),
                      if (conn.vibeTags.isNotEmpty)
                        _note(
                          context,
                          'Your impression',
                          conn.vibeTags.join(' · '),
                        ),
                      if (conn.callWhen.isNotEmpty)
                        _note(
                          context,
                          'Your reminders',
                          conn.callWhen.join(' · '),
                        ),
                      if (ev.tags.isNotEmpty)
                        _note(context, 'Your tags', ev.tags.join(' · ')),
                      if (conn.rawCue.isNotEmpty ||
                          conn.cueConversation.isNotEmpty)
                        ExpansionTile(
                          tilePadding: EdgeInsets.zero,
                          title: const Text(
                            'Original conversation',
                            style: TextStyle(fontSize: 14),
                          ),
                          children: [
                            _note(context, 'Your original memory', conn.rawCue),
                            for (final turn in conn.cueConversation)
                              _note(
                                context,
                                turn['question'] ?? '',
                                turn['answer'] ?? '',
                              ),
                          ],
                        ),
                      const SizedBox(height: 12),
                      RelationshipTools(connection: conn, compact: true),
                    ],
                  ),
                  const SizedBox(height: 28),
                  const Divider(),
                  const SizedBox(height: 20),
                  OutlinedButton.icon(
                    key: const ValueKey('export-connection-contact'),
                    style: OutlinedButton.styleFrom(
                      minimumSize: const Size.fromHeight(50),
                    ),
                    icon: const Icon(Icons.person_add_alt_1_outlined, size: 20),
                    label: const Text('Save to phone contacts'),
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
                            ),
                          );
                        }
                      }
                    },
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _note(BuildContext context, String title, String value) {
    if (value.trim().isEmpty) return const SizedBox.shrink();
    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: Align(
        alignment: Alignment.centerLeft,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              title,
              style: Theme.of(context).textTheme.labelMedium?.copyWith(
                color: Theme.of(context).hintColor,
              ),
            ),
            const SizedBox(height: 5),
            SelectableText(value, style: const TextStyle(height: 1.4)),
          ],
        ),
      ),
    );
  }

  Widget _sharedCardPanel(BuildContext context, SavedConnection connection) {
    final topics = ConnectionInsights.topics(connection);
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: Theme.of(context).cardColor,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: MetCueTheme.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(
                Icons.badge_outlined,
                size: 18,
                color: MetCueTheme.purple,
              ),
              const SizedBox(width: 8),
              Text(
                'From their card',
                style: Theme.of(
                  context,
                ).textTheme.labelMedium?.copyWith(color: MetCueTheme.purple),
              ),
            ],
          ),
          const SizedBox(height: 10),
          const Text(
            'Good topics to talk about',
            style: TextStyle(fontWeight: FontWeight.w600, fontSize: 16),
          ),
          const SizedBox(height: 10),
          Wrap(
            spacing: 6,
            runSpacing: 6,
            children: [
              for (final topic in topics.take(5))
                Chip(
                  label: Text(topic),
                  backgroundColor: MetCueTheme.purple.withValues(alpha: .06),
                  side: BorderSide.none,
                ),
              if (topics.length > 5)
                ActionChip(
                  label: Text('+${topics.length - 5} more'),
                  onPressed: () => showDialog(
                    context: context,
                    builder: (ctx) => AlertDialog(
                      title: const Text('Skills & interests'),
                      content: SingleChildScrollView(
                        child: Wrap(
                          spacing: 6,
                          runSpacing: 6,
                          children: [
                            for (final topic in topics)
                              Chip(label: Text(topic)),
                          ],
                        ),
                      ),
                      actions: [
                        TextButton(
                          onPressed: () => Navigator.pop(ctx),
                          child: const Text('Done'),
                        ),
                      ],
                    ),
                  ),
                ),
            ],
          ),
        ],
      ),
    );
  }

  Future<void> _openContact(BuildContext context, Uri uri) async {
    try {
      if (await launchUrl(uri)) return;
    } catch (_) {}
    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Could not open this contact option.')),
      );
    }
  }
}
