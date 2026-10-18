import 'dart:convert';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import 'package:share_plus/share_plus.dart';
import '../models/saved_connection.dart';
import '../services/follow_up_calendar.dart';
import '../providers/connections_provider.dart';

class FollowUpCard extends StatelessWidget {
  final SavedConnection connection;
  const FollowUpCard({super.key, required this.connection});

  Future<void> _edit(BuildContext context) async {
    final provider = context.read<ConnectionsProvider>();
    final scopeId = connection.id;
    final walletScope = provider.walletScope;
    var note = connection.followUpNote;
    var due =
        connection.followUpAt?.toLocal() ??
        DateTime.now().add(const Duration(days: 1));
    if (!due.isAfter(DateTime.now())) {
      due = DateTime.now().add(const Duration(days: 1));
    }
    final saved = await showDialog<bool>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setState) => AlertDialog(
          title: const Text('Schedule follow-up'),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(connection.fullName),
                TextFormField(
                  initialValue: note,
                  onChanged: (value) => note = value,
                  maxLength: 1000,
                  maxLines: 3,
                  decoration: const InputDecoration(
                    labelText: 'What do you want to follow up on?',
                  ),
                ),
                TextButton.icon(
                  icon: const Icon(Icons.calendar_today_outlined),
                  label: Text(DateFormat('d MMM y, HH:mm').format(due)),
                  onPressed: () async {
                    final now = DateTime.now();
                    final day = await showDatePicker(
                      context: ctx,
                      initialDate: due,
                      firstDate: DateTime(now.year, now.month, now.day),
                      lastDate: DateTime(now.year + 10, 12, 31),
                    );
                    if (day == null || !ctx.mounted) return;
                    final time = await showTimePicker(
                      context: ctx,
                      initialTime: TimeOfDay.fromDateTime(due),
                    );
                    if (time != null && ctx.mounted) {
                      setState(
                        () => due = DateTime(
                          day.year,
                          day.month,
                          day.day,
                          time.hour,
                          time.minute,
                        ),
                      );
                    }
                  },
                ),
                const Text(
                  'Shown in Acquenta. Export to your calendar for an alert outside the app.',
                ),
                if (!due.isAfter(DateTime.now()))
                  const Text('Choose a future date and time.'),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('Cancel'),
            ),
            FilledButton(
              onPressed: due.isAfter(DateTime.now())
                  ? () => Navigator.pop(ctx, true)
                  : null,
              child: const Text('Save'),
            ),
          ],
        ),
      ),
    );
    if (saved == true &&
        context.mounted &&
        walletScope == provider.walletScope) {
      try {
        await provider.setFollowUp(scopeId, due, note);
      } catch (_) {
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text(
                'Could not save. Choose a future date and try again.',
              ),
            ),
          );
        }
      }
    }
  }

  Future<void> _calendar(BuildContext context) async {
    final content = FollowUpCalendar.generate(connection);
    try {
      final box = context.findRenderObject() as RenderBox?;
      await Share.shareXFiles(
        [
          XFile.fromData(
            Uint8List.fromList(utf8.encode(content)),
            mimeType: 'text/calendar',
            name: 'metcue-follow-up.ics',
          ),
        ],
        fileNameOverrides: ['metcue-follow-up.ics'],
        sharePositionOrigin: box == null
            ? null
            : box.localToGlobal(Offset.zero) & box.size,
      );
    } catch (_) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Calendar export unavailable on this device.'),
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final provider = context.read<ConnectionsProvider>();
    final due = connection.followUpAt?.toLocal();
    final active = due != null && !connection.followUpCompleted;
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Follow-up', style: Theme.of(context).textTheme.titleMedium),
            const SizedBox(height: 8),
            Text(
              due == null
                  ? 'Keep the conversation going.'
                  : '${connection.followUpCompleted
                        ? 'Completed'
                        : due.isBefore(DateTime.now())
                        ? 'Overdue'
                        : 'Scheduled'} · ${DateFormat('d MMM y, HH:mm').format(due)}',
            ),
            if (connection.followUpNote.isNotEmpty)
              Text(connection.followUpNote),
            Wrap(
              spacing: 8,
              children: [
                TextButton.icon(
                  onPressed: () => _edit(context),
                  icon: const Icon(Icons.edit_calendar_outlined),
                  label: Text(due == null ? 'Set reminder' : 'Reschedule'),
                ),
                if (due != null && connection.followUpCompleted)
                  TextButton(
                    onPressed: () => provider.reopenFollowUp(connection.id),
                    child: const Text('Reopen'),
                  ),
                if (active) ...[
                  TextButton(
                    onPressed: () => provider.completeFollowUp(connection.id),
                    child: const Text('Complete'),
                  ),
                  TextButton(
                    onPressed: () async {
                      final now = DateTime.now();
                      await provider.setFollowUp(
                        connection.id,
                        DateTime(now.year, now.month, now.day + 1, 9),
                        connection.followUpNote,
                      );
                    },
                    child: const Text('Snooze to tomorrow'),
                  ),
                  TextButton(
                    onPressed: () => _calendar(context),
                    child: const Text('Export to calendar'),
                  ),
                ],
                if (due != null)
                  TextButton(
                    onPressed: () => provider.removeFollowUp(connection.id),
                    child: const Text('Remove'),
                  ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
