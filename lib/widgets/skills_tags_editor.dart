import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../services/auth_service.dart';
import '../services/sync_service.dart';
import '../services/skill_tags.dart';
import 'ai_voice_composer.dart';
import 'ai_microphone_icon.dart';

class SkillsTagsEditor extends StatefulWidget {
  final List<String> skills;
  final String role, pitch;
  final ValueChanged<List<String>> onChanged;
  final Future<List<String>> Function(String)? extract;
  const SkillsTagsEditor({
    super.key,
    required this.skills,
    required this.onChanged,
    this.role = '',
    this.pitch = '',
    this.extract,
  });
  @override
  State<SkillsTagsEditor> createState() => _SkillsTagsEditorState();
}

class _SkillsTagsEditorState extends State<SkillsTagsEditor>
    with WidgetsBindingObserver {
  final _manualFocus = FocusNode();
  final _manualArea = GlobalKey();
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _manualFocus.addListener(_revealManualInput);
  }

  void _revealManualInput() {
    if (!_manualFocus.hasFocus) return;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted &&
          _manualFocus.hasFocus &&
          _manualArea.currentContext != null) {
        Scrollable.ensureVisible(
          _manualArea.currentContext!,
          alignment: 0,
          duration: const Duration(milliseconds: 180),
        );
      }
    });
  }

  @override
  void didChangeMetrics() => _revealManualInput();
  final _experience = TextEditingController(), _tags = TextEditingController();
  List<String> _suggestions = [];
  bool _busy = false;
  String? _error;
  Future<List<String>> _extract(String text) async {
    if (widget.extract != null) return widget.extract!(text);
    final auth = context.read<AuthService?>();
    if (auth == null || !auth.isAuthenticated) throw StateError('Sign in');
    final user = auth.currentUser?.uid;
    final service = SyncService();
    try {
      final result = await service.request('/api/v1/profile/skills', {
        'role': widget.role,
        'pitch': widget.pitch,
        'description': text,
        'mode': 'extract',
      }, auth);
      if (!mounted ||
          user != auth.currentUser?.uid ||
          result['skills'] is! List) {
        throw const FormatException();
      }
      return SkillTags.parse(
        (result['skills'] as List).whereType<String>().join(','),
      );
    } finally {
      service.close();
    }
  }

  void _add(List<String> values) {
    try {
      final result = SkillTags.merge(widget.skills, values);
      widget.onChanged(result);
      setState(() {
        _error = null;
        _tags.clear();
      });
    } on FormatException catch (e) {
      setState(() => _error = e.message);
    }
  }

  Future<void> _voice() async {
    final auth = context.read<AuthService?>();
    final user = auth?.currentUser?.uid;
    final result = await showDialog<String>(
      context: context,
      barrierDismissible: false,
      builder: (_) => AiVoiceComposer(
        initialText: _experience.text,
        title: 'Turn experience into skills',
        applyLabel: 'Add these skills',
        organise: (text) async => (await _extract(text)).join(', '),
      ),
    );
    if (mounted && result != null && user == auth?.currentUser?.uid) {
      _add(SkillTags.parse(result));
    }
  }

  Future<void> _suggest() async {
    if (_experience.text.trim().isEmpty || _busy) return;
    final original = _experience.text;
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      final tags = await _extract(original);
      if (mounted && original == _experience.text) {
        setState(() => _suggestions = tags);
      }
    } catch (_) {
      if (mounted) {
        setState(
          () => _error =
              'Could not extract skills yet. Your description is kept. Try again, or add comma-separated tags below.',
        );
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _manualFocus.dispose();
    _experience.dispose();
    _tags.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.stretch,
    children: [
      const Text('Experience & specialties (optional)'),
      const SizedBox(height: 6),
      const Text(
        'Write a paragraph or speak. AI turns your description into short skill tags for you to review.',
      ),
      const SizedBox(height: 8),
      TextField(
        key: const ValueKey('skill-experience'),
        controller: _experience,
        minLines: 2,
        maxLines: 5,
        maxLength: 3000,
        readOnly: _busy,
        onChanged: (_) => setState(() {
          _suggestions = [];
          _error = null;
        }),
        decoration: InputDecoration(
          hintText: 'I repair pipes, fit bathrooms and create mobile apps…',
          border: const OutlineInputBorder(),
          suffixIcon: IconButton(
            tooltip: 'Speak with AI',
            onPressed: _busy ? null : _voice,
            icon: const AiMicrophoneIcon(),
          ),
        ),
      ),
      Align(
        alignment: Alignment.centerLeft,
        child: OutlinedButton.icon(
          onPressed: _busy ? null : _suggest,
          icon: const Icon(Icons.auto_awesome),
          label: Text(_busy ? 'Extracting…' : 'Extract skills'),
        ),
      ),
      if (_suggestions.isNotEmpty) ...[
        const Text('Suggested tags · tap to add or remove'),
        Wrap(
          spacing: 8,
          runSpacing: 4,
          children: _suggestions
              .map(
                (s) => FilterChip(
                  label: Text(s),
                  selected: widget.skills.contains(s),
                  onSelected: (selected) {
                    if (selected) {
                      _add([s]);
                    } else {
                      widget.onChanged(
                        widget.skills.where((v) => v != s).toList(),
                      );
                    }
                  },
                ),
              )
              .toList(),
        ),
      ],
      const SizedBox(height: 16),
      const Text('Skills & tags on your card'),
      if (widget.skills.isEmpty) const Text('No tags added yet.'),
      Wrap(
        spacing: 8,
        runSpacing: 4,
        children: widget.skills
            .map(
              (s) => InputChip(
                label: Text(s),
                onDeleted: () => widget.onChanged(
                  widget.skills.where((v) => v != s).toList(),
                ),
              ),
            )
            .toList(),
      ),
      const SizedBox(height: 12),
      Column(
        key: _manualArea,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const Text('Add tags manually · separate skills with commas'),
          const SizedBox(height: 8),
          TextField(
            key: const ValueKey('manual-skill-tags'),
            controller: _tags,
            focusNode: _manualFocus,
            textInputAction: TextInputAction.done,
            scrollPadding: const EdgeInsets.only(top: 40, bottom: 120),
            maxLength: 1000,
            maxLines: 2,
            decoration: const InputDecoration(
              hintText: 'Plumbing, Bathroom fitting, Android development',
              border: OutlineInputBorder(),
            ),
            onSubmitted: (_) => _addManual(),
          ),
          Align(
            alignment: Alignment.centerLeft,
            child: OutlinedButton.icon(
              onPressed: _addManual,
              icon: const Icon(Icons.add),
              label: const Text('Add tags'),
            ),
          ),
        ],
      ),
      Text(
        '${widget.skills.length}/12 tags · up to 50 characters per tag',
        style: Theme.of(context).textTheme.bodySmall,
      ),
      if (_error != null)
        Text(
          _error!,
          style: TextStyle(color: Theme.of(context).colorScheme.error),
        ),
    ],
  );
  void _addManual() {
    try {
      _add(SkillTags.parse(_tags.text));
      if (_error == null) FocusScope.of(context).unfocus();
    } on FormatException catch (e) {
      setState(() => _error = e.message);
    }
  }
}
