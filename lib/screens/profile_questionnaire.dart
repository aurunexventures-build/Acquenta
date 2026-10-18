import 'package:flutter/material.dart';
import '../widgets/voice_magic_bar.dart';
import '../widgets/card_text_field.dart';

/// Suggestions remain local to this dialog until the user explicitly applies them.
class ProfileQuestionnaire extends StatefulWidget {
  final String initialText;
  final String purpose;
  final Future<Map<String, dynamic>> Function(Map<String, String>) generate;
  const ProfileQuestionnaire({
    super.key,
    required this.generate,
    this.initialText = '',
    this.purpose = '',
  });

  @override
  State<ProfileQuestionnaire> createState() => _ProfileQuestionnaireState();
}

class _ProfileQuestionnaireState extends State<ProfileQuestionnaire> {
  final _form = GlobalKey<FormState>();
  final _work = TextEditingController();
  final _audience = TextEditingController();
  final _specialties = TextEditingController();
  final _role = TextEditingController();
  final _pitch = TextEditingController();
  List<String> _skills = [];
  bool _busy = false;
  bool _review = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _work.text = widget.initialText;
  }

  @override
  void dispose() {
    for (final controller in [_work, _audience, _specialties, _role, _pitch]) {
      controller.dispose();
    }
    super.dispose();
  }

  Future<void> _generate() async {
    if (!_form.currentState!.validate()) return;
    FocusScope.of(context).unfocus();
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      final draft = await widget.generate({
        'work': _work.text.trim(),
        'audience': _audience.text.trim(),
        'specialties': _specialties.text.trim(),
      });
      if (!mounted) return;
      final role = draft['role'];
      final pitch = draft['pitch'];
      final skills = draft['skills'];
      if (role is! String ||
          pitch is! String ||
          skills is! List ||
          role.length > 200 ||
          pitch.length > 300 ||
          pitch.trim().isEmpty) {
        throw const FormatException();
      }
      setState(() {
        _role.text = role.trim();
        _pitch.text = pitch.trim();
        _skills = skills
            .whereType<String>()
            .map((s) => s.trim())
            .where((s) => s.isNotEmpty && s.length <= 50)
            .toSet()
            .take(12)
            .toList();
        _review = true;
      });
    } catch (_) {
      if (mounted) {
        setState(
          () => _error =
              'Could not draft your card. Your answers are still here. Try again, or close and fill in your card yourself.',
        );
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Widget _field(
    TextEditingController controller,
    String label,
    int limit, {
    bool required = false,
    int lines = 2,
  }) => CardTextField(
    controller: controller,
    label: label,
    maxLength: limit,
    voiceEnabled: controller == _pitch,
    required: required,
    maxLines: lines,
  );

  @override
  Widget build(BuildContext context) => PopScope(
    canPop: !_busy,
    child: Dialog(
      insetPadding: const EdgeInsets.all(16),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 480),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Flexible(
              child: SingleChildScrollView(
                keyboardDismissBehavior:
                    ScrollViewKeyboardDismissBehavior.onDrag,
                padding: const EdgeInsets.fromLTRB(20, 20, 20, 8),
                child: Form(
                  key: _form,
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Text(
                        _review
                            ? 'Review your draft'
                            : 'Describe yourself once',
                        style: Theme.of(context).textTheme.titleLarge,
                      ),
                      const SizedBox(height: 12),
                      if (!_review) ...[
                        Text(
                          widget.purpose.isEmpty
                              ? 'Say what you do, who you help, and any skills you want on this card. One description is enough.'
                              : 'For your “${widget.purpose}” card: say what you do and any skills you want included. One description is enough.',
                        ),
                        const SizedBox(height: 16),
                        const Text('Your description *'),
                        const SizedBox(height: 8),
                        TextFormField(
                          controller: _work,
                          minLines: 2,
                          maxLines: 5,
                          maxLength: 2000,
                          readOnly: _busy,
                          scrollPadding: const EdgeInsets.only(
                            top: 32,
                            bottom: 100,
                          ),
                          validator: (v) => v == null || v.trim().isEmpty
                              ? 'Please add a few words.'
                              : null,
                          decoration: const InputDecoration(
                            hintText:
                                'Describe your role, work or interests in your own words.',
                            border: OutlineInputBorder(),
                          ),
                        ),
                        VoiceMagicBar(
                          controller: _work,
                          onMagic: _generate,
                          busy: _busy,
                          magicLabel: 'Draft my card',
                        ),
                      ] else ...[
                        const Text(
                          'Check your role, wording and skills. Your name and company stay unchanged.',
                        ),
                        _field(
                          _role,
                          'Role / job title *',
                          200,
                          required: true,
                          lines: 1,
                        ),
                        _field(_pitch, 'One-line pitch *', 300, required: true),
                        const Text('Skills & tags'),
                        const SizedBox(height: 8),
                        Wrap(
                          spacing: 8,
                          runSpacing: 4,
                          children: _skills
                              .map(
                                (skill) => InputChip(
                                  label: Text(skill),
                                  onDeleted: () =>
                                      setState(() => _skills.remove(skill)),
                                ),
                              )
                              .toList(),
                        ),
                      ],
                      if (_error != null)
                        Padding(
                          padding: const EdgeInsets.only(top: 12),
                          child: Text(
                            _error!,
                            style: TextStyle(
                              color: Theme.of(context).colorScheme.error,
                            ),
                          ),
                        ),
                    ],
                  ),
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(12, 4, 12, 12),
              child: Wrap(
                alignment: WrapAlignment.end,
                spacing: 8,
                runSpacing: 4,
                children: [
                  TextButton(
                    onPressed: _busy ? null : () => Navigator.pop(context),
                    child: const Text('Close'),
                  ),
                  if (_review)
                    TextButton(
                      onPressed: _busy
                          ? null
                          : () => setState(() => _review = false),
                      child: const Text('Edit description'),
                    ),
                  if (_review)
                    FilledButton(
                      onPressed: _busy
                          ? null
                          : () {
                              if (_form.currentState!.validate()) {
                                Navigator.pop(context, {
                                  'role': _role.text.trim(),
                                  'pitch': _pitch.text.trim(),
                                  'skills': _skills,
                                });
                              }
                            },
                      child: const Text('Use this draft'),
                    ),
                ],
              ),
            ),
          ],
        ),
      ),
    ),
  );
}
