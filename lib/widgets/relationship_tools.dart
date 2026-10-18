import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import '../models/saved_connection.dart';
import '../providers/connections_provider.dart';
import '../services/reconnect_service.dart';

class RelationshipTools extends StatelessWidget {
  final SavedConnection connection;
  const RelationshipTools({super.key, required this.connection});

  Future<void> _note(BuildContext context) async {
    final provider = context.read<ConnectionsProvider>();
    final scope = provider.walletScope;
    var note = '';
    var saving = false;
    String? error;
    await showDialog<void>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, refresh) => AlertDialog(
          title: const Text('Log an interaction'),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextFormField(
                  maxLength: 2000,
                  maxLines: 5,
                  onChanged: (v) => note = v,
                  decoration: const InputDecoration(
                    labelText: 'What happened?',
                    hintText: 'A call, coffee, introduction or update…',
                  ),
                ),
                if (error != null) Text(error!),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: saving ? null : () => Navigator.pop(ctx),
              child: const Text('Cancel'),
            ),
            FilledButton(
              onPressed: saving
                  ? null
                  : () async {
                      if (scope != provider.walletScope) {
                        Navigator.pop(ctx);
                        return;
                      }
                      refresh(() {
                        saving = true;
                        error = null;
                      });
                      try {
                        await provider.addInteraction(connection.id, note);
                        if (ctx.mounted) Navigator.pop(ctx);
                      } catch (_) {
                        if (ctx.mounted) {
                          refresh(() {
                            saving = false;
                            error = note.trim().isEmpty
                                ? 'Write a short note first.'
                                : 'Could not save. Your note is still here; history may be full.';
                          });
                        }
                      }
                    },
              child: Text(saving ? 'Saving…' : 'Save note'),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _draft(BuildContext context) async {
    var draft = ReconnectService.draft(connection);
    await showDialog<void>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Reconnect'),
        content: SizedBox(
          width: 440,
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('Conversation ideas from your saved notes'),
                for (final prompt in ReconnectService.prompts(connection))
                  Padding(
                    padding: const EdgeInsets.only(top: 8),
                    child: Text(prompt),
                  ),
                const SizedBox(height: 16),
                TextFormField(
                  initialValue: draft,
                  maxLines: 6,
                  maxLength: 4000,
                  onChanged: (v) => draft = v,
                  decoration: const InputDecoration(
                    labelText: 'Edit your message',
                  ),
                ),
              ],
            ),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Close'),
          ),
          FilledButton(
            onPressed: () async {
              await Clipboard.setData(ClipboardData(text: draft));
              if (ctx.mounted) {
                Navigator.pop(ctx);
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text('Message copied. Review it before sending.'),
                  ),
                );
              }
            },
            child: const Text('Copy message'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final entries = [...connection.interactions]
      ..sort((a, b) => b.at.compareTo(a.at));
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Wrap(
          spacing: 8,
          children: [
            OutlinedButton.icon(
              onPressed: () => _note(context),
              icon: const Icon(Icons.note_add_outlined),
              label: const Text('Log interaction'),
            ),
            OutlinedButton.icon(
              onPressed: () => _draft(context),
              icon: const Icon(Icons.chat_bubble_outline),
              label: const Text('Reconnect'),
            ),
          ],
        ),
        const SizedBox(height: 12),
        Card(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Interaction history',
                  style: Theme.of(context).textTheme.titleMedium,
                ),
                Text(
                  'Connected ${DateFormat('d MMM y').format(connection.savedAt.toLocal())}',
                ),
                if (entries.isEmpty)
                  const Padding(
                    padding: EdgeInsets.only(top: 8),
                    child: Text(
                      'Log a conversation to remember where you left off.',
                    ),
                  ),
                for (final entry in entries)
                  ExpansionTile(
                    tilePadding: EdgeInsets.zero,
                    title: Text(
                      entry.kind == 'cue'
                          ? 'Previous memory'
                          : 'Conversation note',
                    ),
                    subtitle: Text(
                      DateFormat('d MMM y, HH:mm').format(entry.at.toLocal()),
                    ),
                    children: [
                      Align(
                        alignment: Alignment.centerLeft,
                        child: Padding(
                          padding: const EdgeInsets.only(bottom: 12),
                          child: SelectableText(entry.text),
                        ),
                      ),
                    ],
                  ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}
