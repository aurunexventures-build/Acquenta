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
                const SizedBox(height: 16),
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
                  'For alerts outside Acquenta, export to your calendar.',
                  style: TextStyle(fontSize: 12),
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
    final theme = Theme.of(context);
    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: theme.cardColor,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: theme.dividerColor.withValues(alpha: .45)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: theme.colorScheme.primary.withValues(alpha: .08),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(
                  Icons.event_outlined,
                  color: theme.colorScheme.primary,
                  size: 22,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Follow-up',
                      style: theme.textTheme.titleSmall?.copyWith(
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      due == null
                          ? 'Choose when to reconnect'
                          : DateFormat('d MMM y · HH:mm').format(due),
                      style: theme.textTheme.bodySmall,
                    ),
                    if (due != null)
                      Padding(
                        padding: const EdgeInsets.only(top: 4),
                        child: Text(
                          connection.followUpCompleted
                              ? 'Completed'
                              : due.isBefore(DateTime.now())
                              ? 'Overdue'
                              : 'Scheduled',
                          style: TextStyle(
                            fontSize: 12,
                            color: theme.colorScheme.primary,
                          ),
                        ),
                      ),
                  ],
                ),
              ),
              if (due != null)
                PopupMenuButton<String>(
                  tooltip: 'Follow-up options',
                  onSelected: (value) async {
                    switch (value) {
                      case 'edit':
                        await _edit(context);
                        break;
                      case 'tomorrow':
                        final now = DateTime.now();
                        await provider.setFollowUp(
                          connection.id,
                          DateTime(now.year, now.month, now.day + 1, 9),
                          connection.followUpNote,
                        );
                        break;
                      case 'calendar':
                        await _calendar(context);
                        break;
                      case 'remove':
                        await provider.removeFollowUp(connection.id);
                        break;
                    }
                  },
                  itemBuilder: (_) => [
                    const PopupMenuItem(
                      value: 'edit',
                      child: Text('Reschedule'),
                    ),
                    if (active)
                      const PopupMenuItem(
                        value: 'tomorrow',
                        child: Text('Tomorrow at 9 AM'),
                      ),
                    if (active)
                      const PopupMenuItem(
                        value: 'calendar',
                        child: Text('Export to calendar'),
                      ),
                    const PopupMenuItem(
                      value: 'remove',
                      child: Text('Remove reminder'),
                    ),
                  ],
                ),
            ],
          ),
          if (connection.followUpNote.isNotEmpty)
            Padding(
              padding: const EdgeInsets.only(top: 12),
              child: Text(
                connection.followUpNote,
                style: theme.textTheme.bodyMedium,
              ),
            ),
          const SizedBox(height: 14),
          OutlinedButton.icon(
            style: OutlinedButton.styleFrom(
              minimumSize: const Size.fromHeight(46),
            ),
            onPressed: due == null
                ? () => _edit(context)
                : connection.followUpCompleted
                ? () => provider.reopenFollowUp(connection.id)
                : () => provider.completeFollowUp(connection.id),
            icon: Icon(
              due == null
                  ? Icons.add
                  : connection.followUpCompleted
                  ? Icons.refresh
                  : Icons.check,
              size: 18,
            ),
            label: Text(
              due == null
                  ? 'Set reminder'
                  : connection.followUpCompleted
                  ? 'Reopen'
                  : 'Complete',
            ),
          ),
        ],
      ),
    );
  }
}
