import 'dart:async';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/connections_provider.dart';
import '../widgets/follow_up_card.dart';
import 'connection_detail_screen.dart';

class FollowUpsScreen extends StatefulWidget {
  const FollowUpsScreen({super.key});
  @override
  State<FollowUpsScreen> createState() => _FollowUpsScreenState();
}

class _FollowUpsScreenState extends State<FollowUpsScreen> {
  Timer? _clock;
  String _filter = 'All';
  @override
  void initState() {
    super.initState();
    _clock = Timer.periodic(const Duration(minutes: 1), (_) {
      if (mounted) setState(() {});
    });
  }

  @override
  void dispose() {
    _clock?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<ConnectionsProvider>();
    final now = DateTime.now();
    final tomorrow = DateTime(now.year, now.month, now.day + 1);
    final items =
        (_filter == 'Completed'
                ? provider.completedFollowUps
                : provider.pendingFollowUps)
            .where((c) {
              final due = c.followUpAt!.toLocal();
              return switch (_filter) {
                'Overdue' => due.isBefore(now),
                'Today' =>
                  !due.isBefore(DateTime(now.year, now.month, now.day)) &&
                      due.isBefore(tomorrow),
                'Upcoming' => !due.isBefore(tomorrow),
                _ => true,
              };
            })
            .toList();
    return Scaffold(
      appBar: AppBar(title: const Text('Follow-ups')),
      body: Column(
        children: [
          if (provider.reminders.supported)
            SwitchListTile(
              title: const Text('Device reminder alerts'),
              subtitle: Text(
                provider.notificationStatus.isEmpty
                    ? 'Optional alerts on this device. No contact details appear in notifications.'
                    : provider.notificationStatus,
              ),
              value: provider.notificationsEnabled,
              onChanged: provider.enableNotifications,
            ),
          Padding(
            padding: const EdgeInsets.all(12),
            child: Wrap(
              spacing: 8,
              children: [
                for (final filter in [
                  'All',
                  'Overdue',
                  'Today',
                  'Upcoming',
                  'Completed',
                ])
                  ChoiceChip(
                    label: Text(filter),
                    selected: _filter == filter,
                    onSelected: (_) => setState(() => _filter = filter),
                  ),
              ],
            ),
          ),
          Expanded(
            child: provider.isLoading
                ? const Center(child: CircularProgressIndicator())
                : items.isEmpty
                ? Center(
                    child: Padding(
                      padding: const EdgeInsets.all(24),
                      child: Text(
                        _filter == 'All'
                            ? 'No pending follow-ups. Open a connection and set a reminder.'
                            : 'No follow-ups in this view.',
                      ),
                    ),
                  )
                : ListView(
                    padding: const EdgeInsets.all(16),
                    children: [
                      const Text(
                        'Calendar exports are separate copies; changes here do not update your calendar.',
                      ),
                      for (final person in items)
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            TextButton(
                              onPressed: () => Navigator.push(
                                context,
                                MaterialPageRoute(
                                  builder: (_) => ConnectionDetailScreen(
                                    connectionId: person.id,
                                  ),
                                ),
                              ),
                              child: Text(person.fullName),
                            ),
                            FollowUpCard(connection: person),
                          ],
                        ),
                    ],
                  ),
          ),
        ],
      ),
    );
  }
}
