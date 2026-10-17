import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:uuid/uuid.dart';
import '../models/contact_card.dart';
import '../models/card_link.dart';
import '../providers/cards_provider.dart';
import '../services/storage_service.dart';
import '../widgets/interactive_card_view.dart';
import 'home_screen.dart';

class OnboardingCardBuilderScreen extends StatefulWidget {
  final StorageService storageService;

  const OnboardingCardBuilderScreen({super.key, required this.storageService});

  @override
  State<OnboardingCardBuilderScreen> createState() => _OnboardingCardBuilderScreenState();
}

class _OnboardingCardBuilderScreenState extends State<OnboardingCardBuilderScreen> {
  int _currentStep = 0;

  // Controllers
  final _nameController = TextEditingController(text: 'Anit Singh');
  final _roleController = TextEditingController(text: 'Mobile & Systems Architect');
  final _companyController = TextEditingController(text: 'AuruNex');
  final _headlineController = TextEditingController(text: 'Building intelligent mobile agents & offline-first cross-platform apps');
  final _emailController = TextEditingController(text: 'anit@aurunex.io');
  final _phoneController = TextEditingController(text: '+1 (555) 019-2831');
  final _linkedinController = TextEditingController(text: 'https://linkedin.com/in/anit-singh');

  // Selected tech stack
  final Set<String> _selectedSkills = {'Flutter', 'Android', 'Cloudflare', 'AI Agents'};
  final List<String> _popularSkills = [
    'Flutter', 'Android', 'Cloudflare', 'AI Agents', 'Kotlin', 'iOS',
    'TypeScript', 'Python', 'Go', 'Rust', 'SQLite', 'System Architecture',
  ];

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
    _nameController.dispose();
    _roleController.dispose();
    _companyController.dispose();
    _headlineController.dispose();
    _emailController.dispose();
    _phoneController.dispose();
    _linkedinController.dispose();
    super.dispose();
  }

  ContactCard _buildPreviewCard() {
    return ContactCard(
      id: 'onboarding-preview',
      title: 'Professional',
      category: CardCategory.professional,
      fullName: _nameController.text.trim().isEmpty ? 'Your Full Name' : _nameController.text.trim(),
      role: _roleController.text.trim().isEmpty ? 'Role / Title' : _roleController.text.trim(),
      company: _companyController.text.trim(),
      headline: _headlineController.text.trim(),
      email: _emailController.text.trim(),
      phone: _phoneController.text.trim(),
      techStack: _selectedSkills.toList(),
      links: [
        if (_linkedinController.text.trim().isNotEmpty)
          CardLink(
            id: 'link-onboard',
            title: 'LinkedIn',
            url: _linkedinController.text.trim(),
            type: LinkType.linkedin,
          ),
      ],
      themeColorHex: _selectedColor,
      isDefault: true,
      createdAt: DateTime.now(),
      updatedAt: DateTime.now(),
    );
  }

  void _finishOnboarding() async {
    final cardsProvider = Provider.of<CardsProvider>(context, listen: false);

    final finalCard = ContactCard(
      id: const Uuid().v4(),
      title: 'Professional',
      category: CardCategory.professional,
      fullName: _nameController.text.trim().isEmpty ? 'Anit Singh' : _nameController.text.trim(),
      role: _roleController.text.trim().isEmpty ? 'Engineer' : _roleController.text.trim(),
      company: _companyController.text.trim(),
      headline: _headlineController.text.trim(),
      email: _emailController.text.trim(),
      phone: _phoneController.text.trim(),
      techStack: _selectedSkills.toList(),
      links: [
        if (_linkedinController.text.trim().isNotEmpty)
          CardLink(
            id: const Uuid().v4(),
            title: 'LinkedIn',
            url: _linkedinController.text.trim(),
            type: LinkType.linkedin,
          ),
      ],
      themeColorHex: _selectedColor,
      isDefault: true,
      createdAt: DateTime.now(),
      updatedAt: DateTime.now(),
    );

    await cardsProvider.addCard(finalCard);
    await widget.storageService.saveCards(cardsProvider.cards);
    _navigateToHome();
  }

  void _navigateToHome() async {
    await widget.storageService.setOnboardingCompleted(true);
    if (!mounted) return;
    if (Navigator.canPop(context)) {
      Navigator.pop(context);
    } else {
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(builder: (_) => const HomeScreen()),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final previewCard = _buildPreviewCard();

    return Scaffold(
      backgroundColor: const Color(0xFF0D0F12),
      appBar: AppBar(
        backgroundColor: const Color(0xFF0D0F12),
        elevation: 0,
        leading: Navigator.canPop(context)
            ? IconButton(
                icon: const Icon(Icons.close_rounded, color: Colors.white70),
                onPressed: () => Navigator.pop(context),
              )
            : null,
        title: const Column(
          children: [
            Text(
              'Craft Your MetCue Card',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.white),
            ),
            Text(
              'First-time profile setup',
              style: TextStyle(fontSize: 11, color: Colors.white54),
            ),
          ],
        ),
        centerTitle: true,
        actions: [
          TextButton(
            onPressed: _navigateToHome,
            child: const Text('Skip', style: TextStyle(color: Colors.white38, fontSize: 13)),
          ),
        ],
      ),
      body: SafeArea(
        child: Column(
          children: [
            // Top Live Card Preview
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
              child: InteractiveCardView(
                card: previewCard,
                isExpanded: false,
              ),
            ),

            // Step Indicator Header
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 6),
              child: Row(
                children: List.generate(3, (index) {
                  return Expanded(
                    child: Container(
                      height: 3,
                      margin: const EdgeInsets.symmetric(horizontal: 2),
                      decoration: BoxDecoration(
                        color: index <= _currentStep ? Colors.blueAccent : Colors.white12,
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
                physics: const BouncingScrollPhysics(),
                padding: const EdgeInsets.all(24),
                child: _buildStepContent(),
              ),
            ),

            // Navigation Action Footer
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
              decoration: const BoxDecoration(
                color: Color(0xFF14171D),
                border: Border(top: BorderSide(color: Colors.white10)),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  if (_currentStep > 0)
                    OutlinedButton(
                      onPressed: () => setState(() => _currentStep--),
                      style: OutlinedButton.styleFrom(
                        foregroundColor: Colors.white70,
                        side: const BorderSide(color: Colors.white24),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      ),
                      child: const Text('Back'),
                    )
                  else
                    const SizedBox(width: 80),
                  ElevatedButton(
                    onPressed: () {
                      if (_currentStep < 2) {
                        setState(() => _currentStep++);
                      } else {
                        _finishOnboarding();
                      }
                    },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.blueAccent,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 14),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                    ),
                    child: Text(
                      _currentStep < 2 ? 'Next Step →' : 'Slide into Wallet 🚀',
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
      default:
        return _buildStep3FinishAndContact();
    }
  }

  Widget _buildStep1Identity() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          '1. YOUR IDENTITY',
          style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, letterSpacing: 1.0, color: Colors.blueAccent),
        ),
        const SizedBox(height: 6),
        const Text(
          'How should people identify you?',
          style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.white),
        ),
        const SizedBox(height: 20),
        _buildInputField(
          controller: _nameController,
          label: 'Full Name',
          icon: Icons.person_outline,
          hint: 'e.g. Anit Singh',
          onChanged: (_) => setState(() {}),
        ),
        const SizedBox(height: 14),
        _buildInputField(
          controller: _roleController,
          label: 'Role / Job Title',
          icon: Icons.badge_outlined,
          hint: 'e.g. Mobile & Systems Architect',
          onChanged: (_) => setState(() {}),
        ),
        const SizedBox(height: 14),
        _buildInputField(
          controller: _companyController,
          label: 'Company / Startup / Studio',
          icon: Icons.business_outlined,
          hint: 'e.g. AuruNex',
          onChanged: (_) => setState(() {}),
        ),
        const SizedBox(height: 14),
        _buildInputField(
          controller: _headlineController,
          label: 'One-line Pitch / Headline',
          icon: Icons.bolt_outlined,
          hint: 'e.g. Building intelligent mobile agents and offline-first apps',
          maxLines: 2,
          onChanged: (_) => setState(() {}),
        ),
      ],
    );
  }

  Widget _buildStep2Skills() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          '2. SUPERPOWERS & TECH STACK',
          style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, letterSpacing: 1.0, color: Colors.blueAccent),
        ),
        const SizedBox(height: 6),
        const Text(
          'What do you build with?',
          style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.white),
        ),
        const SizedBox(height: 8),
        const Text(
          'Select your primary technologies. These allow people to recall and search for you even if they forget your name a year later!',
          style: TextStyle(fontSize: 12, color: Colors.white60, height: 1.4),
        ),
        const SizedBox(height: 20),
        Wrap(
          spacing: 8,
          runSpacing: 10,
          children: _popularSkills.map((skill) {
            final isSelected = _selectedSkills.contains(skill);
            return FilterChip(
              label: Text(skill),
              selected: isSelected,
              showCheckmark: false,
              selectedColor: Colors.blueAccent.withValues(alpha: 0.25),
              backgroundColor: Colors.white.withValues(alpha: 0.05),
              side: BorderSide(
                color: isSelected ? Colors.blueAccent : Colors.white12,
              ),
              labelStyle: TextStyle(
                fontSize: 12,
                fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                color: isSelected ? Colors.blueAccent : Colors.white70,
              ),
              onSelected: (selected) {
                setState(() {
                  if (selected) {
                    _selectedSkills.add(skill);
                  } else {
                    _selectedSkills.remove(skill);
                  }
                });
              },
            );
          }).toList(),
        ),
      ],
    );
  }

  Widget _buildStep3FinishAndContact() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          '3. CARD FINISH & DETAILS',
          style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, letterSpacing: 1.0, color: Colors.blueAccent),
        ),
        const SizedBox(height: 6),
        const Text(
          'Choose your luxury material',
          style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.white),
        ),
        const SizedBox(height: 16),

        // Color Material Picker
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
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
                        color: isSelected ? Colors.blueAccent : Colors.white24,
                        width: isSelected ? 3 : 1,
                      ),
                      color: mat['accent'] as Color,
                    ),
                    child: isSelected
                        ? const Icon(Icons.check, color: Colors.black, size: 24)
                        : null,
                  ),
                  const SizedBox(height: 6),
                  Text(
                    mat['name'] as String,
                    style: TextStyle(
                      fontSize: 10,
                      fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                      color: isSelected ? Colors.white : Colors.white54,
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
          style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: Colors.white),
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
        _buildInputField(
          controller: _linkedinController,
          label: 'LinkedIn / Website Profile URL',
          icon: Icons.link_rounded,
          hint: 'e.g. https://linkedin.com/in/...',
          onChanged: (_) => setState(() {}),
        ),
      ],
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
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: Colors.white70),
        ),
        const SizedBox(height: 6),
        TextField(
          controller: controller,
          maxLines: maxLines,
          style: const TextStyle(color: Colors.white, fontSize: 13),
          onChanged: onChanged,
          decoration: InputDecoration(
            hintText: hint,
            hintStyle: const TextStyle(color: Colors.white30, fontSize: 12),
            prefixIcon: Icon(icon, color: Colors.white54, size: 18),
            filled: true,
            fillColor: Colors.white.withValues(alpha: 0.05),
            contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(14),
              borderSide: const BorderSide(color: Colors.white12),
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(14),
              borderSide: const BorderSide(color: Colors.white12),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(14),
              borderSide: const BorderSide(color: Colors.blueAccent),
            ),
          ),
        ),
      ],
    );
  }
}
