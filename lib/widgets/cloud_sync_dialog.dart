import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../screens/auth_screen.dart';
import '../screens/delete_account_screen.dart';
import '../screens/policy_screen.dart';
import '../services/auth_service.dart';
import '../providers/connections_provider.dart';
import '../providers/cards_provider.dart';
import '../providers/account_profile_provider.dart';

class CloudSyncDialog extends StatefulWidget {
  const CloudSyncDialog({super.key});
  @override
  State<CloudSyncDialog> createState() => _CloudSyncDialogState();
}

class _CloudSyncDialogState extends State<CloudSyncDialog> {
  bool _busy = false;
  String? _status;
  Future<void> _sync() async {
    setState(() => _busy = true);
    try {
      await context.read<AccountProfileProvider?>()?.sync();
      if (!mounted) return;
      final result = await context.read<ConnectionsProvider>().syncWallet(
        context.read<AuthService>(),
        context.read<CardsProvider>(),
      );
      if (mounted) setState(() => _status = result.message);
    } catch (_) {
      if (mounted) {
        setState(
          () =>
              _status = 'Could not sync. Your local wallet is still available.',
        );
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthService>();
    return Dialog(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 420),
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                children: [
                  const Expanded(
                    child: Text(
                      'Account & privacy',
                      style: TextStyle(
                        fontSize: 22,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                  IconButton(
                    tooltip: 'Close',
                    onPressed: () => Navigator.pop(context),
                    icon: const Icon(Icons.close_rounded),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              Icon(
                auth.isAuthenticated
                    ? Icons.cloud_done_outlined
                    : Icons.cloud_outlined,
                size: 42,
                color: Theme.of(context).colorScheme.primary,
              ),
              const SizedBox(height: 16),
              Text(
                auth.isAuthenticated
                    ? auth.userEmail ?? 'Guest account'
                    : 'Keep your connections with you.',
                textAlign: TextAlign.center,
                style: const TextStyle(fontWeight: FontWeight.w600),
              ),
              const SizedBox(height: 8),
              Text(
                auth.isAuthenticated
                    ? 'Sync your cards and memories across devices.'
                    : 'Sign in to sync your wallet and use AI recall.',
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 20),
              if (_status != null)
                Padding(
                  padding: const EdgeInsets.only(bottom: 16),
                  child: Text(_status!, style: const TextStyle(fontSize: 13)),
                ),
              if (auth.isAuthenticated)
                FilledButton.icon(
                  onPressed: _busy ? null : _sync,
                  icon: const Icon(Icons.sync_rounded),
                  label: Text(_busy ? 'Syncing…' : 'Sync now'),
                ),
              TextButton(
                onPressed: _busy
                    ? null
                    : () => Navigator.of(context).push(
                        MaterialPageRoute(
                          builder: (_) =>
                              const PolicyScreen(kind: PolicyKind.privacy),
                        ),
                      ),
                child: const Text('Privacy Policy'),
              ),
              if (auth.isAuthenticated) ...[
                TextButton(
                  onPressed: _busy
                      ? null
                      : () async {
                          await auth.signOut();
                          if (context.mounted) {
                            Navigator.of(context).popUntil((r) => r.isFirst);
                          }
                        },
                  child: const Text('Sign out'),
                ),
                TextButton.icon(
                  onPressed: _busy
                      ? null
                      : () => Navigator.of(context).push(
                          MaterialPageRoute(
                            builder: (_) => const DeleteAccountScreen(),
                          ),
                        ),
                  icon: const Icon(Icons.delete_forever_outlined),
                  label: const Text('Delete account'),
                  style: TextButton.styleFrom(
                    foregroundColor: Theme.of(context).colorScheme.error,
                  ),
                ),
              ],
              if (!auth.isAuthenticated || auth.isAnonymous)
                FilledButton(
                  onPressed: () {
                    final navigator = Navigator.of(context);
                    navigator.pop();
                    navigator.push(
                      MaterialPageRoute(
                        builder: (_) => const AuthScreen(closeOnSuccess: true),
                      ),
                    );
                  },
                  child: Text(
                    auth.isAnonymous ? 'Create your account' : 'Sign in',
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}
