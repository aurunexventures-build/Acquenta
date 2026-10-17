import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:uuid/uuid.dart';
import '../models/contact_card.dart';
import '../models/card_link.dart';
import '../providers/cards_provider.dart';
import '../widgets/tag_chip.dart';

class CardEditorScreen extends StatefulWidget {
  final ContactCard? initialCard;

  const CardEditorScreen({super.key, this.initialCard});

  @override
  State<CardEditorScreen> createState() => _CardEditorScreenState();
}

class _CardEditorScreenState extends State<CardEditorScreen> {
  final _formKey = GlobalKey<FormState>();

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

  final TextEditingController _tagController = TextEditingController();

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
  }

  @override
  void dispose() {
    _tagController.dispose();
    super.dispose();
  }

  void _addTechTag() {
    final text = _tagController.text.trim();
    if (text.isNotEmpty && !_techStack.contains(text)) {
      setState(() {
        _techStack.add(text);
        _tagController.clear();
      });
    }
  }

  void _showAddLinkDialog([CardLink? existingLink, int? index]) {
    final titleController = TextEditingController(text: existingLink?.title ?? '');
    final urlController = TextEditingController(text: existingLink?.url ?? '');
    LinkType selectedType = existingLink?.type ?? LinkType.website;

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDialogState) => AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
          title: Text(existingLink != null ? 'Edit Link' : 'Add Link / Social'),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                DropdownButtonFormField<LinkType>(
                  initialValue: selectedType,
                  decoration: const InputDecoration(labelText: 'Link Type'),
                  items: LinkType.values.map((t) {
                    return DropdownMenuItem(
                      value: t,
                      child: Text(t.name.toUpperCase()),
                    );
                  }).toList(),
                  onChanged: (val) {
                    if (val != null) {
                      setDialogState(() {
                        selectedType = val;
                        if (titleController.text.isEmpty) {
                          titleController.text = val.name.toUpperCase();
                        }
                      });
                    }
                  },
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: titleController,
                  decoration: const InputDecoration(
                    labelText: 'Label / Title',
                    hintText: 'e.g. GitHub, Portfolio, LinkedIn',
                  ),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: urlController,
                  decoration: const InputDecoration(
                    labelText: 'URL or Handle',
                    hintText: 'https://...',
                  ),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('Cancel'),
            ),
            ElevatedButton(
              onPressed: () {
                final url = urlController.text.trim();
                final title = titleController.text.trim();
                if (url.isNotEmpty) {
                  setState(() {
                    final newLink = CardLink(
                      id: existingLink?.id ?? const Uuid().v4(),
                      title: title.isNotEmpty ? title : selectedType.name,
                      url: url,
                      type: selectedType,
                    );
                    if (index != null) {
                      _links[index] = newLink;
                    } else {
                      _links.add(newLink);
                    }
                  });
                  Navigator.pop(ctx);
                }
              },
              child: const Text('Save Link'),
            ),
          ],
        ),
      ),
    );
  }

  void _saveCard() {
    if (!_formKey.currentState!.validate()) return;
    _formKey.currentState!.save();

    final provider = Provider.of<CardsProvider>(context, listen: false);
    final now = DateTime.now();

    if (widget.initialCard != null) {
      final updated = widget.initialCard!.copyWith(
        title: _title,
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
      provider.updateCard(updated);
    } else {
      final newCard = ContactCard(
        id: const Uuid().v4(),
        title: _title,
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
      provider.addCard(newCard);
    }

    Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isEditing = widget.initialCard != null;

    return Scaffold(
      appBar: AppBar(
        title: Text(isEditing ? 'Edit Visiting Card' : 'Create Visiting Card'),
        actions: [
          TextButton.icon(
            icon: const Icon(Icons.check, color: Colors.blue),
            label: const Text('Save', style: TextStyle(fontWeight: FontWeight.bold)),
            onPressed: _saveCard,
          ),
        ],
      ),
      body: Form(
        key: _formKey,
        child: ListView(
          padding: const EdgeInsets.all(20),
          children: [
            // Card Identifier & Category
            Card(
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Card Purpose & Type',
                      style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold),
                    ),
                    const SizedBox(height: 12),
                    Row(
                      children: [
                        Expanded(
                          child: TextFormField(
                            initialValue: _title,
                            decoration: const InputDecoration(
                              labelText: 'Card Title / Persona',
                              hintText: 'e.g. Side Project Dev, Work Card',
                              isDense: true,
                              border: OutlineInputBorder(),
                            ),
                            validator: (v) => v == null || v.isEmpty ? 'Required' : null,
                            onSaved: (v) => _title = v ?? '',
                          ),
                        ),
                        const SizedBox(width: 12),
                        DropdownButton<CardCategory>(
                          value: _category,
                          items: CardCategory.values.map((cat) {
                            return DropdownMenuItem(
                              value: cat,
                              child: Text(cat.displayName),
                            );
                          }).toList(),
                          onChanged: (cat) {
                            if (cat != null) setState(() => _category = cat);
                          },
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    // Theme color row
                    Row(
                      children: [
                        const Text('Accent Color:', style: TextStyle(fontSize: 13)),
                        const SizedBox(width: 12),
                        ..._colorPalette.map((hex) {
                          final isSelected = _themeColorHex.toLowerCase() == hex.toLowerCase();
                          final color = Color(int.parse('FF${hex.replaceAll('#', '')}', radix: 16));
                          return GestureDetector(
                            onTap: () => setState(() => _themeColorHex = hex),
                            child: Container(
                              margin: const EdgeInsets.symmetric(horizontal: 4),
                              width: 26,
                              height: 26,
                              decoration: BoxDecoration(
                                color: color,
                                shape: BoxShape.circle,
                                border: Border.all(
                                  color: isSelected ? Colors.black : Colors.transparent,
                                  width: 2.5,
                                ),
                              ),
                              child: isSelected
                                  ? const Icon(Icons.check, size: 14, color: Colors.white)
                                  : null,
                            ),
                          );
                        }),
                      ],
                    ),
                    const SizedBox(height: 8),
                    SwitchListTile(
                      contentPadding: EdgeInsets.zero,
                      title: const Text('Set as Primary / Default Card'),
                      subtitle: const Text('Primary card shown on app launch'),
                      value: _isDefault,
                      onChanged: (v) => setState(() => _isDefault = v),
                    ),
                  ],
                ),
              ),
            ),

            const SizedBox(height: 16),

            // Personal Information
            Card(
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Contact Information',
                      style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold),
                    ),
                    const SizedBox(height: 16),
                    TextFormField(
                      initialValue: _fullName,
                      decoration: const InputDecoration(
                        labelText: 'Full Name *',
                        prefixIcon: Icon(Icons.person_outline),
                        border: OutlineInputBorder(),
                      ),
                      validator: (v) => v == null || v.trim().isEmpty ? 'Please enter name' : null,
                      onSaved: (v) => _fullName = v?.trim() ?? '',
                    ),
                    const SizedBox(height: 12),
                    Row(
                      children: [
                        Expanded(
                          child: TextFormField(
                            initialValue: _role,
                            decoration: const InputDecoration(
                              labelText: 'Role / Job Title',
                              hintText: 'e.g. Flutter Architect',
                              isDense: true,
                              border: OutlineInputBorder(),
                            ),
                            onSaved: (v) => _role = v?.trim() ?? '',
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: TextFormField(
                            initialValue: _company,
                            decoration: const InputDecoration(
                              labelText: 'Company / Studio',
                              hintText: 'e.g. AuruNex',
                              isDense: true,
                              border: OutlineInputBorder(),
                            ),
                            onSaved: (v) => _company = v?.trim() ?? '',
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    TextFormField(
                      initialValue: _headline,
                      decoration: const InputDecoration(
                        labelText: 'Headline / Pitch',
                        hintText: 'e.g. Building Android & Flutter apps, explore side projects',
                        prefixIcon: Icon(Icons.bolt_outlined),
                        border: OutlineInputBorder(),
                      ),
                      onSaved: (v) => _headline = v?.trim() ?? '',
                    ),
                    const SizedBox(height: 12),
                    Row(
                      children: [
                        Expanded(
                          child: TextFormField(
                            initialValue: _email,
                            keyboardType: TextInputType.emailAddress,
                            decoration: const InputDecoration(
                              labelText: 'Email',
                              prefixIcon: Icon(Icons.email_outlined),
                              isDense: true,
                              border: OutlineInputBorder(),
                            ),
                            onSaved: (v) => _email = v?.trim() ?? '',
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: TextFormField(
                            initialValue: _phone,
                            keyboardType: TextInputType.phone,
                            decoration: const InputDecoration(
                              labelText: 'Phone',
                              prefixIcon: Icon(Icons.phone_outlined),
                              isDense: true,
                              border: OutlineInputBorder(),
                            ),
                            onSaved: (v) => _phone = v?.trim() ?? '',
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    TextFormField(
                      initialValue: _location,
                      decoration: const InputDecoration(
                        labelText: 'Location / City',
                        prefixIcon: Icon(Icons.location_on_outlined),
                        isDense: true,
                        border: OutlineInputBorder(),
                      ),
                      onSaved: (v) => _location = v?.trim() ?? '',
                    ),
                    const SizedBox(height: 12),
                    TextFormField(
                      initialValue: _bio,
                      maxLines: 3,
                      decoration: const InputDecoration(
                        labelText: 'Bio & What I Do',
                        hintText: 'Brief summary of what you are working on or open to...',
                        border: OutlineInputBorder(),
                      ),
                      onSaved: (v) => _bio = v?.trim() ?? '',
                    ),
                  ],
                ),
              ),
            ),

            const SizedBox(height: 16),

            // Tech Stack & Skills (Crucial for Context Recall)
            Card(
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        const Icon(Icons.terminal_rounded, size: 20, color: Colors.blue),
                        const SizedBox(width: 8),
                        Text(
                          'Tech Stack & Skills',
                          style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold),
                        ),
                      ],
                    ),
                    const SizedBox(height: 6),
                    Text(
                      'Crucial for memory recall: enables people to search and find you by technology!',
                      style: TextStyle(fontSize: 12, color: theme.hintColor),
                    ),
                    const SizedBox(height: 12),
                    Row(
                      children: [
                        Expanded(
                          child: TextField(
                            controller: _tagController,
                            decoration: const InputDecoration(
                              hintText: 'Add skill (e.g. Flutter, Android, AI Agents)',
                              isDense: true,
                              border: OutlineInputBorder(),
                            ),
                            onSubmitted: (_) => _addTechTag(),
                          ),
                        ),
                        const SizedBox(width: 8),
                        ElevatedButton(
                          onPressed: _addTechTag,
                          child: const Text('Add'),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    if (_techStack.isEmpty)
                      Text(
                        'No tech stack added yet. Add tags to be discoverable.',
                        style: TextStyle(fontSize: 12, color: theme.hintColor, fontStyle: FontStyle.italic),
                      )
                    else
                      Wrap(
                        spacing: 8,
                        runSpacing: 8,
                        children: _techStack.map((t) {
                          return TagChip(
                            label: t,
                            onDeleted: () {
                              setState(() => _techStack.remove(t));
                            },
                          );
                        }).toList(),
                      ),
                  ],
                ),
              ),
            ),

            const SizedBox(height: 16),

            // Links & Social Profiles
            Card(
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          'Links & Socials (${_links.length})',
                          style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold),
                        ),
                        TextButton.icon(
                          icon: const Icon(Icons.add, size: 18),
                          label: const Text('Add Link'),
                          onPressed: () => _showAddLinkDialog(),
                        ),
                      ],
                    ),
                    if (_links.isEmpty)
                      Padding(
                        padding: const EdgeInsets.symmetric(vertical: 8),
                        child: Text(
                          'No links yet. Add GitHub, LinkedIn, Website, or Portfolio.',
                          style: TextStyle(fontSize: 12, color: theme.hintColor, fontStyle: FontStyle.italic),
                        ),
                      )
                    else
                      ListView.separated(
                        shrinkWrap: true,
                        physics: const NeverScrollableScrollPhysics(),
                        itemCount: _links.length,
                        separatorBuilder: (context, index) => const Divider(height: 1),
                        itemBuilder: (ctx, i) {
                          final link = _links[i];
                          return ListTile(
                            contentPadding: EdgeInsets.zero,
                            leading: CircleAvatar(
                              radius: 18,
                              backgroundColor: Colors.blue.withValues(alpha: 0.1),
                              child: Icon(link.defaultIcon, size: 18, color: Colors.blue),
                            ),
                            title: Text(link.title, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
                            subtitle: Text(link.url, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontSize: 12)),
                            trailing: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                IconButton(
                                  icon: const Icon(Icons.edit, size: 18),
                                  onPressed: () => _showAddLinkDialog(link, i),
                                ),
                                IconButton(
                                  icon: const Icon(Icons.delete_outline, size: 18, color: Colors.red),
                                  onPressed: () => setState(() => _links.removeAt(i)),
                                ),
                              ],
                            ),
                          );
                        },
                      ),
                  ],
                ),
              ),
            ),

            const SizedBox(height: 24),
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                padding: const EdgeInsets.symmetric(vertical: 16),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
              ),
              onPressed: _saveCard,
              child: Text(
                isEditing ? 'Save Changes' : 'Create Card',
                style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
              ),
            ),
            const SizedBox(height: 40),
          ],
        ),
      ),
    );
  }
}
