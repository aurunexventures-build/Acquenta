import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/contact_card.dart';
import '../models/card_link.dart';
import '../models/saved_connection.dart';
import '../models/event_context.dart';

class StorageService {
  static const String _cardsKey = 'user_contact_cards';
  static const String _connectionsKey = 'saved_connections';
  static const String _initializedKey = 'has_initialized_seed_data_v5';
  static const String _onboardingKey = 'has_completed_onboarding';

  final SharedPreferences _prefs;

  StorageService(this._prefs);

  bool get hasCompletedOnboarding => _prefs.getBool(_onboardingKey) ?? false;

  Future<void> setOnboardingCompleted(bool value) async {
    await _prefs.setBool(_onboardingKey, value);
  }

  static Future<StorageService> init() async {
    final prefs = await SharedPreferences.getInstance();
    final service = StorageService(prefs);
    await service._maybeSeedData();
    return service;
  }

  // --- CARDS ---

  Future<List<ContactCard>> loadCards() async {
    final jsonString = _prefs.getString(_cardsKey);
    if (jsonString == null || jsonString.isEmpty) {
      return [];
    }
    try {
      final list = jsonDecode(jsonString) as List<dynamic>;
      return list.map((item) => ContactCard.fromJson(item as Map<String, dynamic>)).toList();
    } catch (e) {
      return [];
    }
  }

  Future<void> saveCards(List<ContactCard> cards) async {
    final list = cards.map((c) => c.toJson()).toList();
    await _prefs.setString(_cardsKey, jsonEncode(list));
  }

  // --- CONNECTIONS ---

  Future<List<SavedConnection>> loadConnections() async {
    final jsonString = _prefs.getString(_connectionsKey);
    if (jsonString == null || jsonString.isEmpty) {
      return [];
    }
    try {
      final list = jsonDecode(jsonString) as List<dynamic>;
      return list.map((item) => SavedConnection.fromJson(item as Map<String, dynamic>)).toList();
    } catch (e) {
      return [];
    }
  }

  Future<void> saveConnections(List<SavedConnection> connections) async {
    final list = connections.map((c) => c.toJson()).toList();
    await _prefs.setString(_connectionsKey, jsonEncode(list));
  }

  // --- SEED INITIAL DATA ---

  Future<void> _maybeSeedData() async {
    final hasInit = _prefs.getBool(_initializedKey) ?? false;
    if (hasInit) return;

    // Seed default cards
    final initialCards = [
      ContactCard(
        id: 'card-1',
        title: 'Professional',
        category: CardCategory.professional,
        fullName: 'Cam Robertson',
        role: 'Tech Lead & Founder',
        company: 'VentureScale Labs',
        headline: 'Host of Cam\'s Tech Talk | Angel Investor & Engineering Leader',
        email: 'cam@venturescale.io',
        phone: '+1 (415) 555-0192',
        location: 'San Francisco, CA',
        bio: 'Building developer tools and exploring next-gen mobile & AI architectures.',
        techStack: ['Flutter', 'Systems Architecture', 'Cloudflare', 'TypeScript'],
        links: [
          const CardLink(
            id: 'link-1',
            title: 'LinkedIn',
            url: 'https://linkedin.com/in/cam-robertson',
            type: LinkType.linkedin,
          ),
          const CardLink(
            id: 'link-2',
            title: 'Podcast / Talk',
            url: 'https://camstechtalk.com',
            type: LinkType.website,
          ),
          const CardLink(
            id: 'link-3',
            title: 'Twitter / X',
            url: 'https://x.com/cam_tech',
            type: LinkType.twitter,
          ),
        ],
        themeColorHex: '#2563EB',
        isDefault: true,
        createdAt: DateTime.now().subtract(const Duration(days: 30)),
        updatedAt: DateTime.now(),
      ),
      ContactCard(
        id: 'card-2',
        title: 'Side Projects & Creator',
        category: CardCategory.sideProject,
        fullName: 'Cam Robertson',
        role: 'Indie Builder',
        company: 'Open Source Projects',
        headline: 'Creating tools for developers & networking efficiency',
        email: 'cam.builds@gmail.com',
        phone: '+1 (415) 555-0192',
        location: 'Remote',
        bio: 'Passionate about offline-first architectures, mobile agents, and cross-platform UX.',
        techStack: ['Flutter', 'Dart', 'Go', 'Supabase'],
        links: [
          const CardLink(
            id: 'link-4',
            title: 'GitHub',
            url: 'https://github.com/cam-builder',
            type: LinkType.github,
          ),
          const CardLink(
            id: 'link-5',
            title: 'Portfolio',
            url: 'https://camrobertson.dev',
            type: LinkType.portfolio,
          ),
        ],
        themeColorHex: '#0D9488',
        isDefault: false,
        createdAt: DateTime.now().subtract(const Duration(days: 15)),
        updatedAt: DateTime.now(),
      ),
      ContactCard(
        id: 'card-3',
        title: 'Personal',
        category: CardCategory.personal,
        fullName: 'Cam Robertson',
        role: 'Photographer & Runner',
        company: 'Personal',
        headline: 'Marathon runner and weekend landscape photographer',
        email: 'hello@cam.me',
        phone: '+1 (415) 555-0192',
        location: 'California',
        bio: 'Say hi if you run in the Bay Area or love espresso.',
        techStack: [],
        links: [
          const CardLink(
            id: 'link-6',
            title: 'Instagram',
            url: 'https://instagram.com/cam_captures',
            type: LinkType.website,
          ),
        ],
        themeColorHex: '#8B5CF6',
        isDefault: false,
        createdAt: DateTime.now().subtract(const Duration(days: 5)),
        updatedAt: DateTime.now(),
      ),
    ];
    await saveCards(initialCards);

    // Seed realistic connections including the Anit Singh & Cam's Tech Talk scenario!
    final initialConnections = [
      SavedConnection(
        id: 'conn-1',
        fullName: 'Anit Singh',
        role: 'Senior Mobile & Full-Stack Architect',
        company: 'AuruNex',
        headline: 'Side project developer building high-impact Android & Flutter apps',
        email: 'anit@aurunex.dev',
        phone: '+1 (650) 443-8821',
        avatarUrl: '',
        techStack: ['Flutter', 'Android', 'Dart', 'Kotlin', 'Firebase', 'Cloudflare', 'AI Agents'],
        links: [
          const CardLink(
            id: 'conn-link-1',
            title: 'GitHub',
            url: 'https://github.com/anitsingh',
            type: LinkType.github,
          ),
          const CardLink(
            id: 'conn-link-2',
            title: 'LinkedIn',
            url: 'https://linkedin.com/in/anitsingh',
            type: LinkType.linkedin,
          ),
          const CardLink(
            id: 'conn-link-3',
            title: 'Side Projects',
            url: 'https://aurunex.dev',
            type: LinkType.website,
          ),
        ],
        eventContext: EventContext(
          eventName: "Cam's Tech Talk",
          location: 'San Francisco Tech Hub',
          date: DateTime.now().subtract(const Duration(days: 180)),
          notes: 'Met at Cam\'s Tech Talk after the cross-platform talk. Anit is a prolific side project developer who builds applications on Android, Flutter, and AI agent frameworks. Exchanged contacts and talked about building an offline-first contact card builder.',
          tags: ['Flutter', 'Android', 'Side Projects', 'Mobile Expert', 'Cloudflare'],
        ),
        futureSelfNote: 'Note to Future Self: Super humble yet brilliantly sharp architect. Spoke with immense passion about mobile agents and offline-first architectures. Definitely want to team up with him or build our next startup together!',
        vibeTags: ['Aspirational Founder', 'High Potential Co-founder', 'Sharp & Humble', 'Wants to Collaborate'],
        distinctiveMemory: 'Debated offline-first state machines; showed off sleek dark-mode prototype on his phone.',
        microContext: 'Hallway Chat after keynote session',
        callWhen: ['Need Mobile App', 'Offline Architecture', 'Start New Venture', 'Flutter & Android'],
        savedAt: DateTime.now().subtract(const Duration(days: 180)),
        isFavorite: true,
      ),
      SavedConnection(
        id: 'conn-2',
        fullName: 'Elena Rostova',
        role: 'Staff Machine Learning Engineer',
        company: 'DeepSynthetix',
        headline: 'On-device LLMs, CoreML & Quantization Researcher',
        email: 'elena.rostova@deepsynthetix.ai',
        phone: '+1 (415) 890-1234',
        avatarUrl: '',
        techStack: ['PyTorch', 'On-device AI', 'C++', 'Python', 'CoreML'],
        links: [
          const CardLink(
            id: 'conn-link-4',
            title: 'Hugging Face',
            url: 'https://huggingface.co/elena-rostova',
            type: LinkType.website,
          ),
          const CardLink(
            id: 'conn-link-5',
            title: 'LinkedIn',
            url: 'https://linkedin.com/in/elena-rostova',
            type: LinkType.linkedin,
          ),
        ],
        eventContext: EventContext(
          eventName: 'AI Innovators Summit',
          location: 'Austin Convention Center',
          date: DateTime.now().subtract(const Duration(days: 90)),
          notes: 'Demonstrated real-time local inference running on mobile neural engines. Interested in collaborating on edge AI apps.',
          tags: ['Machine Learning', 'On-device AI', 'PyTorch'],
        ),
        futureSelfNote: 'Note to Future Self: Incredibly articulate researcher. Explained quantizing 7B LLMs for phone chips over matcha. Reach out to her when we need an on-device AI model that runs without server costs.',
        vibeTags: ['Visionary Researcher', 'Deep Tech Guru', 'Down-to-earth Genius', 'Edge AI Expert'],
        distinctiveMemory: 'Explained quantizing 7B LLMs on mobile neural engines; carried green iced matcha drink.',
        microContext: 'Coffee Break at Exhibition Hall',
        callWhen: ['On-device AI', 'Model Quantization', 'Local LLM Inference', 'Edge Compute'],
        savedAt: DateTime.now().subtract(const Duration(days: 90)),
        isFavorite: false,
      ),
      SavedConnection(
        id: 'conn-3',
        fullName: 'Marcus Vance',
        role: 'Distributed Systems Lead',
        company: 'EdgeMesh Networks',
        headline: 'Serverless architecture, Cloudflare Workers & High-throughput Go services',
        email: 'marcus@edgemesh.io',
        phone: '+1 (206) 998-3321',
        avatarUrl: '',
        techStack: ['Go', 'Cloudflare Workers', 'Rust', 'PostgreSQL', 'Docker'],
        links: [
          const CardLink(
            id: 'conn-link-6',
            title: 'GitHub',
            url: 'https://github.com/marcusvance',
            type: LinkType.github,
          ),
        ],
        eventContext: EventContext(
          eventName: 'Cloud Native Global Expo',
          location: 'Seattle, WA',
          date: DateTime.now().subtract(const Duration(days: 45)),
          notes: 'Discussed edge caching and deploying serverless databases on Cloudflare D1 with zero latency worldwide.',
          tags: ['Cloudflare', 'Go', 'Backend', 'DevOps'],
        ),
        futureSelfNote: 'Note to Future Self: High energy and pragmatic engineer. Talked about sub-5ms distributed edge systems. Ping Marcus when scaling infrastructure or if looking for a rock-solid CTO.',
        vibeTags: ['Pragmatic Leader', 'Infrastructure Wizard', 'Great Energy', 'Potential CTO'],
        distinctiveMemory: 'Drew distributed cluster topology on a napkin; wore retro tech conference hoodie.',
        microContext: 'Afterparty / Networking Lounge',
        callWhen: ['Cloud Architecture', 'Scaling Crisis', 'Edge Routing', 'Need CTO Advice'],
        savedAt: DateTime.now().subtract(const Duration(days: 45)),
        isFavorite: false,
      ),
      SavedConnection(
        id: 'conn-4',
        fullName: 'Priya Sharma',
        role: 'Lead UI/UX Designer & Design Systems',
        company: 'DesignCraft Studio',
        headline: 'Crafting minimalist, highly accessible mobile design systems in Figma',
        email: 'priya@designcraft.co',
        phone: '+44 20 7946 0912',
        avatarUrl: '',
        techStack: ['Figma', 'Design Systems', 'Mobile UX', 'Tailwind', 'Prototyping'],
        links: [
          const CardLink(
            id: 'conn-link-7',
            title: 'Dribbble',
            url: 'https://dribbble.com/priyasharma',
            type: LinkType.website,
          ),
          const CardLink(
            id: 'conn-link-8',
            title: 'LinkedIn',
            url: 'https://linkedin.com/in/priyasharma-ux',
            type: LinkType.linkedin,
          ),
        ],
        eventContext: EventContext(
          eventName: "Cam's Tech Talk",
          location: 'San Francisco Tech Hub',
          date: DateTime.now().subtract(const Duration(days: 180)),
          notes: 'Also attended Cam\'s Tech Talk. Great eye for typography, mobile card micro-interactions, and accessibility.',
          tags: ['Design', 'UI/UX', 'Figma', 'Mobile Systems'],
        ),
        futureSelfNote: 'Note to Future Self: Phenomenal aesthetic sensibility and attention to detail. She noticed micro-typography subtleties immediately. Absolutely must consult her when polishing user interfaces.',
        vibeTags: ['Aesthetic Visionary', 'Obsessed with Quality', 'Warm & Empathetic', 'Design Maestro'],
        distinctiveMemory: 'Obsessed with micro-interactions, haptics and hairline borders; carried retro sketchbook.',
        microContext: 'Q&A session front row',
        callWhen: ['Design Systems', 'UX Polish & Haptics', 'Brand Redesign', 'Mobile App Critique'],
        savedAt: DateTime.now().subtract(const Duration(days: 180)),
        isFavorite: true,
      ),
    ];
    await saveConnections(initialConnections);

    await _prefs.setBool(_initializedKey, true);
  }
}
