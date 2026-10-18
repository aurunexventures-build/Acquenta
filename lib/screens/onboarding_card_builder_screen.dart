import '../theme/metcue_theme.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:uuid/uuid.dart';
import '../models/contact_card.dart';
import '../models/card_link.dart';
import '../providers/cards_provider.dart';
import '../services/storage_service.dart';
import '../services/auth_service.dart';
import '../services/photo_service.dart';
import '../services/sync_service.dart';
import '../widgets/interactive_card_view.dart';
import '../widgets/recall_wireframe.dart';
import '../widgets/photo_picker_tile.dart';
import 'account_profile_screen.dart';
import 'profile_questionnaire.dart';
import '../widgets/card_text_field.dart';
import '../widgets/skills_tags_editor.dart';
import '../widgets/social_links_editor.dart';

class OnboardingCardBuilderScreen extends StatefulWidget {
  final StorageService storageService;

  const OnboardingCardBuilderScreen({super.key, required this.storageService});

  @override
  State<OnboardingCardBuilderScreen> createState() =>
      _OnboardingCardBuilderScreenState();
}

class _OnboardingCardBuilderScreenState
    extends State<OnboardingCardBuilderScreen> {
  int _currentStep = 0;
  final _titleController = TextEditingController();
  CardCategory? _category;
  bool _primary = false;
  String _avatarUrl = '';
  bool _portraitEdited = false;

  // Controllers
  final _nameController = TextEditingController();
  final _roleController = TextEditingController();
  final _companyController = TextEditingController();
  final _headlineController = TextEditingController();
  final _emailController = TextEditingController();
  final _phoneController = TextEditingController();
  final _socials = <SocialLinkDraft>[SocialLinkDraft(type: LinkType.linkedin)];
  final _contactForm = GlobalKey<FormState>();

  final _identityForm = GlobalKey<FormState>();
  final Set<String> _selectedSkills = {};
  bool _saving = false;

  bool _prefilledIdentity = false;
  String? _formScope, _formUid;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_prefilledIdentity) return;
    _prefilledIdentity = true;
    final user = context.read<AuthService?>()?.currentUser;
    _formScope = widget.storageService.scope;
    _formUid = user?.uid;
    _emailController.text = user?.email ?? '';
    final google = context.read<AuthService?>()?.googleProfileDefaults ?? {};
    _nameController.text = [
      google['firstName'] ?? '',
      google['lastName'] ?? '',
    ].where((s) => s.isNotEmpty).join(' ');
    _phoneController.text = google['phone'] ?? '';
    if ((google['photoURL'] ?? '').isNotEmpty) {
      _importGooglePortrait(google['photoURL']!);
    }
    final profile = widget.storageService.loadAccountProfile();
    if (profile != null) {
      _nameController.text = profile.fullName;
      _roleController.text = profile.role;
      _companyController.text = profile.company;
      _headlineController.text = profile.intro;
      _phoneController.text = profile.phone;
      _emailController.text = profile.primaryEmail;
      if (profile.links.isNotEmpty) {
        for (final d in _socials) {
          d.dispose();
        }
        _socials
          ..clear()
          ..addAll(profile.links.map(SocialLinkDraft.fromLink));
      }
    }
  }

  Future<void> _importGooglePortrait(String url) async {
    final photo = await PhotoService.importGooglePortrait(url);
    if (!mounted ||
        photo == null ||
        _portraitEdited ||
        _formScope != widget.storageService.scope ||
        _formUid != context.read<AuthService?>()?.currentUser?.uid) {
      return;
    }
    setState(() => _avatarUrl = photo);
  }

  Future<void> _draftProfile() async {
    final auth = context.read<AuthService?>();
    final scope = widget.storageService.scope;
    final before =
        '${_roleController.text}|${_headlineController.text}|${_selectedSkills.join(',')}';
    final draft = await showDialog<Map<String, dynamic>>(
      context: context,
      barrierDismissible: false,
      builder: (_) => ProfileQuestionnaire(
        purpose: _titleController.text.trim(),
        initialText: [
          _roleController.text,
          _headlineController.text,
          _companyController.text,
        ].where((s) => s.trim().isNotEmpty).join('. '),
        generate: (answers) async {
          if (auth == null) throw StateError('Sign in to use AI.');
          final user = auth.currentUser?.uid;
          final result = await SyncService().request(
            '/api/v1/profile/draft',
            answers,
            auth,
          );
          if (scope != widget.storageService.scope ||
              user != auth.currentUser?.uid) {
            throw StateError('Account changed.');
          }
          return result;
        },
      ),
    );
    if (!mounted ||
        draft == null ||
        scope != widget.storageService.scope ||
        before !=
            '${_roleController.text}|${_headlineController.text}|${_selectedSkills.join(',')}') {
      return;
    }
    setState(() {
      _roleController.text = draft['role'] as String;
      _headlineController.text = draft['pitch'] as String;
      _selectedSkills
        ..clear()
        ..addAll((draft['skills'] as List).cast<String>());
    });
  }

  void _preview() {
    showDialog<void>(
      context: context,
      builder: (context) => Dialog(
        child: SingleChildScrollView(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                InteractiveCardView(card: _buildPreviewCard()),
                TextButton(
                  onPressed: () => Navigator.pop(context),
                  child: const Text('Close preview'),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  // Selected Card Material Finish
  String _selectedColor = '#18181B'; // Obsidian Matte
  final List<Map<String, dynamic>> _materialFinishes = [
    {'name': 'Obsidian', 'color': '#18181B', 'accent': Colors.white},
    {'name': 'Midnight', 'color': '#2563EB', 'accent': Color(0xFF60A5FA)},
    {'name': 'Emerald', 'color': '#0D9488', 'accent': Color(0xFF34D399)},
    {'name': 'Amethyst', 'color': '#7C3AED', 'accent': Color(0xFFA78BFA)},
    {'name': 'Amber', 'color': '#D97706', 'accent': Color(0xFFFBBF24)},
  ];

  @override
  void dispose() {
    _titleController.dispose();
    _nameController.dispose();
    _roleController.dispose();
    _companyController.dispose();
    _headlineController.dispose();
    _emailController.dispose();
    _phoneController.dispose();
    for (final d in _socials) {
      d.dispose();
    }
    super.dispose();
  }

  ContactCard _buildPreviewCard() {
    return ContactCard(
      id: 'onboarding-preview',
      title: _titleController.text.trim(),
      avatarUrl: _avatarUrl,
      category: _category ?? CardCategory.custom,
      fullName: _nameController.text.trim().isEmpty
          ? 'Your Full Name'
          : _nameController.text.trim(),
      role: _roleController.text.trim().isEmpty
          ? 'Role / Title'
          : _roleController.text.trim(),
      company: _companyController.text.trim(),
      headline: _headlineController.text.trim(),
      email: _emailController.text.trim(),
      phone: _phoneController.text.trim(),
      techStack: _selectedSkills.toList(),
      links: SocialLinkDraft.validLinks(_socials),
      themeColorHex: _selectedColor,
      isDefault: _primary,
      createdAt: DateTime.now(),
      updatedAt: DateTime.now(),
    );
  }

  void _finishOnboarding() async {
    if (_formScope != widget.storageService.scope ||
        _formUid != context.read<AuthService?>()?.currentUser?.uid) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          persist: false,
          content: Text(
            'Your account changed. Reopen card creation for this account.',
          ),
        ),
      );
      return;
    }
    if (_saving) return;
    if (_category == null ||
        [
          _titleController,
          _nameController,
          _roleController,
          _headlineController,
        ].any((c) => c.text.trim().isEmpty)) {
      setState(() => _currentStep = 0);
      return;
    }
    if (_socials.any((d) => d.validate() != null)) {
      setState(() => _currentStep = 2);
      return;
    }
    final cardsProvider = Provider.of<CardsProvider>(context, listen: false);
    if (!cardsProvider.canCreateCard) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          persist: false,
          content: Text(
            'The free plan includes 5 cards. Edit or remove a card first.',
          ),
        ),
      );
      return;
    }

    final finalCard = ContactCard(
      id: const Uuid().v4(),
      title: _titleController.text.trim(),
      avatarUrl: _avatarUrl,
      category: _category ?? CardCategory.custom,
      fullName: _nameController.text.trim(),
      role: _roleController.text.trim(),
      company: _companyController.text.trim(),
      headline: _headlineController.text.trim(),
      email: _emailController.text.trim(),
      phone: _phoneController.text.trim(),
      techStack: _selectedSkills.toList(),
      links: SocialLinkDraft.validLinks(_socials),
      themeColorHex: _selectedColor,
      isDefault: _primary,
      createdAt: DateTime.now(),
      updatedAt: DateTime.now(),
    );

    setState(() => _saving = true);
    final scope = widget.storageService.scope;
    try {
      await cardsProvider.addCard(finalCard);
      if (!mounted || scope != widget.storageService.scope) return;
      await _navigateToHome();
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Could not save your card. Please try again.'),
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  Future<void> _navigateToHome() async {
    await context.read<CardsProvider>().completeOnboarding();
    if (!mounted) return;
    if (Navigator.canPop(context)) {
      Navigator.pop(context);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: MetCueTheme.paper,
      appBar: AppBar(
        backgroundColor: MetCueTheme.paper,
        elevation: 0,
        leading: Navigator.canPop(context)
            ? IconButton(
                icon: const Icon(Icons.close_rounded, color: MetCueTheme.muted),
                onPressed: () => Navigator.pop(context),
              )
            : null,
        title: Text(
          'Create your card',
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: Theme.of(context).textTheme.titleMedium,
        ),
        centerTitle: true,
        actions: [
          IconButton(
            tooltip: 'About Me',
            icon: const Icon(Icons.manage_accounts_outlined),
            onPressed: () => Navigator.push(
              context,
              MaterialPageRoute(builder: (_) => const AccountProfileScreen()),
            ),
          ),
          IconButton(
            tooltip: 'Preview card',
            onPressed: _preview,
            icon: const Icon(Icons.visibility_outlined),
          ),
        ],
      ),
      body: SafeArea(
        child: Column(
          children: [
            // Step Indicator Header
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 6),
              child: Row(
                children: List.generate(4, (index) {
                  return Expanded(
                    child: Container(
                      height: 3,
                      margin: const EdgeInsets.symmetric(horizontal: 2),
                      decoration: BoxDecoration(
                        color: index <= _currentStep
                            ? MetCueTheme.purple
                            : MetCueTheme.border,
                        borderRadius: BorderRadius.circular(2),
                      ),
                    ),
                  );
                }),
              ),
            ),

            // Form Content for Current Step
            Expanded(
              child: SingleChildScrollView(
                keyboardDismissBehavior:
                    ScrollViewKeyboardDismissBehavior.onDrag,
                physics: const ClampingScrollPhysics(),
                padding: const EdgeInsets.all(24),
                child: _buildStepContent(),
              ),
            ),

            // Give the focused input the full space above the keyboard.
            if (MediaQuery.viewInsetsOf(context).bottom == 0)
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 20,
                  vertical: 12,
                ),
                decoration: const BoxDecoration(
                  color: MetCueTheme.paper,
                  border: Border(top: BorderSide(color: MetCueTheme.border)),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    if (_currentStep > 0)
                      OutlinedButton(
                        onPressed: _saving
                            ? null
                            : () {
                                FocusScope.of(context).unfocus();
                                setState(() => _currentStep--);
                              },
                        style: OutlinedButton.styleFrom(
                          foregroundColor: MetCueTheme.muted,
                          side: const BorderSide(color: MetCueTheme.border),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                        ),
                        child: const Text('Back'),
                      )
                    else
                      const SizedBox(width: 80),
                    ElevatedButton(
                      onPressed: _saving
                          ? null
                          : () {
                              if (_currentStep == 0 &&
                                  !_identityForm.currentState!.validate()) {
                                return;
                              }
                              if (_currentStep == 2 &&
                                  !_contactForm.currentState!.validate()) {
                                return;
                              }
                              FocusScope.of(context).unfocus();
                              if (_currentStep < 3) {
                                setState(() => _currentStep++);
                              } else {
                                _finishOnboarding();
                              }
                            },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: MetCueTheme.purple,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(
                          horizontal: 28,
                          vertical: 14,
                        ),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(14),
                        ),
                      ),
                      child: Text(
                        _saving
                            ? 'Saving…'
                            : _currentStep < 3
                            ? 'Next'
                            : 'Save card',
                        style: const TextStyle(fontWeight: FontWeight.bold),
                      ),
                    ),
                  ],
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildStepContent() {
    switch (_currentStep) {
      case 0:
        return _buildStep1Identity();
      case 1:
        return _buildStep2Skills();
      case 2:
        return _buildStep3FinishAndContact();
      default:
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              '4. REVIEW YOUR CARD',
              style: TextStyle(fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 16),
            InteractiveCardView(card: _buildPreviewCard()),
            const SizedBox(height: 16),
            const Text(
              'Check your details. Use Back to make changes, then save your card.',
            ),
          ],
        );
    }
  }

  Widget _buildStep1Identity() {
    return Form(
      key: _identityForm,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            '1. PURPOSE & IDENTITY',
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.bold,
              letterSpacing: 1.0,
              color: MetCueTheme.purple,
            ),
          ),
          const SizedBox(height: 6),
          const Text(
            'What is this card for?',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: MetCueTheme.ink,
            ),
          ),
          const SizedBox(height: 12),
          CardTextField(
            controller: _titleController,
            label: 'Card name *',
            hint: 'Work, personal, a project or an event',
            required: true,
          ),
          DropdownButtonFormField<CardCategory>(
            initialValue: _category,
            isExpanded: true,
            decoration: const InputDecoration(
              labelText: 'Card purpose *',
              border: OutlineInputBorder(),
            ),
            validator: (value) => value == null ? 'Choose a purpose.' : null,
            items: CardCategory.values
                .map(
                  (c) => DropdownMenuItem(value: c, child: Text(c.displayName)),
                )
                .toList(),
            onChanged: (value) => setState(() => _category = value),
          ),
          SwitchListTile(
            contentPadding: EdgeInsets.zero,
            title: const Text('Make this my primary card'),
            subtitle: const Text('Show this card first in my wallet.'),
            value: _primary,
            onChanged: (v) => setState(() => _primary = v),
          ),
          const SizedBox(height: 8),
          OutlinedButton.icon(
            onPressed: _draftProfile,
            icon: const SizedBox(
              width: 30,
              height: 30,
              child: RecallWireframe(thinking: false),
            ),
            label: const Text('Speak or write my profile'),
          ),
          const SizedBox(height: 12),
          _buildInputField(
            controller: _nameController,
            label: 'Full Name *',
            icon: Icons.person_outline,
            hint: 'e.g. Anit Singh',
            onChanged: (_) => setState(() {}),
          ),
          const SizedBox(height: 14),
          _buildInputField(
            controller: _roleController,
            label: 'Role / Job Title *',
            icon: Icons.badge_outlined,
            hint: 'e.g. Teacher, florist, designer or consultant',
            onChanged: (_) => setState(() {}),
          ),
          const SizedBox(height: 14),
          _buildInputField(
            controller: _headlineController,
            label: 'One-line Pitch / Headline *',
            icon: Icons.bolt_outlined,
            hint: 'e.g. Helping small businesses tell their story',
            maxLines: 2,
            onChanged: (_) => setState(() {}),
          ),
          const SizedBox(height: 12),
          ExpansionTile(
            title: const Text('Company and photo (optional)'),
            children: [
              _buildInputField(
                controller: _companyController,
                label: 'Company / Startup / Studio',
                icon: Icons.business_outlined,
                hint: 'e.g. AuruNex',
                onChanged: (_) => setState(() {}),
              ),
              const SizedBox(height: 14),
              PhotoPickerTile(
                photo: _avatarUrl,
                name: _nameController.text,
                isPortrait: true,
                onChanged: (photo) => setState(() {
                  _portraitEdited = true;
                  _avatarUrl = photo;
                }),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildStep2Skills() => Column(
    crossAxisAlignment: CrossAxisAlignment.stretch,
    children: [
      const Text(
        '2. SKILLS & TAGS',
        style: TextStyle(fontWeight: FontWeight.bold),
      ),
      const SizedBox(height: 12),
      SkillsTagsEditor(
        skills: _selectedSkills.toList(),
        role: _roleController.text,
        pitch: _headlineController.text,
        onChanged: (tags) => setState(() {
          _selectedSkills
            ..clear()
            ..addAll(tags);
        }),
      ),
    ],
  );

  Widget _buildStep3FinishAndContact() {
    return Form(
      key: _contactForm,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            '3. CARD FINISH & DETAILS',
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.bold,
              letterSpacing: 1.0,
              color: MetCueTheme.purple,
            ),
          ),
          const SizedBox(height: 6),
          const Text(
            'Choose your card colour',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: MetCueTheme.ink,
            ),
          ),
          const SizedBox(height: 16),

          // Color Material Picker
          Wrap(
            spacing: 12,
            runSpacing: 12,
            children: _materialFinishes.map((mat) {
              final isSelected = _selectedColor == mat['color'];
              return GestureDetector(
                onTap: () => setState(() => _selectedColor = mat['color']),
                child: Column(
                  children: [
                    Container(
                      width: 52,
                      height: 52,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        border: Border.all(
                          color: isSelected
                              ? MetCueTheme.purple
                              : MetCueTheme.border,
                          width: isSelected ? 3 : 1,
                        ),
                        color: mat['accent'] as Color,
                      ),
                      child: isSelected
                          ? const Icon(
                              Icons.check,
                              color: Colors.black,
                              size: 24,
                            )
                          : null,
                    ),
                    const SizedBox(height: 6),
                    Text(
                      mat['name'] as String,
                      style: TextStyle(
                        fontSize: 10,
                        fontWeight: isSelected
                            ? FontWeight.bold
                            : FontWeight.normal,
                        color: isSelected ? MetCueTheme.ink : MetCueTheme.muted,
                      ),
                    ),
                  ],
                ),
              );
            }).toList(),
          ),

          const SizedBox(height: 28),
          const Text(
            'Direct Contact Handles',
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.bold,
              color: MetCueTheme.ink,
            ),
          ),
          const SizedBox(height: 14),
          _buildInputField(
            controller: _emailController,
            label: 'Email Address',
            icon: Icons.email_outlined,
            hint: 'e.g. anit@aurunex.io',
            onChanged: (_) => setState(() {}),
          ),
          const SizedBox(height: 14),
          _buildInputField(
            controller: _phoneController,
            label: 'Mobile Phone',
            icon: Icons.phone_outlined,
            hint: 'e.g. +1 555-0192',
            onChanged: (_) => setState(() {}),
          ),
          const SizedBox(height: 14),
          SocialLinksEditor(drafts: _socials, onChanged: () => setState(() {})),
        ],
      ),
    );
  }

  Widget _buildInputField({
    required TextEditingController controller,
    required String label,
    required IconData icon,
    required String hint,
    int maxLines = 1,
    required ValueChanged<String> onChanged,
  }) {
    return CardTextField(
      controller: controller,
      label: label,
      hint: hint,
      required: label.endsWith('*'),
      maxLines: maxLines,
      voiceEnabled: controller == _headlineController,
      trailing:
          controller == _emailController &&
              (widget.storageService.loadAccountProfile()?.emails.length ?? 0) >
                  1
          ? PopupMenuButton<String>(
              tooltip: 'Choose a saved email',
              icon: const Icon(Icons.arrow_drop_down),
              onSelected: (value) =>
                  setState(() => _emailController.text = value),
              itemBuilder: (_) => widget.storageService
                  .loadAccountProfile()!
                  .emails
                  .map(
                    (email) => PopupMenuItem(value: email, child: Text(email)),
                  )
                  .toList(),
            )
          : null,
      keyboardType: label == 'Email Address'
          ? TextInputType.emailAddress
          : label == 'Mobile Phone'
          ? TextInputType.phone
          : null,
      onChanged: onChanged,
    );
  }
}
