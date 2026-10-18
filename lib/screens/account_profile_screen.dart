import 'follow_ups_screen.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../models/account_profile.dart';
import '../models/card_link.dart';
import '../providers/account_profile_provider.dart';
import '../services/auth_service.dart';
import '../widgets/card_text_field.dart';
import '../widgets/social_links_editor.dart';
import '../widgets/cloud_sync_dialog.dart';

class AccountProfileScreen extends StatefulWidget {
  final bool setup;
  const AccountProfileScreen({super.key, this.setup = false});
  @override
  State<AccountProfileScreen> createState() => _AccountProfileScreenState();
}

class _AccountProfileScreenState extends State<AccountProfileScreen> {
  final _form = GlobalKey<FormState>();
  final _first = TextEditingController(),
      _last = TextEditingController(),
      _phone = TextEditingController();
  final _role = TextEditingController(),
      _company = TextEditingController(),
      _intro = TextEditingController();
  final _emails = <TextEditingController>[],
      _removedEmails = <TextEditingController>[];
  final _socials = <SocialLinkDraft>[];
  bool _loaded = false, _saving = false;
  String? _loadedScope, _loadedUid;
  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_loaded) return;
    _loaded = true;
    final source = context.read<AccountProfileProvider>();
    _loadedScope = source.storage.scope;
    _loadedUid = context.read<AuthService?>()?.currentUser?.uid;
    final profile = source.profile;
    final google = context.read<AuthService?>()?.googleProfileDefaults ?? {};
    _first.text = profile?.firstName ?? google['firstName'] ?? '';
    _last.text = profile?.lastName ?? google['lastName'] ?? '';
    _phone.text = profile?.phone ?? google['phone'] ?? '';
    _role.text = profile?.role ?? '';
    _company.text = profile?.company ?? '';
    _intro.text = profile?.intro ?? '';
    final emails =
        profile?.emails ??
        [google['email'] ?? context.read<AuthService?>()?.userEmail ?? ''];
    _emails.addAll(
      (emails.isEmpty ? [''] : emails).map(
        (e) => TextEditingController(text: e),
      ),
    );
    _socials.addAll(
      profile?.links.map(SocialLinkDraft.fromLink) ??
          [SocialLinkDraft(type: LinkType.linkedin)],
    );
  }

  @override
  void dispose() {
    for (final c in [
      _first,
      _last,
      _phone,
      _role,
      _company,
      _intro,
      ..._emails,
      ..._removedEmails,
    ]) {
      c.dispose();
    }
    for (final d in _socials) {
      d.dispose();
    }
    super.dispose();
  }

  bool get _sameAccount =>
      _loadedScope == context.read<AccountProfileProvider>().storage.scope &&
      _loadedUid == context.read<AuthService?>()?.currentUser?.uid;
  Future<void> _save() async {
    if (!_sameAccount) return;
    if (_saving || !_form.currentState!.validate()) return;
    if (_socials.any((d) => d.validate() != null)) return;
    FocusScope.of(context).unfocus();
    final provider = context.read<AccountProfileProvider>();
    final scope = provider.storage.scope;
    setState(() => _saving = true);
    try {
      await provider.save(
        AccountProfile(
          firstName: _first.text.trim(),
          lastName: _last.text.trim(),
          phone: _phone.text.trim(),
          role: _role.text.trim(),
          company: _company.text.trim(),
          intro: _intro.text.trim(),
          emails: _emails
              .map((c) => c.text.trim())
              .where((s) => s.isNotEmpty)
              .toList(),
          links: SocialLinkDraft.validLinks(_socials),
          updatedAt: DateTime.now(),
        ),
      );
      if (!mounted || scope != provider.storage.scope || widget.setup) return;
      final messenger = ScaffoldMessenger.of(context);
      Navigator.pop(context);
      messenger
        ..clearSnackBars()
        ..showSnackBar(
          const SnackBar(
            persist: false,
            duration: Duration(seconds: 3),
            content: Text('About Me saved. New cards will use these details.'),
          ),
        );
    } catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            persist: false,
            content: Text(
              error is FormatException
                  ? error.message
                  : 'Could not save your profile. Your edits are still here.',
            ),
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  Widget _field(
    TextEditingController controller,
    String label, {
    bool required = false,
    int lines = 1,
    int? limit,
    TextInputType? keyboard,
  }) => CardTextField(
    controller: controller,
    label: label,
    required: required,
    maxLines: lines,
    maxLength: limit,
    showCounter: false,
    keyboardType: keyboard,
  );
  @override
  Widget build(BuildContext context) {
    context.watch<AuthService?>();
    context.watch<AccountProfileProvider>();
    if (!_sameAccount) {
      return Scaffold(
        appBar: AppBar(title: const Text('About Me')),
        body: const Center(
          child: Text(
            'Your account changed. Reopen About Me to edit this account.',
          ),
        ),
      );
    }
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.setup ? 'Set up your account' : 'About Me'),
        actions: [
          TextButton(
            onPressed: _saving ? null : _save,
            child: Text(_saving ? 'Saving…' : 'Save'),
          ),
        ],
      ),
      body: SafeArea(
        top: false,
        child: Align(
          alignment: Alignment.topCenter,
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 640),
            child: Form(
              key: _form,
              child: ListView(
                keyboardDismissBehavior:
                    ScrollViewKeyboardDismissBehavior.onDrag,
                padding: const EdgeInsets.all(20),
                children: [
                  if (!widget.setup) ...[
                    ListTile(
                      leading: const Icon(Icons.notifications_none_outlined),
                      title: const Text('Notifications & follow-ups'),
                      trailing: const Icon(Icons.chevron_right),
                      onTap: () => Navigator.of(context).push(
                        MaterialPageRoute(
                          builder: (_) => const FollowUpsScreen(),
                        ),
                      ),
                    ),
                    ListTile(
                      leading: const Icon(Icons.cloud_sync_outlined),
                      title: const Text('Sync, account & privacy'),
                      trailing: const Icon(Icons.chevron_right),
                      onTap: () => showDialog(
                        context: context,
                        builder: (_) => const CloudSyncDialog(),
                      ),
                    ),
                    const Divider(),
                    const SizedBox(height: 12),
                  ],
                  Text(
                    widget.setup
                        ? 'Start with your basic details'
                        : 'Your details, ready for every card',
                    style: Theme.of(context).textTheme.titleLarge,
                  ),
                  const SizedBox(height: 8),
                  const Text(
                    'New cards start with a copy of these details. You can change the information on each card.',
                  ),
                  const SizedBox(height: 20),
                  if (context.read<AccountProfileProvider>().profile == null &&
                      (context
                              .read<AuthService?>()
                              ?.googleProfileDefaults
                              .isNotEmpty ??
                          false))
                    const Padding(
                      padding: EdgeInsets.only(bottom: 16),
                      child: Text(
                        'We filled in available Google details. Check or change them before saving.',
                      ),
                    ),
                  _field(_first, 'First name *', required: true, limit: 100),
                  _field(_last, 'Last name (optional)', limit: 100),
                  _field(
                    _phone,
                    'Phone number (optional)',
                    limit: 100,
                    keyboard: TextInputType.phone,
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Email addresses',
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                  const Text(
                    'The first address is your default for new cards. Contact emails do not change your sign-in email.',
                  ),
                  for (final entry in _emails.asMap().entries)
                    Padding(
                      key: ValueKey(entry.value),
                      padding: const EdgeInsets.only(top: 12),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Expanded(
                            child: TextFormField(
                              controller: entry.value,
                              keyboardType: TextInputType.emailAddress,
                              autocorrect: false,
                              enableSuggestions: false,
                              maxLength: 320,
                              scrollPadding: const EdgeInsets.only(
                                top: 32,
                                bottom: 120,
                              ),
                              decoration: InputDecoration(
                                labelText: entry.key == 0
                                    ? 'Primary contact email'
                                    : 'Another contact email',
                                counterText: '',
                                border: const OutlineInputBorder(),
                              ),
                              validator: (value) {
                                final email = value?.trim() ?? '';
                                if (email.isEmpty) return null;
                                if (!RegExp(
                                  r'^[^\s@]+@[^\s@]+\.[^\s@]+$',
                                ).hasMatch(email)) {
                                  return 'Enter a valid email address.';
                                }
                                if (_emails.any(
                                  (c) =>
                                      c != entry.value &&
                                      c.text.trim().toLowerCase() ==
                                          email.toLowerCase(),
                                )) {
                                  return 'This email is already listed.';
                                }
                                return null;
                              },
                            ),
                          ),
                          if (entry.key > 0)
                            IconButton(
                              tooltip: 'Use as primary email',
                              icon: const Icon(Icons.star_outline),
                              onPressed: () {
                                FocusScope.of(context).unfocus();
                                setState(() {
                                  _emails.remove(entry.value);
                                  _emails.insert(0, entry.value);
                                });
                              },
                            ),
                          if (_emails.length > 1)
                            IconButton(
                              tooltip: 'Remove email',
                              icon: const Icon(Icons.close),
                              onPressed: () => setState(() {
                                _emails.remove(entry.value);
                                _removedEmails.add(entry.value);
                              }),
                            ),
                        ],
                      ),
                    ),
                  if (_emails.length < 5)
                    Align(
                      alignment: Alignment.centerLeft,
                      child: TextButton.icon(
                        onPressed: () => setState(
                          () => _emails.add(TextEditingController()),
                        ),
                        icon: const Icon(Icons.add),
                        label: const Text('Add another email'),
                      ),
                    ),
                  const SizedBox(height: 20),
                  SocialLinksEditor(
                    drafts: _socials,
                    onChanged: () => setState(() {}),
                  ),
                  const SizedBox(height: 20),
                  ExpansionTile(
                    title: const Text('Work details (optional)'),
                    children: [
                      _field(_role, 'Role / job title', limit: 200),
                      _field(_company, 'Company', limit: 200),
                      _field(
                        _intro,
                        'Short introduction',
                        lines: 2,
                        limit: 300,
                      ),
                    ],
                  ),
                  const SizedBox(height: 20),
                  FilledButton(
                    onPressed: _saving ? null : _save,
                    child: Text(
                      _saving
                          ? 'Saving…'
                          : widget.setup
                          ? 'Save and create my card'
                          : 'Save About Me',
                    ),
                  ),
                  if (context.watch<AccountProfileProvider>().status
                      case final String status)
                    Padding(
                      padding: const EdgeInsets.only(top: 8),
                      child: Text(
                        status,
                        style: Theme.of(context).textTheme.bodySmall,
                      ),
                    ),
                  TextButton(
                    onPressed: () => showDialog(
                      context: context,
                      builder: (_) => const CloudSyncDialog(),
                    ),
                    child: const Text('Account & privacy'),
                  ),
                  const SizedBox(height: 24),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
