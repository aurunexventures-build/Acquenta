import '../theme/metcue_theme.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import 'package:uuid/uuid.dart';
import '../models/saved_connection.dart';
import '../models/event_context.dart';
import '../providers/connections_provider.dart';
import '../providers/cards_provider.dart';
import '../widgets/tag_chip.dart';
import '../widgets/voice_capture_dialog.dart';

class AddConnectionScreen extends StatefulWidget {
  final SavedConnection? initialConnection;

  const AddConnectionScreen({super.key, this.initialConnection});

  @override
  State<AddConnectionScreen> createState() => _AddConnectionScreenState();
}

class _AddConnectionScreenState extends State<AddConnectionScreen> {
  final _formKey = GlobalKey<FormState>();
  bool _saving = false;
  String? _walletScope;

  late String _fullName;
  late String _role;
  late String _company;
  late String _headline;
  late String _email;
  late String _phone;
  late String _eventName;
  late String _location;
  late DateTime _eventDate;
  late String _eventNotes;
  late String _futureSelfNote;
  late List<String> _vibeTags;
  late List<String> _techStack;
  late String _distinctiveMemory;
  late String _microContext;
  late List<String> _callWhen;

  final TextEditingController _tagController = TextEditingController();
  final TextEditingController _vibeController = TextEditingController();
  final TextEditingController _microContextController = TextEditingController();

  static const List<String> _vibeSuggestions = [
    'Aspirational Founder',
    'High Potential Co-founder',
    'Sharp & Humble',
    'Great Energy',
    'Deep Tech Guru',
    'Aesthetic Visionary',
    'Infrastructure Wizard',
    'Wants to Collaborate',
  ];

  static const List<String> _microContextSuggestions = [
    'Coffee / Matcha Break',
    'Hallway Chat after Keynote',
    'After-Party / Drinks Lounge',
    'Q&A Front Row Session',
    'Live Demo / Hackathon Booth',
    'Dinner / Side Event',
  ];

  static const List<String> _callWhenSuggestions = [
    'Need Mobile App',
    'On-device AI',
    'Cloud Architecture Crisis',
    'Design Audit & Polish',
    'Start New Venture',
    'Need CTO Advice',
    'Offline Architecture',
    'Flutter & Android',
  ];

  @override
  void initState() {
    super.initState();
    final conn = widget.initialConnection;
    if (conn != null) {
      _fullName = conn.fullName;
      _role = conn.role;
      _company = conn.company;
      _headline = conn.headline;
      _email = conn.email;
      _phone = conn.phone;
      _eventName = conn.eventContext.eventName;
      _location = conn.eventContext.location;
      _eventDate = conn.eventContext.date;
      _eventNotes = conn.eventContext.notes;
      _futureSelfNote = conn.futureSelfNote;
      _vibeTags = List.from(conn.vibeTags);
      _techStack = List.from(conn.techStack);
      _distinctiveMemory = conn.distinctiveMemory;
      _microContext = conn.microContext;
      _callWhen = List.from(conn.callWhen);
    } else {
      _fullName = '';
      _role = '';
      _company = '';
      _headline = '';
      _email = '';
      _phone = '';
      // Pre-fill from active event mode if set!
      final activeEvent = Provider.of<CardsProvider>(
        context,
        listen: false,
      ).activeEventMode;
      _eventName = activeEvent?.eventName ?? '';
      _location = activeEvent?.location ?? '';
      _eventDate = DateTime.now();
      _eventNotes = '';
      _futureSelfNote = '';
      _vibeTags = [];
      _techStack = [];
      _distinctiveMemory = '';
      _microContext = '';
      _callWhen = [];
    }
  }

  @override
  void dispose() {
    _tagController.dispose();
    _vibeController.dispose();
    _microContextController.dispose();
    super.dispose();
  }

  void _addTag() {
    final text = _tagController.text.trim();
    if (text.isNotEmpty && !_techStack.contains(text)) {
      setState(() {
        _techStack.add(text);
        _tagController.clear();
      });
    }
  }

  void _addVibeTag(String vibe) {
    final text = vibe.trim();
    if (text.isNotEmpty && !_vibeTags.contains(text)) {
      setState(() {
        _vibeTags.add(text);
        _vibeController.clear();
      });
    }
  }

  Future<void> _save() async {
    if (_saving || !_formKey.currentState!.validate()) return;
    _formKey.currentState!.save();

    final connectionsProvider = Provider.of<ConnectionsProvider>(
      context,
      listen: false,
    );

    if (_walletScope != connectionsProvider.walletScope) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Account changed. Reopen this form before saving.'),
        ),
      );
      return;
    }
    setState(() => _saving = true);
    try {
      final eventContext = EventContext(
        eventName: _eventName.trim().isNotEmpty
            ? _eventName.trim()
            : 'General Networking',
        location: _location.trim(),
        date: _eventDate,
        notes: _eventNotes.trim(),
        tags: _techStack,
      );

      if (widget.initialConnection != null) {
        final updated = widget.initialConnection!.copyWith(
          fullName: _fullName,
          role: _role,
          company: _company,
          headline: _headline,
          email: _email,
          phone: _phone,
          techStack: _techStack,
          eventContext: eventContext,
          futureSelfNote: _futureSelfNote.trim(),
          vibeTags: _vibeTags,
          distinctiveMemory: _distinctiveMemory.trim(),
          microContext: _microContext.trim(),
          callWhen: _callWhen,
        );
        await connectionsProvider.updateConnection(
          updated,
          expectedVersion: widget.initialConnection!.updatedAt,
        );
      } else {
        final newConn = SavedConnection(
          id: const Uuid().v4(),
          fullName: _fullName,
          role: _role,
          company: _company,
          headline: _headline,
          email: _email,
          phone: _phone,
          techStack: _techStack,
          links: const [],
          eventContext: eventContext,
          futureSelfNote: _futureSelfNote.trim(),
          vibeTags: _vibeTags,
          distinctiveMemory: _distinctiveMemory.trim(),
          microContext: _microContext.trim(),
          callWhen: _callWhen,
          savedAt: DateTime.now(),
          isFavorite: false,
        );
        await connectionsProvider.addConnection(newConn);
      }

      if (mounted) Navigator.pop(context);
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
              'Could not save. Your draft is kept here. If the connection changed, copy your edits and reopen it.',
            ),
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    _walletScope ??= context.read<ConnectionsProvider>().walletScope;
    final theme = Theme.of(context);
    final isEditing = widget.initialConnection != null;

    return Scaffold(
      appBar: AppBar(
        title: Text(isEditing ? 'Edit Connection' : 'Save New Connection'),
        actions: [
          TextButton.icon(
            icon: const Icon(Icons.check, color: MetCueTheme.purple),
            label: const Text(
              'Save',
              style: TextStyle(fontWeight: FontWeight.bold),
            ),
            onPressed: _saving ? null : _save,
          ),
        ],
      ),
      body: Form(
        key: _formKey,
        child: ListView(
          keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
          padding: const EdgeInsets.all(20),
          children: [
            OutlinedButton.icon(
              icon: const Icon(Icons.mic),
              label: const Text('Use a quick memory cue instead'),
              onPressed: () async {
                bool saved = false;
                final provider = context.read<ConnectionsProvider>();
                await showDialog(
                  context: context,
                  builder: (_) => VoiceCaptureDialog(
                    connection: widget.initialConnection,
                    activeEventName: context
                        .read<CardsProvider>()
                        .activeEventMode
                        ?.eventName,
                    onCaptured: (connection) async {
                      if (widget.initialConnection == null) {
                        await provider.addConnection(connection);
                      } else {
                        await provider.updateConnection(connection);
                      }
                      saved = true;
                    },
                  ),
                );
                if (saved && context.mounted) Navigator.pop(context);
              },
            ),
            const SizedBox(height: 16),
            // Event Memory Block (Highlighted because this solves Cam's problem!)
            Container(
              decoration: BoxDecoration(
                color: MetCueTheme.purple.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(20),
                border: Border.all(
                  color: MetCueTheme.purple.withValues(alpha: 0.4),
                ),
              ),
              padding: const EdgeInsets.all(18),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Row(
                    children: [
                      Icon(
                        Icons.psychology_alt_rounded,
                        color: MetCueTheme.purple,
                        size: 24,
                      ),
                      SizedBox(width: 8),
                      Text(
                        'Event Context & Memory Aid',
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 16,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 6),
                  Text(
                    'Fill this in so you can easily recall: "Who was that person I met at this event who does X?" even years later!',
                    style: TextStyle(
                      fontSize: 12,
                      color: theme.textTheme.bodyMedium?.color?.withValues(
                        alpha: 0.8,
                      ),
                    ),
                  ),
                  const SizedBox(height: 14),
                  TextFormField(
                    scrollPadding: const EdgeInsets.only(top: 24, bottom: 96),
                    initialValue: _eventName,
                    decoration: const InputDecoration(
                      labelText: 'Event / Meetup Name *',
                      hintText: 'e.g. Cam\'s Tech Talk, Google I/O',
                      prefixIcon: Icon(Icons.event, color: MetCueTheme.purple),
                      filled: true,
                      fillColor: Colors.white,
                      border: OutlineInputBorder(),
                    ),
                    validator: (v) => v == null || v.trim().isEmpty
                        ? 'Please enter event name'
                        : null,
                    onSaved: (v) => _eventName = v ?? '',
                  ),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      Expanded(
                        child: TextFormField(
                          scrollPadding: const EdgeInsets.only(
                            top: 24,
                            bottom: 96,
                          ),
                          initialValue: _location,
                          decoration: const InputDecoration(
                            labelText: 'Location / Venue',
                            hintText: 'e.g. SF, London, Virtual',
                            prefixIcon: Icon(
                              Icons.location_on_outlined,
                              size: 20,
                            ),
                            filled: true,
                            fillColor: Colors.white,
                            border: OutlineInputBorder(),
                          ),
                          onSaved: (v) => _location = v ?? '',
                        ),
                      ),
                      const SizedBox(width: 12),
                      OutlinedButton.icon(
                        style: OutlinedButton.styleFrom(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 14,
                            vertical: 16,
                          ),
                          backgroundColor: Colors.white,
                        ),
                        icon: const Icon(Icons.calendar_today, size: 16),
                        label: Text(DateFormat('MMM d, y').format(_eventDate)),
                        onPressed: () async {
                          final picked = await showDatePicker(
                            context: context,
                            initialDate: _eventDate,
                            firstDate: DateTime(2020),
                            lastDate: DateTime.now().add(
                              const Duration(days: 365),
                            ),
                          );
                          if (picked != null) {
                            setState(() => _eventDate = picked);
                          }
                        },
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  TextFormField(
                    scrollPadding: const EdgeInsets.only(top: 24, bottom: 96),
                    initialValue: _eventNotes,
                    maxLines: 3,
                    decoration: const InputDecoration(
                      labelText: 'Discussion Notes & What They Do',
                      hintText:
                          'e.g. Building side projects on Android & Flutter, talked about AI agent apps, looking for mobile co-founder...',
                      prefixIcon: Icon(Icons.edit_note, size: 22),
                      filled: true,
                      fillColor: Colors.white,
                      border: OutlineInputBorder(),
                    ),
                    onSaved: (v) => _eventNotes = v ?? '',
                  ),
                ],
              ),
            ),

            const SizedBox(height: 20),

            // Human Touch: Message to My Future Self & Vibe Check
            Card(
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
                side: BorderSide(
                  color: MetCueTheme.purple.withValues(alpha: 0.3),
                  width: 1.2,
                ),
              ),
              color: MetCueTheme.purple.withValues(alpha: 0.04),
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        const Icon(
                          Icons.mark_email_read_rounded,
                          size: 20,
                          color: MetCueTheme.purple,
                        ),
                        const SizedBox(width: 8),
                        Text(
                          'Message to My Future Self',
                          style: theme.textTheme.titleMedium?.copyWith(
                            fontWeight: FontWeight.bold,
                            color: MetCueTheme.purple,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 6),
                    Text(
                      'Capture your authentic impression or intuition for your future self when recalling this person (e.g. "Super sharp, aspirational founder, want to collaborate with him in future").',
                      style: TextStyle(fontSize: 12, color: theme.hintColor),
                    ),
                    const SizedBox(height: 12),
                    TextFormField(
                      scrollPadding: const EdgeInsets.only(top: 24, bottom: 96),
                      initialValue: _futureSelfNote,
                      maxLines: 2,
                      decoration: const InputDecoration(
                        labelText: 'Personal Advice to Future Self',
                        hintText:
                            'e.g. Very nice in talking and sounded very aspirational, would want to work with in future...',
                        prefixIcon: Icon(Icons.psychology_alt_rounded),
                        border: OutlineInputBorder(),
                      ),
                      onChanged: (v) => _futureSelfNote = v,
                    ),
                    const SizedBox(height: 16),
                    Text(
                      'Human Vibe & Impression Badges:',
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.bold,
                        color: theme.textTheme.bodyMedium?.color,
                      ),
                    ),
                    const SizedBox(height: 8),
                    // Quick vibe presets
                    Wrap(
                      spacing: 6,
                      runSpacing: 6,
                      children: _vibeSuggestions.map((vibe) {
                        final isSelected = _vibeTags.contains(vibe);
                        return FilterChip(
                          label: Text(
                            vibe,
                            style: const TextStyle(fontSize: 11),
                          ),
                          selected: isSelected,
                          onSelected: (selected) {
                            setState(() {
                              if (selected) {
                                _vibeTags.add(vibe);
                              } else {
                                _vibeTags.remove(vibe);
                              }
                            });
                          },
                          selectedColor: MetCueTheme.purple.withValues(
                            alpha: 0.25,
                          ),
                          checkmarkColor: MetCueTheme.purple,
                        );
                      }).toList(),
                    ),
                    const SizedBox(height: 10),
                    Row(
                      children: [
                        Expanded(
                          child: TextField(
                            scrollPadding: const EdgeInsets.only(
                              top: 24,
                              bottom: 96,
                            ),
                            controller: _vibeController,
                            decoration: const InputDecoration(
                              hintText: 'Or add custom vibe badge...',
                              isDense: true,
                              border: OutlineInputBorder(),
                            ),
                            onSubmitted: (v) => _addVibeTag(v),
                          ),
                        ),
                        const SizedBox(width: 8),
                        ElevatedButton(
                          onPressed: () => _addVibeTag(_vibeController.text),
                          child: const Text('Add'),
                        ),
                      ],
                    ),
                    if (_vibeTags.isNotEmpty) ...[
                      const SizedBox(height: 10),
                      Wrap(
                        spacing: 6,
                        runSpacing: 6,
                        children: _vibeTags.map((vibe) {
                          return TagChip(
                            label: '✨ $vibe',
                            backgroundColor: MetCueTheme.purple.withValues(
                              alpha: 0.12,
                            ),
                            textColor: MetCueTheme.purple,
                            onDeleted: () =>
                                setState(() => _vibeTags.remove(vibe)),
                          );
                        }).toList(),
                      ),
                    ],
                  ],
                ),
              ),
            ),

            const SizedBox(height: 20),

            // Cognitive Memory Anchors (1-Year Human Recall Science)
            Container(
              decoration: BoxDecoration(
                color: MetCueTheme.purple.withValues(alpha: 0.08),
                borderRadius: BorderRadius.circular(20),
                border: Border.all(
                  color: MetCueTheme.purple.withValues(alpha: 0.35),
                ),
              ),
              padding: const EdgeInsets.all(18),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(6),
                        decoration: BoxDecoration(
                          color: MetCueTheme.purple.withValues(alpha: 0.2),
                          shape: BoxShape.circle,
                        ),
                        child: const Icon(
                          Icons.hub_rounded,
                          size: 18,
                          color: MetCueTheme.purple,
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Cognitive Memory Anchors (1-Year Recall)',
                              style: theme.textTheme.titleMedium?.copyWith(
                                fontWeight: FontWeight.bold,
                                color: MetCueTheme.purple,
                              ),
                            ),
                            Text(
                              'How human memory actually recalls people: sensory cues & trigger scenarios',
                              style: TextStyle(
                                fontSize: 11,
                                color: theme.hintColor,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),

                  // 1. Distinctive Visual / Sensory Memory
                  Text(
                    '1. Visual or Quirky Detail (Sensory Anchor):',
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.bold,
                      color: theme.textTheme.bodyMedium?.color,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'What did your senses register? (e.g. "Debated offline state machines; sleek dark-mode prototype on phone", "Wore bright orange On-Cloud shoes")',
                    style: TextStyle(fontSize: 11, color: theme.hintColor),
                  ),
                  const SizedBox(height: 8),
                  TextFormField(
                    scrollPadding: const EdgeInsets.only(top: 24, bottom: 96),
                    initialValue: _distinctiveMemory,
                    maxLines: 2,
                    decoration: const InputDecoration(
                      hintText:
                          'e.g. Debated offline-first state machines; showed off sleek dark-mode prototype...',
                      prefixIcon: Icon(
                        Icons.visibility_outlined,
                        color: MetCueTheme.purple,
                      ),
                      border: OutlineInputBorder(),
                    ),
                    onChanged: (v) => _distinctiveMemory = v,
                  ),
                  const SizedBox(height: 16),

                  // 2. Micro-Context / Scene
                  Text(
                    '2. Micro-Scene Context (Where in the venue?):',
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.bold,
                      color: theme.textTheme.bodyMedium?.color,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Wrap(
                    spacing: 6,
                    runSpacing: 6,
                    children: _microContextSuggestions.map((scene) {
                      final isSelected = _microContext == scene;
                      return ChoiceChip(
                        label: Text(
                          scene,
                          style: const TextStyle(fontSize: 11),
                        ),
                        selected: isSelected,
                        onSelected: (selected) {
                          setState(() {
                            _microContext = selected ? scene : '';
                            _microContextController.text = _microContext;
                          });
                        },
                        selectedColor: MetCueTheme.purple.withValues(
                          alpha: 0.25,
                        ),
                      );
                    }).toList(),
                  ),
                  const SizedBox(height: 8),
                  TextFormField(
                    scrollPadding: const EdgeInsets.only(top: 24, bottom: 96),
                    controller: _microContextController,
                    decoration: const InputDecoration(
                      hintText: 'Or custom scene: e.g. Front row after Q&A...',
                      prefixIcon: Icon(
                        Icons.place_outlined,
                        color: MetCueTheme.purple,
                      ),
                      isDense: true,
                      border: OutlineInputBorder(),
                    ),
                    onChanged: (v) => _microContext = v,
                  ),
                  const SizedBox(height: 16),

                  // 3. Situational "Call When..." Action Triggers
                  Text(
                    '3. "Call When..." Situational Triggers:',
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.bold,
                      color: theme.textTheme.bodyMedium?.color,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'In what future scenarios should your memory recall this person?',
                    style: TextStyle(fontSize: 11, color: theme.hintColor),
                  ),
                  const SizedBox(height: 8),
                  Wrap(
                    spacing: 6,
                    runSpacing: 6,
                    children: _callWhenSuggestions.map((trigger) {
                      final isSelected = _callWhen.contains(trigger);
                      return FilterChip(
                        label: Text(
                          trigger,
                          style: const TextStyle(fontSize: 11),
                        ),
                        selected: isSelected,
                        onSelected: (selected) {
                          setState(() {
                            if (selected) {
                              _callWhen.add(trigger);
                            } else {
                              _callWhen.remove(trigger);
                            }
                          });
                        },
                        selectedColor: Colors.teal.withValues(alpha: 0.25),
                        checkmarkColor: Colors.teal,
                      );
                    }).toList(),
                  ),
                ],
              ),
            ),

            const SizedBox(height: 20),

            // Person Details
            Card(
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
              ),
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Person Details',
                      style: theme.textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 14),
                    TextFormField(
                      scrollPadding: const EdgeInsets.only(top: 24, bottom: 96),
                      initialValue: _fullName,
                      decoration: const InputDecoration(
                        labelText: 'Full Name *',
                        hintText: 'e.g. Anit Singh',
                        prefixIcon: Icon(Icons.person),
                        border: OutlineInputBorder(),
                      ),
                      validator: (v) =>
                          v == null || v.trim().isEmpty ? 'Enter name' : null,
                      onSaved: (v) => _fullName = v ?? '',
                    ),
                    const SizedBox(height: 12),
                    Row(
                      children: [
                        Expanded(
                          child: TextFormField(
                            scrollPadding: const EdgeInsets.only(
                              top: 24,
                              bottom: 96,
                            ),
                            initialValue: _role,
                            decoration: const InputDecoration(
                              labelText: 'Role',
                              hintText: 'e.g. Mobile Architect',
                              border: OutlineInputBorder(),
                            ),
                            onSaved: (v) => _role = v ?? '',
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: TextFormField(
                            scrollPadding: const EdgeInsets.only(
                              top: 24,
                              bottom: 96,
                            ),
                            initialValue: _company,
                            decoration: const InputDecoration(
                              labelText: 'Company / Studio',
                              hintText: 'e.g. AuruNex',
                              border: OutlineInputBorder(),
                            ),
                            onSaved: (v) => _company = v ?? '',
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    TextFormField(
                      scrollPadding: const EdgeInsets.only(top: 24, bottom: 96),
                      initialValue: _headline,
                      decoration: const InputDecoration(
                        labelText: 'Headline / Summary',
                        hintText:
                            'e.g. Side project developer building Android & Flutter apps',
                        prefixIcon: Icon(Icons.short_text),
                        border: OutlineInputBorder(),
                      ),
                      onSaved: (v) => _headline = v ?? '',
                    ),
                    const SizedBox(height: 12),
                    Row(
                      children: [
                        Expanded(
                          child: TextFormField(
                            scrollPadding: const EdgeInsets.only(
                              top: 24,
                              bottom: 96,
                            ),
                            initialValue: _email,
                            keyboardType: TextInputType.emailAddress,
                            decoration: const InputDecoration(
                              labelText: 'Email',
                              prefixIcon: Icon(Icons.email_outlined),
                              border: OutlineInputBorder(),
                            ),
                            onSaved: (v) => _email = v ?? '',
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: TextFormField(
                            scrollPadding: const EdgeInsets.only(
                              top: 24,
                              bottom: 96,
                            ),
                            initialValue: _phone,
                            keyboardType: TextInputType.phone,
                            decoration: const InputDecoration(
                              labelText: 'Phone',
                              prefixIcon: Icon(Icons.phone_outlined),
                              border: OutlineInputBorder(),
                            ),
                            onSaved: (v) => _phone = v ?? '',
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),

            const SizedBox(height: 20),

            // Skills & Tech Stack
            Card(
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
              ),
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        const Icon(
                          Icons.terminal_rounded,
                          size: 20,
                          color: MetCueTheme.purple,
                        ),
                        const SizedBox(width: 8),
                        Text(
                          'Tech Stack / Skills Tags',
                          style: theme.textTheme.titleMedium?.copyWith(
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 6),
                    Text(
                      'Tag with technologies they mentioned (e.g. Flutter, Android, AI Agents, Cloudflare).',
                      style: TextStyle(fontSize: 12, color: theme.hintColor),
                    ),
                    const SizedBox(height: 12),
                    Row(
                      children: [
                        Expanded(
                          child: TextField(
                            scrollPadding: const EdgeInsets.only(
                              top: 24,
                              bottom: 96,
                            ),
                            controller: _tagController,
                            decoration: const InputDecoration(
                              hintText: 'Add skill tag...',
                              isDense: true,
                              border: OutlineInputBorder(),
                            ),
                            onSubmitted: (_) => _addTag(),
                          ),
                        ),
                        const SizedBox(width: 8),
                        ElevatedButton(
                          onPressed: _addTag,
                          child: const Text('Add'),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    if (_techStack.isNotEmpty)
                      Wrap(
                        spacing: 8,
                        runSpacing: 8,
                        children: _techStack.map((t) {
                          return TagChip(
                            label: t,
                            onDeleted: () =>
                                setState(() => _techStack.remove(t)),
                          );
                        }).toList(),
                      ),
                  ],
                ),
              ),
            ),

            const SizedBox(height: 24),
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                padding: const EdgeInsets.symmetric(vertical: 16),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(14),
                ),
              ),
              onPressed: _saving ? null : _save,
              child: Text(
                isEditing ? 'Update Connection' : 'Save Connection',
                style: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
            const SizedBox(height: 40),
          ],
        ),
      ),
    );
  }
}
