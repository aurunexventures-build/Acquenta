import 'policy_screen.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'package:provider/provider.dart';
import '../services/auth_service.dart';
import '../theme/metcue_theme.dart';

class AuthScreen extends StatefulWidget {
  final VoidCallback? onContinueOffline;
  final bool closeOnSuccess;
  const AuthScreen({
    super.key,
    this.onContinueOffline,
    this.closeOnSuccess = false,
  });
  @override
  State<AuthScreen> createState() => _AuthScreenState();
}

class _AuthScreenState extends State<AuthScreen> {
  final _form = GlobalKey<FormState>();
  final _email = TextEditingController();
  final _password = TextEditingController();
  bool _register = false, _visible = false, _busy = false;
  String? _error, _message;
  @override
  void dispose() {
    _email.dispose();
    _password.dispose();
    super.dispose();
  }

  String _friendlyError(Object error) {
    if (error is FirebaseAuthException) {
      return switch (error.code) {
        'invalid-credential' ||
        'wrong-password' ||
        'user-not-found' => 'Check your email and password, then try again.',
        'invalid-email' => 'Enter a valid email address.',
        'email-already-in-use' =>
          'This email already has an account. Try signing in.',
        'weak-password' =>
          'Choose a stronger password with at least 8 characters.',
        'network-request-failed' =>
          'Could not connect. Check your internet and try again.',
        'too-many-requests' =>
          'Too many attempts. Please try again in a little while.',
        'popup-blocked' => 'Allow the Google sign-in window, then try again.',
        'account-exists-with-different-credential' ||
        'credential-already-in-use' =>
          'Sign in using the method already linked to this email.',
        'operation-not-allowed' || 'unauthorized-domain' =>
          'This sign-in option needs configuration. Please try another option.',
        'user-disabled' =>
          'This account is unavailable. Please contact support.',
        _ => 'Could not sign in. Please try again.',
      };
    }
    return 'Could not complete sign-in. Please try again.';
  }

  Future<void> _run(Future<void> Function(AuthService) action) async {
    if (_busy) return;
    setState(() {
      _busy = true;
      _error = null;
      _message = null;
    });
    final wasSignedIn = context.read<AuthService>().isAuthenticated;
    try {
      await action(context.read<AuthService>());
      if (mounted &&
          wasSignedIn &&
          !context.read<AuthService>().isAuthenticated) {
        Navigator.of(context).popUntil((route) => route.isFirst);
        return;
      }
      if (mounted &&
          widget.closeOnSuccess &&
          context.read<AuthService>().isAuthenticated &&
          !context.read<AuthService>().isAnonymous) {
        Navigator.pop(context);
      }
    } on FirebaseAuthException catch (e) {
      if (mounted &&
          e.code != 'popup-closed-by-user' &&
          e.code != 'cancelled-popup-request') {
        setState(() => _error = _friendlyError(e));
      }
    } catch (e) {
      if (mounted) setState(() => _error = _friendlyError(e));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  void _submit() {
    if (!_form.currentState!.validate()) return;
    FocusScope.of(context).unfocus();
    _run((auth) async {
      if (_register) {
        await auth.registerWithEmail(_email.text, _password.text);
      } else {
        await auth.signInWithEmail(_email.text, _password.text);
      }
    });
  }

  void _reset() {
    if (!RegExp(r'^[^\s@]+@[^\s@]+\.[^\s@]+$').hasMatch(_email.text.trim())) {
      setState(() => _error = 'Enter your email above to reset your password.');
      return;
    }
    _run((auth) async {
      await auth.sendPasswordReset(_email.text);
      if (mounted) {
        setState(
          () => _message =
              'If this email has an account, a reset link is on its way.',
        );
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final keyboard = MediaQuery.viewInsetsOf(context).bottom > 0;
    final auth = context.watch<AuthService>();
    final signedIn = auth.isAuthenticated && !auth.isAnonymous;
    return Scaffold(
      appBar: Navigator.canPop(context)
          ? AppBar(
              title: Text(signedIn ? 'Your account' : 'Your Acquenta account'),
            )
          : null,
      body: SafeArea(
        child: LayoutBuilder(
          builder: (context, box) {
            final compact = box.maxWidth < 600 || box.maxHeight < 740;
            final tiny = box.maxHeight < 640;
            final gap = compact ? 10.0 : 14.0;
            return ScrollConfiguration(
              behavior: ScrollConfiguration.of(
                context,
              ).copyWith(scrollbars: false, overscroll: false),
              child: SingleChildScrollView(
                physics: const ClampingScrollPhysics(),
                keyboardDismissBehavior:
                    ScrollViewKeyboardDismissBehavior.onDrag,
                padding: EdgeInsets.fromLTRB(
                  20,
                  keyboard
                      ? 8
                      : compact
                      ? 16
                      : 28,
                  20,
                  keyboard ? 8 : 16,
                ),
                child: ConstrainedBox(
                  constraints: BoxConstraints(
                    minHeight:
                        (box.maxHeight -
                                (keyboard
                                    ? 16
                                    : compact
                                    ? 32
                                    : 44))
                            .clamp(0.0, double.infinity),
                  ),
                  child: Center(
                    child: ConstrainedBox(
                      constraints: const BoxConstraints(maxWidth: 420),
                      child: AutofillGroup(
                        child: Form(
                          key: _form,
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.stretch,
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              if (!keyboard &&
                                  !tiny &&
                                  !(compact && _register)) ...[
                                Row(
                                  children: [
                                    Container(
                                      padding: EdgeInsets.all(compact ? 6 : 10),
                                      decoration: BoxDecoration(
                                        color: MetCueTheme.purple,
                                        borderRadius: BorderRadius.circular(14),
                                      ),
                                      child: ClipRRect(
                                        borderRadius: BorderRadius.circular(6),
                                        child: Image.asset(
                                          'assets/branding/acquenta-icon-v3.png',
                                          width: compact ? 22 : 26,
                                          height: compact ? 22 : 26,
                                          fit: BoxFit.cover,
                                          excludeFromSemantics: true,
                                        ),
                                      ),
                                    ),
                                    const SizedBox(width: 10),
                                    const Text(
                                      'Acquenta',
                                      style: TextStyle(
                                        fontSize: 28,
                                        fontWeight: FontWeight.w700,
                                        letterSpacing: -1.2,
                                      ),
                                    ),
                                  ],
                                ),
                                SizedBox(height: compact ? 16 : 28),
                              ],
                              Row(
                                children: [
                                  Expanded(
                                    child: Text(
                                      keyboard
                                          ? (_register
                                                ? 'Create account'
                                                : signedIn
                                                ? 'Your account'
                                                : 'Welcome back')
                                          : tiny && !signedIn
                                          ? (_register
                                                ? 'Create account'
                                                : 'Sign in')
                                          : signedIn
                                          ? 'Your people.\nYour space.'
                                          : _register
                                          ? (compact
                                                ? 'Create your wallet'
                                                : 'Make room for\ngood connections.')
                                          : 'Remember the moment.\nRecall the person.',
                                      style: TextStyle(
                                        fontSize: keyboard || tiny
                                            ? 24
                                            : compact
                                            ? 28
                                            : 34,
                                        height: 1.1,
                                        fontWeight: FontWeight.w700,
                                        letterSpacing: -1.2,
                                      ),
                                    ),
                                  ),
                                  if (tiny &&
                                      _register &&
                                      !keyboard &&
                                      !signedIn)
                                    TextButton(
                                      onPressed: _busy
                                          ? null
                                          : () => setState(() {
                                              _register = false;
                                              _error = null;
                                              _message = null;
                                            }),
                                      child: const Text('Sign in'),
                                    ),
                                ],
                              ),
                              if (!keyboard && !compact) ...[
                                const SizedBox(height: 10),
                                Text(
                                  signedIn
                                      ? auth.displayName
                                      : _register
                                      ? 'Create your personal Acquenta wallet.'
                                      : 'Find people through the details you remember.',
                                  style: const TextStyle(
                                    color: MetCueTheme.muted,
                                    fontSize: 14,
                                    height: 1.5,
                                  ),
                                ),
                              ],
                              SizedBox(
                                height: keyboard
                                    ? 12
                                    : compact
                                    ? 18
                                    : 26,
                              ),
                              if (_error != null || _message != null) ...[
                                Semantics(
                                  liveRegion: true,
                                  child: Container(
                                    padding: const EdgeInsets.all(12),
                                    decoration: BoxDecoration(
                                      color: _error != null
                                          ? const Color(0xFFFCEAE7)
                                          : const Color(0xFFE7F0EB),
                                      borderRadius: BorderRadius.circular(12),
                                    ),
                                    child: Text(
                                      _error ?? _message!,
                                      style: TextStyle(
                                        color: _error != null
                                            ? const Color(0xFF9E3931)
                                            : const Color(0xFF326C68),
                                        fontSize: 13,
                                      ),
                                    ),
                                  ),
                                ),
                                const SizedBox(height: 14),
                              ],
                              if (signedIn) ...[
                                ListTile(
                                  contentPadding: EdgeInsets.zero,
                                  leading: const CircleAvatar(
                                    backgroundColor: Color(0xFFE9E3F7),
                                    child: Icon(
                                      Icons.person_outline_rounded,
                                      color: MetCueTheme.purple,
                                    ),
                                  ),
                                  title: Text(auth.userEmail ?? 'Signed in'),
                                  subtitle: const Text('Personal wallet'),
                                ),
                                const SizedBox(height: 20),
                                OutlinedButton.icon(
                                  onPressed: _busy
                                      ? null
                                      : () => _run(
                                          (service) => service.signOut(),
                                        ),
                                  icon: const Icon(Icons.logout_rounded),
                                  label: const Text('Sign out'),
                                ),
                              ] else ...[
                                if (!keyboard) ...[
                                  SizedBox(
                                    height: 48,
                                    child: OutlinedButton.icon(
                                      onPressed: _busy
                                          ? null
                                          : () => _run((auth) async {
                                              await auth.signInWithGoogle();
                                            }),
                                      style: OutlinedButton.styleFrom(
                                        backgroundColor: Colors.white,
                                        foregroundColor: MetCueTheme.ink,
                                        side: const BorderSide(
                                          color: MetCueTheme.border,
                                        ),
                                        shape: RoundedRectangleBorder(
                                          borderRadius: BorderRadius.circular(
                                            14,
                                          ),
                                        ),
                                      ),
                                      icon: const FaIcon(
                                        FontAwesomeIcons.google,
                                        size: 19,
                                        color: MetCueTheme.purple,
                                      ),
                                      label: const Text('Continue with Google'),
                                    ),
                                  ),
                                  if (tiny)
                                    const SizedBox(height: 8)
                                  else
                                    Padding(
                                      padding: EdgeInsets.symmetric(
                                        vertical: compact ? 10 : 16,
                                      ),
                                      child: const Row(
                                        children: [
                                          Expanded(child: Divider()),
                                          Padding(
                                            padding: EdgeInsets.symmetric(
                                              horizontal: 14,
                                            ),
                                            child: Text(
                                              'or use email',
                                              style: TextStyle(
                                                color: MetCueTheme.muted,
                                                fontSize: 12,
                                              ),
                                            ),
                                          ),
                                          Expanded(child: Divider()),
                                        ],
                                      ),
                                    ),
                                ],
                                TextFormField(
                                  controller: _email,
                                  enabled: !_busy,
                                  keyboardType: TextInputType.emailAddress,
                                  textInputAction: TextInputAction.next,
                                  autofillHints: const [AutofillHints.email],
                                  autocorrect: false,
                                  scrollPadding: const EdgeInsets.only(
                                    bottom: 20,
                                  ),
                                  decoration: InputDecoration(
                                    isDense: true,
                                    contentPadding: const EdgeInsets.symmetric(
                                      horizontal: 12,
                                      vertical: 8,
                                    ),
                                    labelText: 'Email',
                                    prefixIcon: Icon(
                                      Icons.mail_outline_rounded,
                                    ),
                                  ),
                                  validator: (value) =>
                                      RegExp(
                                        r'^[^\s@]+@[^\s@]+\.[^\s@]+$',
                                      ).hasMatch((value ?? '').trim())
                                      ? null
                                      : 'Enter a valid email.',
                                ),
                                SizedBox(height: gap),
                                TextFormField(
                                  controller: _password,
                                  enabled: !_busy,
                                  obscureText: !_visible,
                                  enableSuggestions: false,
                                  autocorrect: false,
                                  textInputAction: TextInputAction.done,
                                  autofillHints: [
                                    _register
                                        ? AutofillHints.newPassword
                                        : AutofillHints.password,
                                  ],
                                  scrollPadding: const EdgeInsets.only(
                                    bottom: 20,
                                  ),
                                  onFieldSubmitted: (_) => _submit(),
                                  decoration: InputDecoration(
                                    isDense: true,
                                    contentPadding: const EdgeInsets.symmetric(
                                      horizontal: 12,
                                      vertical: 8,
                                    ),
                                    labelText: 'Password',
                                    prefixIcon: const Icon(
                                      Icons.lock_outline_rounded,
                                    ),
                                    suffixIcon: IconButton(
                                      tooltip: _visible
                                          ? 'Hide password'
                                          : 'Show password',
                                      onPressed: () =>
                                          setState(() => _visible = !_visible),
                                      icon: Icon(
                                        _visible
                                            ? Icons.visibility_off_outlined
                                            : Icons.visibility_outlined,
                                      ),
                                    ),
                                  ),
                                  validator: (value) => (value ?? '').isEmpty
                                      ? 'Enter your password.'
                                      : _register && value!.length < 8
                                      ? 'Use at least 8 characters.'
                                      : null,
                                ),
                                if (!_register)
                                  Align(
                                    alignment: Alignment.centerRight,
                                    child: TextButton(
                                      onPressed: _busy ? null : _reset,
                                      child: const Text('Forgot password?'),
                                    ),
                                  ),
                                if (_register) SizedBox(height: gap),
                                SizedBox(
                                  height: 48,
                                  child: FilledButton(
                                    onPressed: _busy ? null : _submit,
                                    child: _busy
                                        ? const SizedBox(
                                            width: 22,
                                            height: 22,
                                            child: CircularProgressIndicator(
                                              strokeWidth: 2,
                                            ),
                                          )
                                        : Text(
                                            _register
                                                ? 'Create account'
                                                : 'Sign in',
                                          ),
                                  ),
                                ),
                                if (!keyboard) ...[
                                  const SizedBox(height: 4),
                                  if (!(tiny && _register))
                                    TextButton(
                                      onPressed: _busy
                                          ? null
                                          : () => setState(() {
                                              _register = !_register;
                                              _error = null;
                                              _message = null;
                                            }),
                                      child: Text(
                                        _register
                                            ? 'Already a member? Sign in'
                                            : 'New here? Create account',
                                      ),
                                    ),
                                ],
                              ],
                              if (_register && !signedIn && !keyboard)
                                Padding(
                                  padding: const EdgeInsets.only(top: 4),
                                  child: Text(
                                    'Creating an account accepts the Terms of Use. Read our Privacy Policy.',
                                    textAlign: TextAlign.center,
                                    style: TextStyle(
                                      fontSize: 11,
                                      color: MetCueTheme.muted,
                                    ),
                                  ),
                                ),
                              Wrap(
                                alignment: WrapAlignment.center,
                                spacing: 8,
                                children: [
                                  TextButton(
                                    onPressed: () => Navigator.push(
                                      context,
                                      MaterialPageRoute(
                                        builder: (_) => const PolicyScreen(
                                          kind: PolicyKind.privacy,
                                        ),
                                      ),
                                    ),
                                    child: const Text('Privacy Policy'),
                                  ),
                                  TextButton(
                                    onPressed: () => Navigator.push(
                                      context,
                                      MaterialPageRoute(
                                        builder: (_) => const PolicyScreen(
                                          kind: PolicyKind.terms,
                                        ),
                                      ),
                                    ),
                                    child: const Text('Terms of Use'),
                                  ),
                                ],
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            );
          },
        ),
      ),
    );
  }
}
