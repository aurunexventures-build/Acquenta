import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:uuid/uuid.dart';
import '../models/contact_card.dart';
import '../models/card_link.dart';
import '../providers/cards_provider.dart';
import '../widgets/skills_tags_editor.dart';
import '../widgets/social_links_editor.dart';
import '../widgets/card_text_field.dart';
import '../services/auth_service.dart';
import '../services/sync_service.dart';
import 'profile_questionnaire.dart';
import '../widgets/photo_picker_tile.dart';

class CardEditorScreen extends StatefulWidget {
  final ContactCard? initialCard;

  const CardEditorScreen({super.key, this.initialCard});

  @override
  State<CardEditorScreen> createState() => _CardEditorScreenState();
}

class _CardEditorScreenState extends State<CardEditorScreen> {
  final _formKey = GlobalKey<FormState>();
  bool _saving = false;
  final _fields = <String, TextEditingController>{};

  String _avatarUrl = '';
  late String _title;
  late CardCategory _category;
  late String _fullName;
  late String _headline;
  late String _company;
  late String _role;
  late String _email;
  late String _phone;
  late String _location;
  late String _bio;
  late String _themeColorHex;
  late bool _isDefault;
  late List<String> _techStack;
  late List<CardLink> _links;
  final _socials = <SocialLinkDraft>[];

  static const List<String> _colorPalette = [
    '#2563EB', // Blue
    '#0D9488', // Teal
    '#8B5CF6', // Purple
    '#EA580C', // Orange
    '#E11D48', // Rose
    '#16A34A', // Green
    '#0F172A', // Slate / Dark
  ];

  @override
  void initState() {
    super.initState();
    final card = widget.initialCard;
    if (card != null) {
      _avatarUrl = card.avatarUrl;
      _title = card.title;
      _category = card.category;
      _fullName = card.fullName;
      _headline = card.headline;
      _company = card.company;
      _role = card.role;
      _email = card.email;
      _phone = card.phone;
      _location = card.location;
      _bio = card.bio;
      _themeColorHex = card.themeColorHex;
      _isDefault = card.isDefault;
      _techStack = List.from(card.techStack);
      _links = List.from(card.links);
    } else {
      _title = 'Professional';
      _category = CardCategory.professional;
      _fullName = '';
      _headline = '';
      _company = '';
      _role = '';
      _email = '';
      _phone = '';
      _location = '';
      _bio = '';
      _themeColorHex = '#2563EB';
      _isDefault = false;
      _techStack = [];
      _links = [];
    }
    _socials.addAll(_links.map(SocialLinkDraft.fromLink));
  }

  TextEditingController _controller(String key, String value) =>
      _fields.putIfAbsent(key, () => TextEditingController(text: value));

  @override
  void dispose() {
    for (final field in _fields.values) {
      field.dispose();
    }
    for (final d in _socials) {
      d.dispose();
    }
    super.dispose();
  }

  Future<void> _saveCard() async {
    if (_saving) return;
    if (_socials.any((d) => d.validate() != null)) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Check your social usernames and website addresses.'),
        ),
      );
      return;
    }
    _links = SocialLinkDraft.validLinks(_socials);
    _title = _controller('title', _title).text.trim();
    _fullName = _controller('name', _fullName).text.trim();
    _role = _controller('role', _role).text.trim();
    _headline = _controller('pitch', _headline).text.trim();
    _company = _controller('company', _company).text.trim();
    _email = _controller('email', _email).text.trim();
    _phone = _controller('phone', _phone).text.trim();
    _location = _controller('location', _location).text.trim();
    _bio = _controller('bio', _bio).text.trim();
    if ([_title, _fullName, _role, _headline].any((v) => v.isEmpty)) {
      _formKey.currentState!.validate();
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Add a card name, your name, role and one-line pitch.'),
        ),
      );
      return;
    }
    if (!_formKey.currentState!.validate()) return;
    _formKey.currentState!.save();

    final provider = Provider.of<CardsProvider>(context, listen: false);
    final now = DateTime.now();
    final scope = provider.storageService.scope;
    setState(() => _saving = true);
    try {
      if (widget.initialCard != null) {
        final updated = widget.initialCard!.copyWith(
          title: _title,
          avatarUrl: _avatarUrl,
          category: _category,
          fullName: _fullName,
          headline: _headline,
          company: _company,
          role: _role,
          email: _email,
          phone: _phone,
          location: _location,
          bio: _bio,
          themeColorHex: _themeColorHex,
          isDefault: _isDefault,
          techStack: _techStack,
          links: _links,
          updatedAt: now,
        );
        await provider.updateCard(updated);
      } else {
        final newCard = ContactCard(
          id: const Uuid().v4(),
          title: _title,
          avatarUrl: _avatarUrl,
          category: _category,
          fullName: _fullName,
          headline: _headline,
          company: _company,
          role: _role,
          email: _email,
          phone: _phone,
          location: _location,
          bio: _bio,
          themeColorHex: _themeColorHex,
          isDefault: _isDefault,
          techStack: _techStack,
          links: _links,
          createdAt: now,
          updatedAt: now,
        );
        await provider.addCard(newCard);
      }

      if (mounted && scope == provider.storageService.scope) {
        Navigator.pop(context);
      }
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Could not save. Your edits are still here.'),
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  Future<void> _draftProfile() async {
    final auth = context.read<AuthService?>();
    final storage = context.read<CardsProvider>().storageService;
    final scope = storage.scope;
    final role = _controller('role', _role),
        pitch = _controller('pitch', _headline);
    final bio = _controller('bio', _bio);
    final before = '${role.text}|${pitch.text}|${bio.text}';
    final draft = await showDialog<Map<String, dynamic>>(
      context: context,
      barrierDismissible: false,
      builder: (_) => ProfileQuestionnaire(
        initialText: [
          role.text,
          pitch.text,
          bio.text,
        ].where((s) => s.trim().isNotEmpty).join('. '),
        purpose: _controller('title', _title).text,
        generate: (answers) async {
          if (auth == null) throw StateError('Sign in to use AI.');
          final service = SyncService();
          try {
            return await service.request(
              '/api/v1/profile/draft',
              answers,
              auth,
            );
          } finally {
            service.close();
          }
        },
      ),
    );
    if (!mounted ||
        draft == null ||
        scope != storage.scope ||
        before != '${role.text}|${pitch.text}|${bio.text}') {
      return;
    }
    setState(() {
      role.text = draft['role'] as String;
      pitch.text = draft['pitch'] as String;
      _techStack = (draft['skills'] as List).cast<String>().toList();
    });
  }

  Widget _field(
    String key,
    String label,
    String value,
    ValueChanged<String> save, {
    String hint = '',
    bool required = false,
    int lines = 1,
    TextInputType? keyboard,
  }) => CardTextField(
    key: ValueKey('edit-$key'),
    controller: _controller(key, value),
    label: label,
    hint: hint,
    required: required,
    voiceEnabled: key == 'pitch',
    maxLines: lines,
    keyboardType: keyboard,
    onSaved: (v) => save(v?.trim() ?? ''),
  );

  Widget _section(String title, List<Widget> children) => Padding(
    padding: const EdgeInsets.only(bottom: 20),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(
          title,
          style: Theme.of(
            context,
          ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 8),
        ...children,
      ],
    ),
  );

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(
      title: Text(widget.initialCard == null ? 'Create card' : 'Edit card'),
      actions: [
        TextButton(
          onPressed: _saving ? null : _saveCard,
          child: Text(_saving ? 'Saving…' : 'Save'),
        ),
      ],
    ),
    body: Form(
      key: _formKey,
      child: Align(
        alignment: Alignment.topCenter,
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 640),
          child: ListView(
            keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
            padding: const EdgeInsets.all(20),
            children: [
              _section('1. What is this card for?', [
                _field(
                  'title',
                  'Card name *',
                  _title,
                  (v) => _title = v,
                  hint: 'Work, personal, a project or an event',
                  required: true,
                ),
                DropdownButtonFormField<CardCategory>(
                  initialValue: _category,
                  isExpanded: true,
                  decoration: const InputDecoration(
                    labelText: 'Card purpose',
                    border: OutlineInputBorder(),
                  ),
                  items: CardCategory.values
                      .map(
                        (c) => DropdownMenuItem(
                          value: c,
                          child: Text(c.displayName),
                        ),
                      )
                      .toList(),
                  onChanged: (v) {
                    if (v != null) setState(() => _category = v);
                  },
                ),
                const SizedBox(height: 8),
                SwitchListTile(
                  contentPadding: EdgeInsets.zero,
                  title: const Text('Make this my primary card'),
                  subtitle: const Text('Show this card first in my wallet.'),
                  value: _isDefault,
                  onChanged: (v) => setState(() => _isDefault = v),
                ),
              ]),
              _section('2. About you', [
                OutlinedButton.icon(
                  onPressed: _draftProfile,
                  icon: const Icon(Icons.auto_awesome_outlined),
                  label: const Text('Describe yourself once · draft with AI'),
                ),
                _field(
                  'name',
                  'Full Name *',
                  _fullName,
                  (v) => _fullName = v,
                  required: true,
                ),
                _field(
                  'role',
                  'Role / Job Title *',
                  _role,
                  (v) => _role = v,
                  required: true,
                  hint: 'Teacher, designer, consultant…',
                ),
                _field(
                  'company',
                  'Company / Studio',
                  _company,
                  (v) => _company = v,
                ),
                _field(
                  'pitch',
                  'One-line pitch *',
                  _headline,
                  (v) => _headline = v,
                  required: true,
                  lines: 2,
                  hint: 'What you do and who you help',
                ),
                _field(
                  'bio',
                  'More about you (optional)',
                  _bio,
                  (v) => _bio = v,
                  lines: 3,
                ),
              ]),
              _section('3. Skills & tags', [
                SkillsTagsEditor(
                  skills: _techStack,
                  role: _controller('role', _role).text,
                  pitch: _controller('pitch', _headline).text,
                  onChanged: (tags) => setState(() => _techStack = tags),
                ),
              ]),
              _section('4. Contact details', [
                _field(
                  'email',
                  'Email',
                  _email,
                  (v) => _email = v,
                  keyboard: TextInputType.emailAddress,
                ),
                _field(
                  'phone',
                  'Phone',
                  _phone,
                  (v) => _phone = v,
                  keyboard: TextInputType.phone,
                ),
                _field(
                  'location',
                  'Location / City',
                  _location,
                  (v) => _location = v,
                ),
              ]),
              _section('Links & socials', [
                SocialLinksEditor(
                  drafts: _socials,
                  onChanged: () => setState(() {}),
                ),
              ]),
              ExpansionTile(
                title: const Text('Photo & card colour'),
                children: [
                  PhotoPickerTile(
                    photo: _avatarUrl,
                    name: _controller('name', _fullName).text,
                    isPortrait: true,
                    onChanged: (v) => setState(() => _avatarUrl = v),
                  ),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: _colorPalette
                        .map(
                          (hex) => Semantics(
                            label: 'Card colour $hex',
                            selected: _themeColorHex == hex,
                            child: IconButton(
                              tooltip: 'Card colour $hex',
                              style: IconButton.styleFrom(
                                backgroundColor: Color(
                                  int.parse('FF${hex.substring(1)}', radix: 16),
                                ),
                              ),
                              onPressed: () =>
                                  setState(() => _themeColorHex = hex),
                              icon: Icon(
                                _themeColorHex == hex
                                    ? Icons.check
                                    : Icons.circle,
                                color: Colors.white,
                              ),
                            ),
                          ),
                        )
                        .toList(),
                  ),
                  const SizedBox(height: 16),
                ],
              ),
              const SizedBox(height: 20),
              FilledButton(
                onPressed: _saving ? null : _saveCard,
                child: Text(_saving ? 'Saving…' : 'Save changes'),
              ),
              const SizedBox(height: 24),
            ],
          ),
        ),
      ),
    ),
  );
}
