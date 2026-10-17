import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../services/auth_service.dart';
import '../services/sync_service.dart';
import '../providers/connections_provider.dart';

class CloudSyncDialog extends StatefulWidget {
  const CloudSyncDialog({super.key});

  @override
  State<CloudSyncDialog> createState() => _CloudSyncDialogState();
}

class _CloudSyncDialogState extends State<CloudSyncDialog> {
  bool _isCheckingHealth = false;
  Map<String, dynamic>? _healthData;
  bool _isSyncing = false;
  String? _syncStatusMessage;
  bool? _syncSuccess;

  // Sign-in form controllers
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  bool _isRegisterMode = false;
  bool _isAuthLoading = false;
  String? _authError;

  @override
  void initState() {
    super.initState();
    _checkEdgeHealth();
  }

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  Future<void> _checkEdgeHealth() async {
    setState(() => _isCheckingHealth = true);
    final health = await SyncService.checkHealth();
    if (mounted) {
      setState(() {
        _isCheckingHealth = false;
        _healthData = health;
      });
    }
  }

  Future<void> _handleSync() async {
    final authService = Provider.of<AuthService>(context, listen: false);
    final connProvider = Provider.of<ConnectionsProvider>(context, listen: false);

    if (!authService.isAuthenticated) {
      setState(() {
        _syncStatusMessage = 'Please sign in or continue as Guest first.';
        _syncSuccess = false;
      });
      return;
    }

    setState(() {
      _isSyncing = true;
      _syncStatusMessage = 'Pushing to Cloudflare D1 & Vectorize...';
      _syncSuccess = null;
    });

    final result = await SyncService.syncToCloud(
      connections: connProvider.connections,
      authService: authService,
    );

    if (mounted) {
      setState(() {
        _isSyncing = false;
        _syncSuccess = result.success;
        _syncStatusMessage = result.message;
      });
    }
  }

  Future<void> _handleGuestSignIn() async {
    setState(() {
      _isAuthLoading = true;
      _authError = null;
    });
    try {
      final auth = Provider.of<AuthService>(context, listen: false);
      await auth.signInAnonymously();
    } catch (e) {
      setState(() => _authError = e.toString());
    } finally {
      if (mounted) setState(() => _isAuthLoading = false);
    }
  }

  Future<void> _handleEmailAuth() async {
    final email = _emailController.text.trim();
    final password = _passwordController.text.trim();
    if (email.isEmpty || password.isEmpty) {
      setState(() => _authError = 'Please enter both email and password.');
      return;
    }

    setState(() {
      _isAuthLoading = true;
      _authError = null;
    });

    try {
      final auth = Provider.of<AuthService>(context, listen: false);
      if (_isRegisterMode) {
        await auth.registerWithEmail(email, password);
      } else {
        await auth.signInWithEmail(email, password);
      }
    } catch (e) {
      setState(() => _authError = e.toString());
    } finally {
      if (mounted) setState(() => _isAuthLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final authService = Provider.of<AuthService>(context);
    final theme = Theme.of(context);

    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 480),
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Header
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: Colors.blue.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(14),
                    ),
                    child: const Icon(Icons.cloud_sync_rounded, color: Colors.blue, size: 28),
                  ),
                  const SizedBox(width: 14),
                  const Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Cloudflare & Firebase Sync',
                          style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                        ),
                        Text(
                          'Edge Database & Vector Retrieval',
                          style: TextStyle(fontSize: 12, color: Colors.grey),
                        ),
                      ],
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.close),
                    onPressed: () => Navigator.pop(context),
                  ),
                ],
              ),
              const SizedBox(height: 20),

              // Cloudflare Edge Status Card
              Container(
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: Colors.grey.withValues(alpha: 0.06),
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: Colors.grey.withValues(alpha: 0.2)),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Text(
                          'CLOUDFLARE EDGE WORKER',
                          style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, letterSpacing: 0.8),
                        ),
                        if (_isCheckingHealth)
                          const SizedBox(width: 14, height: 14, child: CircularProgressIndicator(strokeWidth: 2))
                        else if (_healthData != null)
                          Row(
                            children: [
                              Container(
                                width: 8,
                                height: 8,
                                decoration: const BoxDecoration(
                                  color: Colors.green,
                                  shape: BoxShape.circle,
                                ),
                              ),
                              const SizedBox(width: 6),
                              const Text('Live Online', style: TextStyle(color: Colors.green, fontSize: 11, fontWeight: FontWeight.bold)),
                            ],
                          )
                        else
                          const Text('Offline / Connecting', style: TextStyle(color: Colors.orange, fontSize: 11)),
                      ],
                    ),
                    const SizedBox(height: 8),
                    const Text(
                      'Worker: metcue-worker.quadban-cloudflare.workers.dev',
                      style: TextStyle(fontSize: 11, fontFamily: 'monospace', color: Colors.blueGrey),
                    ),
                    const Text(
                      'D1 Database: metcue-db  •  Vectorize: metcue-index',
                      style: TextStyle(fontSize: 11, fontFamily: 'monospace', color: Colors.blueGrey),
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 18),

              // Auth Status Section
              if (authService.isAuthenticated) ...[
                Container(
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    color: Colors.green.withValues(alpha: 0.08),
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: Colors.green.withValues(alpha: 0.3)),
                  ),
                  child: Row(
                    children: [
                      const Icon(Icons.check_circle_rounded, color: Colors.green, size: 28),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              authService.isAnonymous ? 'Guest User (Anonymous)' : (authService.userEmail ?? 'Signed In'),
                              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
                            ),
                            Text(
                              'UID: ${authService.currentUser?.uid.substring(0, 10)}...',
                              style: const TextStyle(fontSize: 11, color: Colors.grey),
                            ),
                          ],
                        ),
                      ),
                      TextButton(
                        onPressed: () => authService.signOut(),
                        child: const Text('Sign Out', style: TextStyle(color: Colors.red, fontSize: 12)),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 18),

                // Sync Action Button
                ElevatedButton.icon(
                  onPressed: _isSyncing ? null : _handleSync,
                  icon: _isSyncing
                      ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                      : const Icon(Icons.sync_rounded),
                  label: Text(_isSyncing ? 'Syncing...' : 'Sync Local Cards to Cloud'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.blue,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                  ),
                ),
              ] else ...[
                // Unauthenticated - Options
                const Text(
                  'Sign In to Sync & Enable Semantic Search',
                  style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
                ),
                const SizedBox(height: 8),

                if (_authError != null) ...[
                  Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: Colors.red.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Text(_authError!, style: const TextStyle(color: Colors.red, fontSize: 11)),
                  ),
                  const SizedBox(height: 8),
                ],

                // Instant Guest Button
                OutlinedButton.icon(
                  onPressed: _isAuthLoading ? null : _handleGuestSignIn,
                  icon: const Icon(Icons.bolt_rounded, color: Colors.amber),
                  label: const Text('1-Tap Instant Guest Access'),
                  style: OutlinedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                ),

                const SizedBox(height: 14),
                Row(
                  children: [
                    const Expanded(child: Divider()),
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 10),
                      child: Text('or with email', style: TextStyle(fontSize: 11, color: Colors.grey.shade600)),
                    ),
                    const Expanded(child: Divider()),
                  ],
                ),
                const SizedBox(height: 14),

                TextField(
                  controller: _emailController,
                  decoration: const InputDecoration(
                    labelText: 'Email',
                    prefixIcon: Icon(Icons.email_outlined, size: 20),
                    border: OutlineInputBorder(),
                    isDense: true,
                  ),
                ),
                const SizedBox(height: 10),
                TextField(
                  controller: _passwordController,
                  obscureText: true,
                  decoration: const InputDecoration(
                    labelText: 'Password',
                    prefixIcon: Icon(Icons.lock_outline, size: 20),
                    border: OutlineInputBorder(),
                    isDense: true,
                  ),
                ),
                const SizedBox(height: 12),

                ElevatedButton(
                  onPressed: _isAuthLoading ? null : _handleEmailAuth,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.blue,
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                  child: _isAuthLoading
                      ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                      : Text(_isRegisterMode ? 'Register New Account' : 'Sign In'),
                ),

                TextButton(
                  onPressed: () => setState(() => _isRegisterMode = !_isRegisterMode),
                  child: Text(
                    _isRegisterMode ? 'Already have an account? Sign In' : 'Need an account? Register',
                    style: const TextStyle(fontSize: 12),
                  ),
                ),
              ],

              // Sync status banner if any
              if (_syncStatusMessage != null) ...[
                const SizedBox(height: 14),
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: _syncSuccess == true
                        ? Colors.green.withValues(alpha: 0.1)
                        : _syncSuccess == false
                            ? Colors.red.withValues(alpha: 0.1)
                            : Colors.blue.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Row(
                    children: [
                      Icon(
                        _syncSuccess == true
                            ? Icons.check_circle_outline
                            : _syncSuccess == false
                                ? Icons.error_outline
                                : Icons.hourglass_top,
                        color: _syncSuccess == true
                            ? Colors.green
                            : _syncSuccess == false
                                ? Colors.red
                                : Colors.blue,
                        size: 20,
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          _syncStatusMessage!,
                          style: TextStyle(
                            fontSize: 12,
                            color: _syncSuccess == true
                                ? Colors.green.shade800
                                : _syncSuccess == false
                                    ? Colors.red.shade800
                                    : Colors.blue.shade800,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}
