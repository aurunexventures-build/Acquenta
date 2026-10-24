import 'dart:convert';
import 'dart:async';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:uuid/uuid.dart';
import '../models/saved_connection.dart';
import '../models/event_context.dart';
import '../services/auth_service.dart';
import '../services/sync_service.dart';
import 'photo_picker_tile.dart';
import 'voice_magic_bar.dart';

/// Capture once, organise once, review. Original words remain editable.
class VoiceCaptureDialog extends StatefulWidget {
  final String? activeEventName;
  final SavedConnection? connection;
  final SyncService? service;
  final bool guided, editOnly;
  final FutureOr<void> Function(SavedConnection connection) onCaptured;
  const VoiceCaptureDialog({
    super.key,
    this.activeEventName,
    this.connection,
    this.service,
    this.guided = false,
    this.editOnly = false,
    required this.onCaptured,
  });
  @override
  State<VoiceCaptureDialog> createState() => _VoiceCaptureDialogState();
}

class _VoiceCaptureDialogState extends State<VoiceCaptureDialog> {
  late final SyncService _service;
  final _raw = TextEditingController();
  final _answer = TextEditingController();
  final _turns = <Map<String, String>>[];
  String _question = '';
  String _normalise(String value) =>
      value.toLowerCase().replaceAll(RegExp(r'[^a-z0-9 ]'), '').trim();
  final Map<String, TextEditingController> _fields = {};
  bool _busy = false, _saving = false, _review = false;
  String _status = '', _photo = '';
  int _request = 0;
  static const _labels = {
    'fullName': 'Name',
    'eventName': 'Event',
    'role': 'Role',
    'company': 'Company',
    'summary': 'What you discussed',
    'skills': 'Skills / interests (comma separated)',
    'distinctiveMemory': 'What made them memorable?',
    'microContext': 'Where did you chat?',
    'futureSelfNote': 'Note to your future self',
    'vibeTags': 'Your impressions (comma separated)',
    'callWhen': 'Reach out when… (comma separated)',
  };
  @override
  void initState() {
    super.initState();
    _service = widget.service ?? SyncService();
    final c = widget.connection;
    final initial = <String, String>{
      'fullName': c?.fullName ?? '',
      'role': c?.role ?? '',
      'company': c?.company ?? '',
      'eventName': c?.eventContext.eventName ?? widget.activeEventName ?? '',
      'summary': c?.eventContext.notes ?? '',
      'skills': c?.techStack.join(', ') ?? '',
      'distinctiveMemory': c?.distinctiveMemory ?? '',
      'microContext': c?.microContext ?? '',
      'futureSelfNote': c?.futureSelfNote ?? '',
      'vibeTags': c?.vibeTags.join(', ') ?? '',
      'callWhen': c?.callWhen.join(', ') ?? '',
    };
    for (final key in _labels.keys) {
      _fields[key] = TextEditingController(text: initial[key]);
    }
    _raw.text = c?.rawCue ?? '';
    _photo = c?.avatarUrl ?? '';
    _review = widget.editOnly;
  }

  String _value(String key) => _fields[key]!.text.trim();
  List<String> _tags(String key) => _value(key)
      .split(',')
      .map((s) => s.trim())
      .where((s) => s.isNotEmpty)
      .toSet()
      .take(30)
      .toList();
  void _rawChanged(String value) {
    setState(() {
      if (!widget.editOnly) {
        _review = false;
        _turns.clear();
        _question = '';
      }
      _status = '';
    });
  }

  Future<void> _generate() async {
    final auth = context.read<AuthService?>();
    final raw = _raw.text.trim();
    if (raw.isEmpty) {
      setState(() => _status = 'Speak or type a few words first.');
      return;
    }
    if (auth == null || !auth.isAuthenticated) {
      setState(
        () =>
            _status = 'Sign in for AI. You can still save your original note.',
      );
      return;
    }
    final generation = ++_request, uid = auth.currentUser?.uid;
    setState(() {
      _busy = true;
      _status = '';
    });
    try {
      final contextNote = widget.guided && widget.connection != null
          ? jsonEncode({
              'person': {
                'name': widget.connection!.fullName,
                'role': widget.connection!.role,
                'company': widget.connection!.company,
                'skills': widget.connection!.techStack,
              },
              'memory': raw,
            })
          : raw;
      final data = await _service.generateCues(
        contextNote.length <= 6000 ? contextNote : raw,
        _value('eventName'),
        auth,
        conversation: _turns,
        askFollowUp: widget.guided,
      );
      if (!mounted ||
          generation != _request ||
          uid != auth.currentUser?.uid ||
          raw != _raw.text.trim()) {
        return;
      }
      final cues = Map<String, dynamic>.from(data['cues']);
      setState(() {
        for (final key in _fields.keys) {
          if (widget.connection != null &&
              ['fullName', 'role', 'company', 'skills'].contains(key)) {
            continue;
          }
          final value = cues[key];
          final rendered = value is List
              ? value.join(', ')
              : value is String
              ? value
              : '';
          if (rendered.isNotEmpty) _fields[key]!.text = rendered;
        }
        _review = true;
        final question = cues['followUpQuestion'] as String? ?? '';
        _question =
            widget.guided &&
                _turns.length < 3 &&
                !_turns.any(
                  (turn) =>
                      _normalise(turn['question'] ?? '') ==
                      _normalise(question),
                )
            ? question.trim()
            : '';
        _status = _question.isEmpty ? 'Your notes are ready to review.' : '';
      });
    } catch (_) {
      if (mounted) {
        setState(
          () => _status =
              'AI is unavailable. Your original note can still be saved.',
        );
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _reply() async {
    final answer = _answer.text.trim();
    if (_busy || answer.isEmpty || _question.isEmpty || _turns.length >= 3) {
      return;
    }
    setState(() {
      _turns.add({'question': _question, 'answer': answer});
      _question = '';
      _answer.clear();
    });
    await _generate();
  }

  Future<void> _save() async {
    if (!mounted) return;
    final raw = _raw.text.trim();
    if (_value('fullName').isEmpty) {
      setState(
        () => _status =
            'Add a name or memorable label, such as “Designer with yellow bag”.',
      );
      return;
    }
    if (raw.isEmpty && _value('summary').isEmpty) {
      setState(() => _status = 'Add at least one cue for your future self.');
      return;
    }
    final turns = _turns.isNotEmpty
        ? _turns
        : widget.connection?.cueConversation ?? <Map<String, String>>[];
    final now = DateTime.now(), original = widget.connection;
    final event =
        (original?.eventContext ?? EventContext(eventName: '', date: now))
            .copyWith(
              eventName: _value('eventName').isEmpty
                  ? 'Networking'
                  : _value('eventName'),
              notes: _value('summary').isEmpty ? raw : _value('summary'),
              tags: {
                ...?original?.eventContext.tags,
                ..._tags('skills'),
              }.toList(),
            );
    final draft =
        original ??
        SavedConnection(
          id: const Uuid().v4(),
          fullName: _value('fullName'),
          eventContext: event,
          savedAt: now,
        );
    final result = draft.copyWith(
      fullName: _value('fullName'),
      role: _value('role'),
      company: _value('company'),
      rawCue: raw,
      cueConversation: turns,
      avatarUrl: _photo,
      eventContext: event,
      techStack: original?.techStack ?? _tags('skills'),
      distinctiveMemory: _value('distinctiveMemory'),
      microContext: _value('microContext'),
      futureSelfNote: _value('futureSelfNote'),
      vibeTags: _tags('vibeTags'),
      callWhen: _tags('callWhen'),
      updatedAt: now,
    );
    setState(() => _saving = true);
    try {
      await widget.onCaptured(result);
      if (mounted) Navigator.pop(context);
    } catch (_) {
      if (mounted) {
        setState(() {
          _saving = false;
          _status =
              'Could not save. Your draft is still here. If this connection changed elsewhere, copy your words and reopen it.';
        });
      }
    }
  }

  @override
  void dispose() {
    _request++;
    if (widget.service == null) _service.close();
    _raw.dispose();
    _answer.dispose();
    for (final controller in _fields.values) {
      controller.dispose();
    }
    super.dispose();
  }

  Widget _field(String key) => Padding(
    padding: const EdgeInsets.only(bottom: 12),
    child: TextField(
      scrollPadding: const EdgeInsets.only(top: 24, bottom: 96),
      controller: _fields[key],
      maxLength: key == 'fullName'
          ? 200
          : key == 'eventName'
          ? 300
          : null,
      maxLines: ['summary', 'futureSelfNote', 'distinctiveMemory'].contains(key)
          ? 2
          : 1,
      decoration: InputDecoration(
        labelText: _labels[key],
        border: const OutlineInputBorder(),
      ),
    ),
  );
  @override
  Widget build(BuildContext context) => Dialog(
    insetPadding: const EdgeInsets.all(12),
    child: ConstrainedBox(
      constraints: const BoxConstraints(maxWidth: 540),
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    widget.editOnly
                        ? 'Edit your notes'
                        : widget.guided
                        ? 'Talk to Acquenta AI'
                        : 'Add a memory',
                    style: const TextStyle(
                      fontSize: 21,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
                IconButton(
                  tooltip: 'Close',
                  onPressed: _saving ? null : () => Navigator.pop(context),
                  icon: const Icon(Icons.close),
                ),
              ],
            ),
            if (widget.connection == null)
              _field('fullName')
            else
              Text(
                widget.connection!.fullName,
                style: const TextStyle(fontWeight: FontWeight.w600),
              ),
            const SizedBox(height: 12),
            if (widget.guided)
              Container(
                padding: const EdgeInsets.all(14),
                margin: const EdgeInsets.only(bottom: 12),
                decoration: BoxDecoration(
                  color: Theme.of(
                    context,
                  ).colorScheme.primary.withValues(alpha: .07),
                  borderRadius: BorderRadius.circular(14),
                ),
                child: Text(
                  'What would you like to remember about ${widget.connection?.fullName ?? 'this person'}? Tell me about your conversation.',
                ),
              ),
            TextField(
              controller: _raw,
              onChanged: _rawChanged,
              minLines: 3,
              maxLines: 5,
              maxLength: 6000,
              enabled: !_busy && !_saving,
              decoration: const InputDecoration(
                labelText: 'Say it in your own words',
                hintText: 'What do you want to remember?',
                border: OutlineInputBorder(),
              ),
            ),
            if (!widget.editOnly)
              VoiceMagicBar(
                merged: widget.guided,
                controller: _raw,
                onMagic: _generate,
                onChanged: _rawChanged,
                busy: _busy || _saving,
              ),
            if (widget.guided && !_review)
              TextButton.icon(
                onPressed: _busy || _saving ? null : _generate,
                icon: const Icon(Icons.arrow_forward),
                label: const Text('Continue'),
              ),
            if (widget.guided) ...[
              for (final turn in _turns) ...[
                Align(
                  alignment: Alignment.centerLeft,
                  child: Padding(
                    padding: const EdgeInsets.symmetric(vertical: 8),
                    child: Text(
                      turn['question'] ?? '',
                      style: const TextStyle(fontWeight: FontWeight.w600),
                    ),
                  ),
                ),
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Theme.of(
                      context,
                    ).colorScheme.primary.withValues(alpha: .07),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Text(turn['answer'] ?? ''),
                ),
              ],
              if (_question.isNotEmpty) ...[
                const SizedBox(height: 16),
                Text(
                  _question,
                  style: const TextStyle(fontWeight: FontWeight.w600),
                ),
                const SizedBox(height: 8),
                TextField(
                  controller: _answer,
                  enabled: !_busy && !_saving,
                  minLines: 1,
                  maxLines: 3,
                  maxLength: 2000,
                  decoration: const InputDecoration(
                    labelText: 'Your reply',
                    hintText: 'Speak or type your answer',
                  ),
                ),
                VoiceMagicBar(
                  controller: _answer,
                  onMagic: _reply,
                  busy: _busy || _saving,
                  merged: true,
                  magicLabel: 'Send reply',
                ),
                TextButton.icon(
                  onPressed: _busy || _saving ? null : _reply,
                  icon: const Icon(Icons.send_outlined),
                  label: const Text('Send reply'),
                ),
                TextButton(
                  onPressed: () => setState(() => _question = ''),
                  child: const Text('Skip · review notes'),
                ),
              ],
            ],
            if (_status.isNotEmpty)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 8),
                child: Text(_status),
              ),
            if (_review && (!widget.guided || _question.isEmpty)) ...[
              const SizedBox(height: 12),
              _field('summary'),
              ExpansionTile(
                title: const Text('More details'),
                children: [
                  for (final key in _labels.keys.where(
                    (key) =>
                        key != 'summary' &&
                        (widget.connection == null ||
                            ![
                              'fullName',
                              'role',
                              'company',
                              'skills',
                            ].contains(key)),
                  ))
                    _field(key),
                ],
              ),
            ],
            ExpansionTile(
              title: const Text('Photo & event'),
              children: [
                PhotoPickerTile(
                  photo: _photo,
                  name: _value('fullName'),
                  onChanged: (photo) => setState(() => _photo = photo),
                ),
                if (!_review) _field('eventName'),
              ],
            ),
            const SizedBox(height: 12),
            if (!widget.guided || _question.isEmpty)
              FilledButton(
                onPressed: _busy || _saving ? null : _save,
                child: Text(_saving ? 'Saving…' : 'Save'),
              ),
          ],
        ),
      ),
    ),
  );
}
