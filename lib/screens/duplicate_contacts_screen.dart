import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../models/saved_connection.dart';
import '../providers/connections_provider.dart';
import '../services/duplicate_service.dart';

class DuplicateContactsScreen extends StatefulWidget {
  const DuplicateContactsScreen({super.key});
  @override
  State<DuplicateContactsScreen> createState() =>
      _DuplicateContactsScreenState();
}

class _DuplicateContactsScreenState extends State<DuplicateContactsScreen> {
  bool _busy = false;
  String _status = '';
  Future<void> _merge(SavedConnection keep, SavedConnection source) async {
    final p = context.read<ConnectionsProvider>();
    final scope = p.walletScope;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Merge these contacts?'),
        content: SingleChildScrollView(
          child: Text(
            'Keep ${keep.fullName}\n${keep.email} · ${keep.company}\n\nMerge ${source.fullName}\n${source.email} · ${source.company}\n\nExisting values stay. Empty fields are filled. Other details and conflicting reminders are archived privately in history; only one reminder stays active. The source photo is not archived. The second contact is removed after saving.',
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Merge'),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted || scope != p.walletScope) return;
    setState(() => _busy = true);
    try {
      await p.mergeConnections(keep, source);
      if (mounted) {
        setState(
          () => _status =
              'Contacts merged. Source details are in interaction history.',
        );
      }
    } catch (_) {
      if (mounted) {
        setState(
          () => _status =
              'Could not merge. A contact changed, was removed, or exceeds storage limits. Refresh and review again.',
        );
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final people = context.watch<ConnectionsProvider>().connections;
    final pairs = <(SavedConnection, SavedConnection)>[];
    for (var i = 0; i < people.length; i++) {
      for (var j = i + 1; j < people.length; j++) {
        if (DuplicateService.reason(people[i], people[j]) != null &&
            pairs.length < 100) {
          pairs.add((people[i], people[j]));
        }
      }
    }
    return Scaffold(
      appBar: AppBar(title: const Text('Review duplicates')),
      body: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          const Text(
            'Matches use contact ID, email, phone, or name plus company. Review each pair; matching details can belong to different people.',
          ),
          if (pairs.length == 100)
            const Text('Showing 100 pairs. Review more after merging.'),
          if (pairs.isEmpty)
            const Padding(
              padding: EdgeInsets.all(20),
              child: Text('No possible duplicates found.'),
            ),
          for (final pair in pairs)
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('${pair.$1.fullName} / ${pair.$2.fullName}'),
                    Text(DuplicateService.reason(pair.$1, pair.$2)!),
                    Wrap(
                      spacing: 8,
                      children: [
                        TextButton(
                          onPressed: _busy
                              ? null
                              : () => _merge(pair.$1, pair.$2),
                          child: Text('Keep ${pair.$1.fullName}'),
                        ),
                        TextButton(
                          onPressed: _busy
                              ? null
                              : () => _merge(pair.$2, pair.$1),
                          child: Text('Keep ${pair.$2.fullName}'),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          if (_status.isNotEmpty) Text(_status),
        ],
      ),
    );
  }
}
