import '../services/conversation_audio_activity.dart';
import '../services/conversation_screen_awake.dart';
import '../widgets/conversation_listening_indicator.dart';
import '../services/cloud_card_conversation_voice.dart';
import 'dart:async';
import 'dart:convert';
import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import '../models/contact_card.dart';
import '../services/card_conversation_voice.dart';
import '../services/profile_name_reply.dart';

/// One voice conversation drafts one card; account defaults are never edited here.
class ProfileQuestionnaire extends StatefulWidget {
  final String initialText,
      purpose,
      initialName,
      initialRole,
      applyLabel,
      profileName,
      initialBio;
  final CardCategory category;
  final bool understandReplies, briefConversation;
  final CardConversationVoice? voice;
  final Future<Map<String, dynamic>> Function(Map<String, String>) generate;
  const ProfileQuestionnaire({
    super.key,
    required this.generate,
    this.initialText = '',
    this.purpose = '',
    this.initialName = '',
    this.profileName = '',
    this.initialBio = '',
    this.initialRole = '',
    this.category = CardCategory.professional,
    this.voice,
    this.applyLabel = 'Create card',
    this.understandReplies = false,
    this.briefConversation = false,
  });
  @override
  State<ProfileQuestionnaire> createState() => _ProfileQuestionnaireState();
}

class _ProfileQuestionnaireState extends State<ProfileQuestionnaire>
    with WidgetsBindingObserver {
  static const _questions = [
    'What should we name your card?',
    'What is this card for?',
    'What name should appear on this card?',
    'What is your current role or job title?',
    'Tell me what you do and how you help people.',
    'Which skills or specialties should this card highlight? Tell me in your own words.',
    'Who would you like to connect with, and what can you help them with?',
  ];
  static const _labels = [
    'Card name',
    'Card purpose',
    'Your name',
    'Role',
    'Headline',
    'Skills',
    'Audience',
    'More about you',
    'Company',
  ];
  bool _purposeConfirmed = false, _identityConfirmed = false;
  final _screenAwake = ConversationScreenAwake();
  ConversationAudioPhase _audioPhase = ConversationAudioPhase.idle;
  bool get _detailsReady =>
      !widget.briefConversation || (_purposeConfirmed && _identityConfirmed);
  String _questionFor(int index) => index == 7
      ? 'What would you like More about you to say?'
      : index == 8
      ? 'Which company should appear on this card? You can also say no company.'
      : _questions[index];
  void _audioActivityChanged() {
    final phase =
        (_voice as ConversationAudioActivitySource).activity.value.phase;
    if (mounted && phase != _audioPhase) setState(() => _audioPhase = phase);
  }

  final _answers = List<String?>.filled(7, null);
  final _conversation = <Map<String, dynamic>>[];
  Map<String, dynamic>? _aiDraft, _understoodDraft;
  String? _nextQuestion;
  bool _confirmingProfileName = false, _showConversation = false;
  final _composer = TextEditingController();
  final _focus = FocusNode();
  final _scroll = ScrollController();
  late final CardConversationVoice _voice;
  Timer? _finishTimer, _restartTimer;
  int _listenSegment = 0;
  int _question = 0, _turn = 0;
  int? _editing;
  bool _voiceMode = false,
      _speaking = false,
      _listening = false,
      _busy = false,
      _initializing = true,
      _committing = false;
  String? _error;
  bool get _complete => _answers.every((a) => a != null);
  int get _answerIndex => _editing ?? _question;

  @override
  void initState() {
    super.initState();
    _voice = widget.voice ?? DeviceCardConversationVoice();
    _screenAwake.open();
    if (_voice is ConversationAudioActivitySource) {
      (_voice as ConversationAudioActivitySource).activity.addListener(
        _audioActivityChanged,
      );
    }
    if (widget.understandReplies && widget.profileName.trim().isNotEmpty) {
      _confirmingProfileName = true;
      _question = 2;
      _nextQuestion =
          'Your profile name is ${widget.profileName.trim()}. Would you like to use it on this card?';
    } else if (widget.briefConversation) {
      _question = 2;
      _nextQuestion = 'What name would you like on this card?';
    }
    WidgetsBinding.instance.addObserver(this);
    _focus.addListener(_typingStarted);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) unawaited(_startVoice());
    });
  }

  void _typingStarted() {
    if (_focus.hasFocus && _voiceMode) _pauseVoice();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if ([
      AppLifecycleState.paused,
      AppLifecycleState.hidden,
      AppLifecycleState.detached,
    ].contains(state)) {
      _pauseVoice();
    }
  }

  @override
  void dispose() {
    _screenAwake.close();
    if (_voice is ConversationAudioActivitySource) {
      (_voice as ConversationAudioActivitySource).activity.removeListener(
        _audioActivityChanged,
      );
    }
    WidgetsBinding.instance.removeObserver(this);
    _turn++;
    _finishTimer?.cancel();
    _restartTimer?.cancel();
    unawaited(_voice.dispose());
    _focus.removeListener(_typingStarted);
    _focus.dispose();
    _composer.dispose();
    _scroll.dispose();
    super.dispose();
  }

  void _scrollToEnd({bool review = false}) {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted && _scroll.hasClients) {
        _scroll.animateTo(
          review
              ? _scroll.position.minScrollExtent
              : _scroll.position.maxScrollExtent,
          duration: const Duration(milliseconds: 220),
          curve: Curves.easeOut,
        );
      }
    });
  }

  void _pauseVoice() {
    if (!mounted) return;
    if (!_busy) _turn++;
    _finishTimer?.cancel();
    _restartTimer?.cancel();
    setState(() {
      _voiceMode = false;
      _speaking = false;
      _listening = false;
      _initializing = false;
    });
    unawaited(_voice.stop());
  }

  Future<void> _startVoice() async {
    if (_busy || (_complete && _editing == null)) return;
    _focus.unfocus();
    final turn = ++_turn;
    setState(() {
      _initializing = true;
      _error = null;
    });
    final ready = await _voice.initialize();
    if (!mounted || turn != _turn) return;
    setState(() {
      _initializing = false;
      _voiceMode = ready;
    });
    if (!ready) {
      setState(
        () => _error = kIsWeb
            ? 'Voice is unavailable in this browser. Check microphone permission or try Chrome. You can also type below.'
            : 'Voice is unavailable. You can type your replies below.',
      );
      return;
    }
    await _askAndListen(keepReply: _composer.text.trim().isNotEmpty);
  }

  Future<void> _askAndListen({bool keepReply = false}) async {
    if (!mounted || !_voiceMode || _busy) return;
    final turn = ++_turn;
    _finishTimer?.cancel();
    _restartTimer?.cancel();
    _committing = false;
    setState(() {
      _speaking = true;
      _listening = false;
      _error = null;
    });
    try {
      await _voice.stop();
      if (!mounted || turn != _turn) return;
      await _voice.speak(
        _editing == null
            ? (_nextQuestion ?? _questions[_answerIndex])
            : _questionFor(_answerIndex),
      );
      if (!mounted || turn != _turn || !_voiceMode) return;
      if (!keepReply) _composer.clear();
      await _listenForReply(turn, prefix: _composer.text.trim());
    } catch (error) {
      _handleVoiceError(error, turn);
    }
  }

  Future<void> _listenForReply(int turn, {required String prefix}) async {
    if (!mounted || turn != _turn || !_voiceMode || _busy) return;
    final segment = ++_listenSegment;
    if (widget.briefConversation && _voice is CloudCardConversationVoice) {
      unawaited(
        _voice.prepareQuestions([
          if (_question == 2) 'Tell me what you do and how you help people.',
          if (_question == 1) 'Tell me what you do and how you help people.',
          if (_question == 4 || _question == 5)
            'Who would you like to connect with?',
          if (_question == 4)
            'What skills or specialties would you like to highlight?',
        ]),
      );
    }
    setState(() {
      _speaking = false;
      _listening = true;
    });
    if (_voice is! CloudCardConversationVoice &&
        prefix.isNotEmpty &&
        !(_finishTimer?.isActive ?? false)) {
      _scheduleReply(turn);
    }
    try {
      await _voice.listen(
        onResult: (text, finalResult) {
          if (!mounted ||
              turn != _turn ||
              segment != _listenSegment ||
              _committing) {
            return;
          }
          if (text.trim().isEmpty) return;
          _finishTimer?.cancel();
          final reply = [
            prefix,
            text.trim(),
          ].where((s) => s.isNotEmpty).join(' ');
          _composer.value = TextEditingValue(
            text: reply,
            selection: TextSelection.collapsed(offset: reply.length),
          );
          setState(() {});
          _scrollToEnd();
          if (finalResult && _voice is CloudCardConversationVoice) {
            unawaited(_submit());
          } else {
            _scheduleReply(turn);
          }
        },
        onDone: () {
          if (!mounted ||
              turn != _turn ||
              segment != _listenSegment ||
              _committing) {
            return;
          }
          // A platform can end one recognition segment before the user is finished.
          // Keep the silence deadline and reopen the microphone without replaying the question.
          _restartTimer?.cancel();
          _restartTimer = Timer(const Duration(milliseconds: 300), () {
            if (!mounted || turn != _turn || !_voiceMode || _committing) return;
            if (_finishTimer?.isActive ?? false) {
              unawaited(_listenForReply(turn, prefix: _composer.text.trim()));
            } else {
              _voiceFailed();
            }
          });
        },
        onError: (_) {
          if (mounted && turn == _turn && segment == _listenSegment) {
            _voiceFailed();
          }
        },
      );
    } catch (error) {
      _handleVoiceError(error, turn);
    }
  }

  void _handleVoiceError(Object error, int turn) {
    if (mounted && turn == _turn) {
      _voiceFailed();
      if (error is MaleVoiceUnavailable) {
        setState(
          () => _error = kIsWeb
              ? 'No supported English male voice is available in this browser. Try Chrome or enable an English male voice on your computer, then resume. You can also type below.'
              : 'Download an English male voice in iPhone Settings → Accessibility → Spoken Content → Voices, then resume. You can also type below.',
        );
      }
    }
  }

  void _voiceFailed() {
    _pauseVoice();
    setState(
      () => _error =
          'Voice paused. Your answers are kept. Resume or type a reply.',
    );
  }

  void _scheduleReply(int turn) {
    _finishTimer?.cancel();
    _finishTimer = Timer(const Duration(seconds: 3), () {
      if (!mounted || turn != _turn || _committing) return;
      if (_composer.text.trim().isEmpty) {
        _voiceFailed();
        return;
      }
      unawaited(_submit());
    });
  }

  Future<void> _submit() async {
    if (_busy || _committing || (_complete && _editing == null)) return;
    final answer = _composer.text.trim();
    final index = _answerIndex;
    final optionalCorrection =
        _aiDraft != null && _editing != null && [5, 7, 8].contains(index);
    if ((answer.isEmpty && !optionalCorrection) || answer.length > 1600) {
      _pauseVoice();
      setState(
        () => _error = answer.isEmpty
            ? 'Add a reply first.'
            : 'Please shorten this reply.',
      );
      return;
    }
    if (widget.understandReplies && _editing != null && _aiDraft != null) {
      _saveDraftCorrection(answer, index);
      return;
    }
    if (_confirmingProfileName && index == 2) {
      final reply = answer
          .toLowerCase()
          .replaceAll(RegExp(r"[,!.?]"), '')
          .trim();
      final useName = acceptsProfileName(answer);
      final anotherName = RegExp(
        r"^(no|no thanks|no thank you|use another name|another name|different name)$",
      ).hasMatch(reply);
      if ((useName && isOnlyProfileNameConfirmation(answer)) || anotherName) {
        await _confirmName(answer, useName);
        return;
      }
    }
    if (widget.understandReplies) {
      await _interpretReply(answer, index);
      return;
    }
    _committing = true;
    final keepTalking = _voiceMode;
    ++_turn;
    _finishTimer?.cancel();
    _restartTimer?.cancel();
    await _voice.stop();
    if (!mounted) return;
    setState(() {
      _answers[index] = answer;
      _editing = null;
      _composer.clear();
      _error = null;
      _speaking = false;
      _listening = false;
      _question = _answers.indexWhere((a) => a == null);
      if (_question < 0) _question = 6;
      _committing = false;
      if (_complete) _voiceMode = false;
    });
    _scrollToEnd();
    if (_complete) {
      if (keepTalking) await _speakReview();
    } else if (keepTalking) {
      await _askAndListen();
    }
  }

  Future<void> _confirmName(String reply, bool useProfile) async {
    final keepTalking = _voiceMode;
    ++_turn;
    _committing = true;
    _finishTimer?.cancel();
    _restartTimer?.cancel();
    await _voice.stop();
    if (!mounted) return;
    setState(() {
      _conversation.add({
        'field': 2,
        'question': _nextQuestion!,
        'answer': reply,
        'profileNameConfirmed': useProfile,
      });
      _answers[2] = useProfile ? widget.profileName.trim() : null;
      _confirmingProfileName = false;
      _question = useProfile ? (widget.briefConversation ? 4 : 0) : 2;
      _nextQuestion = useProfile
          ? (widget.briefConversation
                ? 'Tell me what you do and how you help people.'
                : null)
          : 'What name would you like on this card instead?';
      _composer.clear();
      _error = null;
      _speaking = false;
      _listening = false;
      _committing = false;
    });
    _scrollToEnd();
    if (keepTalking && _voiceMode) await _askAndListen();
  }

  void _saveDraftCorrection(String answer, int index) {
    final limit = index == 0
        ? 100
        : index == 4
        ? ContactCard.pitchLimit
        : index == 7
        ? 1200
        : index == 5
        ? 1000
        : 200;
    final skills = answer
        .split(RegExp(r'[,;\n]'))
        .map((s) => s.trim())
        .where((s) => s.isNotEmpty)
        .toSet()
        .toList();
    if (answer.length > limit ||
        (index == 5 &&
            (skills.length > 12 || skills.any((s) => s.length > 50)))) {
      setState(
        () => _error = index == 5
            ? 'Use up to 12 short skills, separated by commas.'
            : 'Please shorten this correction.',
      );
      return;
    }
    setState(() {
      if (index == 2) _identityConfirmed = false;
      if (index < _answers.length) _answers[index] = answer;
      if (index == 8) {
        _aiDraft!['company'] = answer;
        _identityConfirmed = false;
      } else if (index == 7) {
        _aiDraft!['bio'] = answer;
      } else if (index == 5) {
        _aiDraft!['skills'] = skills;
      } else {
        final key = {
          0: 'cardName',
          2: 'fullName',
          3: 'role',
          4: 'pitch',
        }[index];
        if (key != null) _aiDraft![key] = answer;
      }
      _editing = null;
      _composer.clear();
      _error = null;
    });
    _focus.unfocus();
  }

  Future<void> _interpretReply(String answer, int index) async {
    final keepTalking = _voiceMode;
    final turn = ++_turn;
    _finishTimer?.cancel();
    _restartTimer?.cancel();
    _committing = true;
    setState(() {
      _busy = true;
      _speaking = false;
      _listening = false;
      _error = null;
    });
    await _voice.stop();
    final conversation = [
      ..._conversation,
      {
        'field': index,
        'question': _editing == null
            ? (_nextQuestion ?? _questions[index])
            : _questions[index],
        'answer': answer,
        if (_confirmingProfileName) 'profileNameOffered': true,
      },
    ];
    try {
      final result = await widget.generate({
        'mode': 'conversation',
        if (widget.briefConversation) 'conversationStyle': 'brief',
        if (widget.briefConversation) 'conversationVersion': '3',
        if (widget.briefConversation && _understoodDraft != null)
          'previousDraft': jsonEncode(_understoodDraft),
        if (widget.briefConversation) 'defaultPurpose': widget.category.name,
        'conversation': jsonEncode(conversation),
        if (widget.initialBio.isNotEmpty) 'existingBio': widget.initialBio,
        if (widget.profileName.trim().isNotEmpty)
          'profileName': widget.profileName.trim(),
      });
      if (!mounted || turn != _turn) return;
      final answers = result['answers'], next = result['next'];
      if (answers is! List ||
          answers.length != 7 ||
          answers.any((a) => a != null && a is! String) ||
          next is! int ||
          next < -1 ||
          next > 6 ||
          (next == -1 && (answers.contains(null) || result['card'] is! Map)) ||
          (next >= 0 && result['question'] is! String)) {
        throw const FormatException();
      }
      setState(() {
        _conversation
          ..clear()
          ..addAll(conversation);
        for (var i = 0; i < 7; i++) {
          _answers[i] = answers[i] as String?;
        }
        if (result['context'] is Map) {
          _understoodDraft = Map<String, dynamic>.from(
            result['context'] as Map,
          );
        }
        _question = next < 0 ? 6 : next;
        _nextQuestion = next < 0 ? null : result['question'] as String;
        _aiDraft = next < 0
            ? {
                'bio': widget.initialBio,
                'company': '',
                ...Map<String, dynamic>.from(result['card'] as Map),
              }
            : null;
        _showConversation = false;
        _purposeConfirmed = false;
        _identityConfirmed = false;
        _editing = null;
        _confirmingProfileName = false;
        _composer.clear();
        _busy = false;
        _committing = false;
      });
      _scrollToEnd(review: _complete);
      if (_complete) {
        final speakReview = keepTalking && _voiceMode;
        setState(() => _voiceMode = false);
        if (speakReview) await _speakReview();
      } else if (keepTalking && _voiceMode) {
        await _askAndListen();
      }
    } catch (_) {
      if (mounted && turn == _turn) {
        setState(() {
          _busy = false;
          _committing = false;
          _voiceMode = false;
          _error =
              'Could not understand that reply. Your words are kept. Retry or rephrase, then send.';
        });
      }
    }
  }

  Future<void> _speakReview() async {
    final turn = ++_turn;
    setState(() => _speaking = true);
    try {
      await _voice.speak(
        widget.briefConversation
            ? 'Please confirm the name and company on your card, and choose its purpose below. You can edit any detail before saving.'
            : 'Your card is ready to review. Check the details, skills and introduction, then tap ${widget.applyLabel}.',
      );
    } catch (_) {
      /* Text review remains available. */
    }
    if (mounted && turn == _turn) setState(() => _speaking = false);
  }

  void _edit(int index) {
    _pauseVoice();
    setState(() {
      _editing = index;
      _composer.text = index == 8
          ? (_aiDraft?['company'] as String? ?? '')
          : index == 7
          ? (_aiDraft?['bio'] as String? ?? '')
          : index == 5 && _aiDraft != null
          ? (_aiDraft!['skills'] as List).join(', ')
          : _answers[index] ??
                _conversation.lastWhere(
                      (turn) => turn['field'] == index,
                    )['answer']
                    as String;
      _error = null;
    });
    _focus.requestFocus();
  }

  Future<void> _replay() async {
    _pauseVoice();
    final turn = _turn;
    setState(() => _speaking = true);
    try {
      await _voice.initialize();
      if (!mounted || turn != _turn) return;
      final lines = <String>[];
      for (var i = 0; i < _answers.length; i++) {
        if (_answers[i] != null) lines.add('${_questions[i]} ${_answers[i]}');
      }
      if (_aiDraft != null) {
        lines.add(
          'Exact skill tags: ${(_aiDraft!['skills'] as List).join(', ')}',
        );
        lines.add('More about you: ${_aiDraft!['bio'] ?? ''}');
      }
      await _voice.speak(lines.join('. '));
    } catch (_) {
      if (mounted && turn == _turn) {
        setState(
          () => _error =
              'Audio replay is unavailable. Your conversation is shown above.',
        );
      }
    }
    if (mounted && turn == _turn) setState(() => _speaking = false);
  }

  CardCategory get _category {
    final value = _answers[1]!.toLowerCase();
    if (value.contains('personal')) return CardCategory.personal;
    if (value.contains('project')) return CardCategory.sideProject;
    if (value.contains('event') || value.contains('conference')) {
      return CardCategory.event;
    }
    if (value.contains('professional') ||
        value.contains('work') ||
        value.contains('business')) {
      return CardCategory.professional;
    }
    return CardCategory.custom;
  }

  Future<void> _createCard() async {
    if (_busy || !_complete || _editing != null || !_detailsReady) return;
    _pauseVoice();
    final turn = ++_turn;
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      final draft =
          _aiDraft ??
          await widget.generate({
            'work': 'Role: ${_answers[3]}. ${_answers[4]}',
            'audience': _answers[6]!,
            'specialties': _answers[5]!,
          });
      if (!mounted || turn != _turn) return;
      final pitch = draft['pitch'], skills = draft['skills'];
      if (pitch is! String ||
          pitch.trim().isEmpty ||
          pitch.characters.length > ContactCard.pitchLimit ||
          skills is! List) {
        throw const FormatException();
      }
      Navigator.pop(context, {
        if (!widget.briefConversation)
          'cardName': draft['cardName'] ?? _answers[0]!,
        'category': draft['category'] ?? _category.name,
        'fullName': draft['fullName'] ?? _answers[2]!,
        'role': draft['role'] ?? _answers[3]!,
        'company': draft['company'] as String? ?? '',
        'pitch': pitch.trim(),
        'bio': draft['bio'] as String? ?? widget.initialBio,
        'skills': skills
            .whereType<String>()
            .map((s) => s.trim())
            .where((s) => s.isNotEmpty && s.length <= 50)
            .toSet()
            .take(12)
            .toList(),
        'createCard': true,
      });
    } catch (_) {
      if (mounted && turn == _turn) {
        setState(() {
          _busy = false;
          _error =
              'Could not create your card. Your answers are still here. Try again.';
        });
      }
    }
  }

  Widget _draftReview() {
    final draft = _aiDraft!;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text('Review your card', style: Theme.of(context).textTheme.titleLarge),
        const SizedBox(height: 6),
        const Text('These are the details that will be saved.'),
        const SizedBox(height: 16),
        if (!widget.briefConversation)
          _bubble('Card name: ${draft['cardName']}', answer: 0),
        _bubble('Your name: ${draft['fullName']}', answer: 2),
        _bubble(
          'Company: ${(draft['company'] as String?)?.isNotEmpty == true ? draft['company'] : 'No company'}',
          answer: 8,
        ),
        if (widget.briefConversation)
          CheckboxListTile(
            key: const ValueKey('confirm-card-identity'),
            value: _identityConfirmed,
            onChanged: _busy
                ? null
                : (value) =>
                      setState(() => _identityConfirmed = value ?? false),
            contentPadding: EdgeInsets.zero,
            controlAffinity: ListTileControlAffinity.leading,
            title: const Text('Use this name and company'),
          ),
        for (final i in [3, 4])
          _bubble(
            '${_labels[i]}: ${draft[{3: 'role', 4: 'pitch'}[i]]}',
            answer: i,
          ),
        Row(
          children: [
            Expanded(
              child: Text(
                'Skills & tags',
                style: Theme.of(context).textTheme.titleMedium,
              ),
            ),
            IconButton(
              tooltip: 'Edit Skills',
              onPressed: _busy ? null : () => _edit(5),
              icon: const Icon(Icons.edit_outlined, size: 18),
            ),
          ],
        ),
        Wrap(
          key: const ValueKey('draft-skill-tags'),
          spacing: 8,
          runSpacing: 4,
          children: (draft['skills'] as List)
              .whereType<String>()
              .map((skill) => Chip(label: Text(skill)))
              .toList(),
        ),
        if ((draft['skills'] as List).isEmpty)
          const Text('No skill tags selected.'),
        const SizedBox(height: 12),
        Row(
          children: [
            Expanded(
              child: Text(
                'More about you',
                style: Theme.of(context).textTheme.titleMedium,
              ),
            ),
            IconButton(
              tooltip: 'Edit More about you',
              onPressed: _busy ? null : () => _edit(7),
              icon: const Icon(Icons.edit_outlined, size: 18),
            ),
          ],
        ),
        _bubble(
          (draft['bio'] as String?)?.trim().isNotEmpty == true
              ? draft['bio'] as String
              : 'Not added',
        ),
        if (widget.briefConversation) ...[
          Text(
            'Card purpose · only you',
            style: Theme.of(context).textTheme.titleMedium,
          ),
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            runSpacing: 4,
            children: CardCategory.values
                .map(
                  (category) => ChoiceChip(
                    label: Text(category.displayName),
                    selected:
                        _purposeConfirmed && draft['category'] == category.name,
                    onSelected: _busy
                        ? null
                        : (_) => setState(() {
                            draft['category'] = category.name;
                            _purposeConfirmed = true;
                          }),
                  ),
                )
                .toList(),
          ),
          const SizedBox(height: 12),
        ],
        const SizedBox(height: 8),
        TextButton.icon(
          onPressed: _editing != null
              ? null
              : () => setState(() => _showConversation = true),
          icon: const Icon(Icons.chat_bubble_outline),
          label: const Text('View conversation'),
        ),
      ],
    );
  }

  Widget _bubble(String text, {bool user = false, int? answer}) => Align(
    alignment: user ? Alignment.centerRight : Alignment.centerLeft,
    child: Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Container(
        constraints: const BoxConstraints(maxWidth: 420),
        padding: const EdgeInsets.fromLTRB(12, 10, 8, 10),
        decoration: BoxDecoration(
          color: user ? const Color(0xFFEDE7FA) : Colors.white,
          border: Border.all(
            color: user ? const Color(0xFFD8CEEF) : const Color(0xFFE8E3ED),
          ),
          borderRadius: BorderRadius.circular(16),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Flexible(
              child: Text(
                text,
                style: const TextStyle(fontSize: 14, height: 1.4),
              ),
            ),
            if (answer != null)
              IconButton(
                tooltip: 'Edit ${_labels[answer]}',
                constraints: const BoxConstraints.tightFor(
                  width: 40,
                  height: 40,
                ),
                padding: const EdgeInsets.all(8),
                visualDensity: VisualDensity.compact,
                onPressed: _busy ? null : () => _edit(answer),
                icon: const Icon(Icons.edit_outlined, size: 16),
              ),
          ],
        ),
      ),
    ),
  );

  @override
  Widget build(BuildContext context) {
    final active = _speaking || _listening || _busy;
    final keyboardCompact =
        MediaQuery.viewInsetsOf(context).bottom > 0 &&
        MediaQuery.sizeOf(context).height < 700;
    final status = _audioPhase == ConversationAudioPhase.transcribing
        ? 'Transcribing your reply…'
        : _busy
        ? (_aiDraft == null && widget.understandReplies
              ? 'Understanding your reply…'
              : 'Creating your card…')
        : _initializing
        ? 'Starting voice…'
        : _speaking
        ? 'Acquenta is speaking…'
        : _listening
        ? 'Listening… Take your time, or tap send.'
        : _complete && _editing == null
        ? (widget.briefConversation && !_detailsReady
              ? 'Choose a purpose and confirm your name and company.'
              : widget.understandReplies
              ? 'Review your draft'
              : 'Review your answers')
        : 'Speak or type a reply';
    return PopScope(
      canPop: !_busy,
      child: Dialog(
        insetPadding: const EdgeInsets.all(12),
        child: LayoutBuilder(
          builder: (context, available) {
            // Insets animate: use actual space as well as the current keyboard state.
            final compact = keyboardCompact || available.maxHeight < 360;
            return ConstrainedBox(
              constraints: BoxConstraints(
                maxWidth: 560,
                maxHeight: math.min(
                  760,
                  MediaQuery.sizeOf(context).height * .9,
                ),
              ),
              child: Column(
                children: [
                  Padding(
                    padding: EdgeInsets.fromLTRB(
                      16,
                      compact ? 4 : 12,
                      8,
                      compact ? 4 : 8,
                    ),
                    child: Row(
                      children: [
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'Acquenta AI',
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: compact
                                    ? Theme.of(context).textTheme.titleMedium
                                    : Theme.of(context).textTheme.titleLarge,
                              ),
                              if (!compact)
                                const Text(
                                  'For this card only',
                                  style: TextStyle(
                                    fontSize: 12,
                                    color: Color(0xFF777080),
                                  ),
                                ),
                            ],
                          ),
                        ),
                        AnimatedContainer(
                          duration: MediaQuery.disableAnimationsOf(context)
                              ? Duration.zero
                              : const Duration(milliseconds: 200),
                          padding: const EdgeInsets.all(3),
                          decoration: BoxDecoration(
                            borderRadius: BorderRadius.circular(16),
                            boxShadow: active
                                ? [
                                    BoxShadow(
                                      color: const Color(
                                        0xFF8B75D5,
                                      ).withValues(alpha: .4),
                                      blurRadius: 14,
                                      spreadRadius: 2,
                                    ),
                                  ]
                                : [],
                          ),
                          child: ClipRRect(
                            borderRadius: BorderRadius.circular(12),
                            child: Image.asset(
                              'assets/branding/acquenta-icon-v3.png',
                              width: compact ? 32 : 44,
                              height: compact ? 32 : 44,
                              excludeFromSemantics: true,
                            ),
                          ),
                        ),
                        IconButton(
                          tooltip: 'Close',
                          onPressed: _busy
                              ? null
                              : () => Navigator.pop(context),
                          icon: const Icon(Icons.close),
                        ),
                      ],
                    ),
                  ),
                  const Divider(height: 1),
                  Expanded(
                    child: ListView(
                      key: const ValueKey('card-conversation'),
                      controller: _scroll,
                      padding: const EdgeInsets.all(12),
                      children: [
                        if (_aiDraft != null && _complete && !_showConversation)
                          _draftReview()
                        else ...[
                          if (widget.understandReplies) ...[
                            for (final turn in _conversation) ...[
                              _bubble(turn['question'] as String),
                              _bubble(turn['answer'] as String, user: true),
                            ],
                            if (!_complete)
                              _bubble(
                                _editing == null
                                    ? (_nextQuestion ?? _questions[_question])
                                    : _questionFor(_editing!),
                              ),
                          ] else
                            for (var i = 0; i < _answers.length; i++) ...[
                              if (_answers[i] != null ||
                                  i == _question && !_complete)
                                _bubble(_questions[i]),
                              if (_answers[i] != null)
                                _bubble(_answers[i]!, user: true, answer: i),
                            ],
                          if (_listening && _composer.text.isNotEmpty)
                            _bubble(_composer.text, user: true),
                          if (_aiDraft != null && _complete)
                            TextButton(
                              onPressed: () =>
                                  setState(() => _showConversation = false),
                              child: const Text('Back to card review'),
                            ),
                          if (_complete && _aiDraft == null)
                            _bubble(
                              'Review your answers, then ${widget.applyLabel.toLowerCase()}.',
                            ),
                        ],
                      ],
                    ),
                  ),
                  if (_confirmingProfileName && !_busy)
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 12),
                      child: Wrap(
                        spacing: 8,
                        children: [
                          ActionChip(
                            label: const Text('Use this name'),
                            onPressed: () {
                              _composer.text = 'Use this name';
                              unawaited(_submit());
                            },
                          ),
                          ActionChip(
                            label: const Text('Use another name'),
                            onPressed: () {
                              _composer.text = 'Use another name';
                              unawaited(_submit());
                            },
                          ),
                        ],
                      ),
                    ),
                  if (_voice is ConversationAudioActivitySource)
                    ConversationListeningIndicator(
                      source: _voice as ConversationAudioActivitySource,
                    ),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 12),
                    child: Row(
                      children: [
                        Expanded(
                          child: Semantics(
                            liveRegion: true,
                            child: Text(
                              compact && _error != null ? _error! : status,
                              maxLines: compact ? 1 : 2,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(
                                fontSize: 12,
                                color: Color(0xFF2563EB),
                              ),
                            ),
                          ),
                        ),
                        if (!kIsWeb && _answers.any((a) => a != null))
                          IconButton(
                            tooltip: 'Replay conversation',
                            onPressed: _busy ? null : _replay,
                            icon: const Icon(Icons.replay_rounded, size: 20),
                          ),
                        if (!_complete || _editing != null)
                          IconButton(
                            tooltip: _voiceMode || _speaking
                                ? 'Pause voice conversation'
                                : 'Resume voice conversation',
                            onPressed: _busy
                                ? null
                                : () {
                                    if (_voiceMode || _speaking) {
                                      _pauseVoice();
                                    } else {
                                      unawaited(_startVoice());
                                    }
                                  },
                            icon: Icon(
                              _voiceMode || _speaking
                                  ? Icons.pause_circle_outline
                                  : Icons.mic_none_rounded,
                            ),
                          ),
                      ],
                    ),
                  ),
                  if (_error != null && !compact)
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 12),
                      child: Text(
                        _error!,
                        style: TextStyle(
                          fontSize: 12,
                          color: Theme.of(context).colorScheme.error,
                        ),
                      ),
                    ),
                  if (!_complete || _editing != null)
                    Padding(
                      padding: const EdgeInsets.fromLTRB(12, 0, 12, 12),
                      child: TextField(
                        key: const ValueKey('conversation-reply'),
                        controller: _composer,
                        focusNode: _focus,
                        minLines: 1,
                        maxLines: compact ? 2 : 3,
                        readOnly: _busy,
                        textInputAction: TextInputAction.send,
                        onSubmitted: (_) => unawaited(_submit()),
                        scrollPadding: const EdgeInsets.only(bottom: 80),
                        decoration: InputDecoration(
                          hintText: _editing == null
                              ? 'Reply…'
                              : 'Edit ${_labels[_editing!].toLowerCase()}…',
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(20),
                          ),
                          suffixIcon: IconButton(
                            tooltip: _editing == null
                                ? 'Send reply'
                                : (widget.understandReplies
                                      ? 'Save correction'
                                      : 'Save answer'),
                            onPressed: _busy
                                ? null
                                : () => unawaited(_submit()),
                            icon: const Icon(Icons.arrow_upward_rounded),
                          ),
                        ),
                      ),
                    ),
                  if (_complete && _editing == null)
                    Padding(
                      padding: const EdgeInsets.fromLTRB(12, 0, 12, 12),
                      child: SizedBox(
                        width: double.infinity,
                        child: FilledButton.icon(
                          onPressed: _busy || !_detailsReady
                              ? null
                              : _createCard,
                          icon: _busy
                              ? const SizedBox(
                                  width: 16,
                                  height: 16,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                  ),
                                )
                              : const Icon(Icons.credit_card_rounded),
                          label: Text(_busy ? 'Creating…' : widget.applyLabel),
                        ),
                      ),
                    ),
                ],
              ),
            );
          },
        ),
      ),
    );
  }
}
