import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../services/auth_service.dart';
import '../services/sync_service.dart';
import '../providers/cards_provider.dart';
import '../providers/connections_provider.dart';

class DeleteAccountScreen extends StatefulWidget {
  final SyncService? syncService;
  const DeleteAccountScreen({super.key, this.syncService});
  @override
  State<DeleteAccountScreen> createState() => _DeleteAccountScreenState();
}

class _DeleteAccountScreenState extends State<DeleteAccountScreen> {
  final _password = TextEditingController();
  bool _confirmed = false;
  bool _busy = false;
  String? _error;
  @override
  void dispose() {
    _password.dispose();
    super.dispose();
  }

  Future<void> _delete() async {
    final auth = context.read<AuthService>();
    final people = context.read<ConnectionsProvider>();
    final cards = context.read<CardsProvider>();
    final storage = cards.storageService;
    final uid = auth.currentUser?.uid;
    if (uid == null || !_confirmed) return;
    setState(() {
      _busy = true;
      _error = null;
    });
    final api = widget.syncService ?? SyncService();
    try {
      final authenticated = await auth.reauthenticateForDeletion(
        _password.text,
      );
      if (!authenticated) return;
      if (uid != auth.currentUser?.uid || uid != storage.scope) {
        throw StateError('Account changed. Please reopen account settings.');
      }
      await people.suspendForAccountDeletion();
      await api.request(
        '/api/v1/account',
        {'confirmation': 'DELETE'},
        auth,
        method: 'DELETE',
      );
      if (uid != auth.currentUser?.uid) throw StateError('Account changed.');
      await storage.deleteAccountData(uid);
      PaintingBinding.instance.imageCache.clear();
      PaintingBinding.instance.imageCache.clearLiveImages();
      cards.clearForAccountSwitch();
      people.clearForAccountSwitch();
      await auth.signOut();
      if (mounted) Navigator.of(context).popUntil((route) => route.isFirst);
    } catch (error) {
      if (mounted) {
        setState(
          () => _error =
              'Deletion could not finish. ${error.toString().replaceFirst('Exception: ', '')} Retry here to finish; your sign-in remains available.',
        );
      }
    } finally {
      api.close();
      people.resumeAfterAccountDeletionAttempt();
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthService>();
    return PopScope(
      canPop: !_busy,
      child: Scaffold(
        appBar: AppBar(
          title: const Text('Delete account'),
          automaticallyImplyLeading: !_busy,
        ),
        body: SafeArea(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(24),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text(
                  auth.userEmail ?? 'Your Acquenta account',
                  style: Theme.of(context).textTheme.titleMedium,
                ),
                const SizedBox(height: 16),
                const Text(
                  'This permanently removes your Acquenta login, cards, saved connections, notes, photos, reminders and cloud search data. Published card links will stop working.',
                ),
                const SizedBox(height: 12),
                const Text(
                  'Copies you exported or shared with other people cannot be recalled. Other devices cannot sync this account again. Local data is cleared when a device detects deletion; offline copies and device backups may remain.',
                ),
                const SizedBox(height: 20),
                if (auth.usesPassword)
                  TextField(
                    controller: _password,
                    obscureText: true,
                    enabled: !_busy,
                    decoration: const InputDecoration(
                      labelText: 'Confirm your password',
                      border: OutlineInputBorder(),
                    ),
                  ),
                if (!auth.usesPassword)
                  const Text(
                    'You will confirm your sign-in with your account provider.',
                  ),
                CheckboxListTile(
                  contentPadding: EdgeInsets.zero,
                  value: _confirmed,
                  onChanged: _busy
                      ? null
                      : (value) => setState(() => _confirmed = value ?? false),
                  title: const Text('I understand this cannot be undone.'),
                ),
                if (_error != null)
                  Padding(
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    child: Text(
                      _error!,
                      style: TextStyle(
                        color: Theme.of(context).colorScheme.error,
                      ),
                    ),
                  ),
                FilledButton.icon(
                  onPressed: _confirmed && !_busy ? _delete : null,
                  style: FilledButton.styleFrom(
                    backgroundColor: Theme.of(context).colorScheme.error,
                  ),
                  icon: const Icon(Icons.delete_forever_outlined),
                  label: Text(
                    _busy ? 'Deleting account…' : 'Permanently delete account',
                  ),
                ),
                TextButton(
                  onPressed: _busy ? null : () => Navigator.pop(context),
                  child: const Text('Keep my account'),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
