import '../widgets/card_finish_picker.dart';
import '../widgets/card_colour_picker.dart';
import 'package:flutter/foundation.dart';
import '../services/cloud_card_conversation_voice.dart';
import '../widgets/delete_card_dialog.dart';
import '../widgets/card_purpose_row.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:uuid/uuid.dart';
import '../models/contact_card.dart';
import '../models/card_link.dart';
import '../providers/cards_provider.dart';
import '../widgets/skills_tags_editor.dart';
import '../widgets/social_links_editor.dart';
import '../widgets/card_text_field.dart';
import '../widgets/aai_card_button.dart';
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
  String _cardFinish = 'contour';
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
      _cardFinish = card.cardFinish;
      _isDefault = card.isDefault;
      _techStack = List.from(card.techStack);
      _links = List.from(card.links);
    } else {
      _category = CardCategory.professional;
      _fullName = '';
      _headline = '';
      _company = '';
      _role = '';
      _email = '';
      _phone = '';
      _location = '';
      _bio = '';
      _themeColorHex =
          context.read<CardsProvider?>()?.suggestedCardColour ?? '#2563EB';
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
    _fullName = _controller('name', _fullName).text.trim();
    _role = _controller('role', _role).text.trim();
    _headline = _controller('pitch', _headline).text.trim();
    _company = _controller('company', _company).text.trim();
    _email = _controller('email', _email).text.trim();
    _phone = _controller('phone', _phone).text.trim();
    _location = _controller('location', _location).text.trim();
    _bio = _controller('bio', _bio).text.trim();
    if (_headline.characters.length > ContactCard.pitchLimit) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Keep the one-line pitch within 120 characters.'),
        ),
      );
      return;
    }
    if ([_fullName, _role, _headline].any((v) => v.isEmpty)) {
      _formKey.currentState!.validate();
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Add your name, role and one-line pitch.'),
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
          cardFinish: _cardFinish,
          isDefault: _isDefault,
          techStack: _techStack,
          links: _links,
          updatedAt: now,
        );
        await provider.updateCard(updated);
      } else {
        final newCard = ContactCard(
          id: const Uuid().v4(),
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
          cardFinish: _cardFinish,
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
    } catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              error is FormatException
                  ? error.message
                  : 'Could not save. Your edits are still here.',
            ),
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
    final company = _controller('company', _company);
    final name = _controller('name', _fullName);
    final before =
        '$_category|${name.text}|${role.text}|${pitch.text}|${bio.text}|${company.text}';
    final service = SyncService();
    final draft = await showDialog<Map<String, dynamic>>(
      context: context,
      barrierDismissible: false,
      builder: (_) => ProfileQuestionnaire(
        understandReplies: true,
        briefConversation: true,
        voice: kIsWeb || auth?.currentUser == null
            ? null
            : CloudCardConversationVoice(
                request: (path, body) {
                  if (auth == null) throw StateError('Sign in to use voice.');
                  return service.request(path, body, auth);
                },
              ),
        profileName:
            storage.loadAccountProfile()?.fullName ??
            auth?.currentUser?.displayName ??
            '',
        applyLabel: widget.initialCard == null ? 'Create card' : 'Save card',
        initialText: [
          role.text,
          pitch.text,
          bio.text,
        ].where((s) => s.trim().isNotEmpty).join('. '),
        category: _category,
        initialName: name.text,
        initialBio: bio.text,
        initialRole: role.text,
        generate: (answers) async {
          if (auth == null) throw StateError('Sign in to use AI.');
          return await service.request('/api/v1/profile/draft', answers, auth);
        },
      ),
    ).whenComplete(service.close);
    if (!mounted ||
        draft == null ||
        scope != storage.scope ||
        before !=
            '$_category|${name.text}|${role.text}|${pitch.text}|${bio.text}|${company.text}') {
      return;
    }
    setState(() {
      name.text = draft['fullName'] as String;
      company.text = draft['company'] as String? ?? '';
      _company = company.text;
      _category = CardCategory.values.byName(draft['category'] as String);
      role.text = draft['role'] as String;
      pitch.text = draft['pitch'] as String;
      bio.text = draft['bio'] as String? ?? bio.text;
      _techStack = (draft['skills'] as List).cast<String>().toList();
    });
    if (draft['createCard'] == true) await _saveCard();
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
    maxLength: key == 'pitch' ? ContactCard.pitchLimit : null,
    showCounter: key == 'pitch',
    keyboardType: keyboard,
    onSaved: (v) => save(v?.trim() ?? ''),
  );

  Widget _section(String title, List<Widget> children) => Padding(
    padding: const EdgeInsets.only(bottom: 20),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          children: [
            Expanded(
              child: Text(
                title,
                style: Theme.of(
                  context,
                ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold),
              ),
            ),
            if (title.startsWith('1.')) AaiCardButton(onPressed: _draftProfile),
          ],
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
              const Text(
                'Card details only · changing this card does not update your account.',
              ),
              const SizedBox(height: 12),
              _section('1. About you', [
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
                  lines: 1,
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
              _section('2. Skills & tags', [
                SkillsTagsEditor(
                  skills: _techStack,
                  role: _controller('role', _role).text,
                  pitch: _controller('pitch', _headline).text,
                  onChanged: (tags) => setState(() => _techStack = tags),
                ),
              ]),
              _section('3. Contact details', [
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
                title: const Text('Photo & appearance'),
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
                  CardFinishPicker(
                    value: _cardFinish,
                    colour: _themeColorHex,
                    name: _controller('name', _fullName).text,
                    onChanged: (value) => setState(() => _cardFinish = value),
                  ),
                  CardColourPicker(
                    value: _themeColorHex,
                    onChanged: (value) =>
                        setState(() => _themeColorHex = value),
                  ),
                  const SizedBox(height: 16),
                ],
              ),
              _section('Private card settings', [
                CardPurposeRow(
                  primary: _isDefault,
                  onPrimaryChanged: (value) =>
                      setState(() => _isDefault = value),
                  purpose: DropdownButtonFormField<CardCategory>(
                    key: ValueKey(_category),
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
                            child: Text(
                              c.displayName,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                        )
                        .toList(),
                    onChanged: (v) {
                      if (v != null) setState(() => _category = v);
                    },
                  ),
                ),
              ]),
              const SizedBox(height: 20),
              FilledButton(
                onPressed: _saving ? null : _saveCard,
                child: Text(_saving ? 'Saving…' : 'Save changes'),
              ),
              if (widget.initialCard != null) ...[
                const SizedBox(height: 12),
                OutlinedButton.icon(
                  onPressed: _saving
                      ? null
                      : () async {
                          final deleted = await confirmDeleteCard(
                            context,
                            context.read<CardsProvider>(),
                            widget.initialCard!,
                          );
                          if (deleted && context.mounted) {
                            Navigator.pop(context, true);
                          }
                        },
                  icon: const Icon(Icons.delete_outline_rounded),
                  label: const Text('Delete card'),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: Theme.of(context).colorScheme.error,
                  ),
                ),
              ],
              const SizedBox(height: 24),
            ],
          ),
        ),
      ),
    ),
  );
}
