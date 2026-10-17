import 'package:flutter/material.dart';
import 'package:speech_to_text/speech_to_text.dart' as stt;
import '../models/saved_connection.dart';
import '../models/event_context.dart';
import 'package:uuid/uuid.dart';

class VoiceCaptureDialog extends StatefulWidget {
  final String? activeEventName;
  final Function(SavedConnection connection) onCaptured;

  const VoiceCaptureDialog({
    super.key,
    this.activeEventName,
    required this.onCaptured,
  });

  @override
  State<VoiceCaptureDialog> createState() => _VoiceCaptureDialogState();
}

class _VoiceCaptureDialogState extends State<VoiceCaptureDialog> {
  final stt.SpeechToText _speech = stt.SpeechToText();
  bool _isListening = false;
  bool _isAvailable = false;
  String _wordsSpoken = '';
  double _soundLevel = 0.0;

  // Parsed results
  String _extractedName = '';
  String _extractedRole = '';
  String _extractedEvent = '';
  List<String> _extractedSkills = [];
  String _extractedNotes = '';

  @override
  void initState() {
    super.initState();
    _initSpeech();
  }

  Future<void> _initSpeech() async {
    try {
      final available = await _speech.initialize(
        onError: (err) {
          if (mounted) {
            setState(() => _isListening = false);
          }
        },
        onStatus: (status) {
          if (mounted) {
            setState(() => _isListening = status == 'listening');
          }
        },
      );
      if (mounted) {
        setState(() => _isAvailable = available);
        if (available) {
          _startListening();
        }
      }
    } catch (_) {
      if (mounted) {
        setState(() => _isAvailable = false);
      }
    }
  }

  void _startListening() async {
    _wordsSpoken = '';
    await _speech.listen(
      onResult: (result) {
        if (mounted) {
          setState(() {
            _wordsSpoken = result.recognizedWords;
            _parseSpokenText(_wordsSpoken);
          });
        }
      },
      onSoundLevelChange: (level) {
        if (mounted) setState(() => _soundLevel = level);
      },
      listenOptions: stt.SpeechListenOptions(
        pauseFor: const Duration(seconds: 4),
        listenMode: stt.ListenMode.dictation,
      ),
    );
    setState(() => _isListening = true);
  }

  void _stopListening() async {
    await _speech.stop();
    setState(() => _isListening = false);
  }

  /// On-device zero-cost regex and heuristic parsing of spoken networking memos
  void _parseSpokenText(String text) {
    _extractedNotes = text;
    final lower = text.toLowerCase();

    // 1. Detect Event: look for "at [Event]" or "met at [Event]"
    final eventMatch = RegExp(r'(?:at|during|from)\s+([A-Za-z0-9\x27\s]+?)(?:,|\.|\bwho\b|\bhe\b|\bshe\b|\bthey\b|$)', caseSensitive: false)
        .firstMatch(text);
    if (eventMatch != null) {
      final candidate = eventMatch.group(1)?.trim() ?? '';
      if (candidate.length > 2 && !candidate.toLowerCase().startsWith('the ')) {
        _extractedEvent = candidate;
      }
    }
    if (_extractedEvent.isEmpty && widget.activeEventName != null) {
      _extractedEvent = widget.activeEventName!;
    }

    // 2. Detect Name: look for "met [Name]" or "this is [Name]" or "name is [Name]"
    final nameMatch = RegExp(r'(?:met|talking to|spoke with|name is|with)\s+([A-Z][a-z]+(?:\s+[A-Z][a-z]+)?)')
        .firstMatch(text);
    if (nameMatch != null) {
      _extractedName = nameMatch.group(1)?.trim() ?? '';
    } else {
      // First 2 capitalized words
      final capMatch = RegExp(r'\b([A-Z][a-z]+(?:\s+[A-Z][a-z]+)?)\b').firstMatch(text);
      if (capMatch != null) {
        _extractedName = capMatch.group(1)?.trim() ?? '';
      }
    }

    // 3. Detect Role / Title: "developer", "engineer", "architect", "designer", "founder"
    final roles = ['developer', 'engineer', 'architect', 'designer', 'founder', 'lead', 'manager', 'creator'];
    for (final r in roles) {
      if (lower.contains(r)) {
        // e.g. "mobile developer" or "flutter architect"
        final roleRegex = RegExp(r'(\b\w+\s+' + r + r'|\b' + r + r')', caseSensitive: false);
        final rm = roleRegex.firstMatch(text);
        if (rm != null) {
          _extractedRole = rm.group(1) ?? r;
          break;
        }
      }
    }

    // 4. Detect Skills / Tech Stack keywords
    final techKeywords = [
      'Flutter', 'Android', 'iOS', 'Dart', 'Kotlin', 'Swift', 'Firebase',
      'Cloudflare', 'React', 'Python', 'AI', 'LLM', 'Agents', 'Go', 'Rust',
      'Figma', 'TypeScript', 'Node', 'Backend', 'Frontend', 'Mobile'
    ];
    final foundSkills = <String>{};
    for (final tech in techKeywords) {
      if (lower.contains(tech.toLowerCase())) {
        foundSkills.add(tech);
      }
    }
    _extractedSkills = foundSkills.toList();
  }

  void _saveConnection() {
    final finalName = _extractedName.isNotEmpty ? _extractedName : 'Quick Contact';
    final finalEvent = _extractedEvent.isNotEmpty
        ? _extractedEvent
        : (widget.activeEventName ?? 'Networking Meetup');

    final conn = SavedConnection(
      id: const Uuid().v4(),
      fullName: finalName,
      role: _extractedRole,
      headline: _extractedSkills.isNotEmpty ? 'Works on ${_extractedSkills.join(', ')}' : '',
      techStack: _extractedSkills,
      eventContext: EventContext(
        eventName: finalEvent,
        date: DateTime.now(),
        notes: _extractedNotes,
        tags: _extractedSkills,
      ),
      savedAt: DateTime.now(),
    );

    widget.onCaptured(conn);
    Navigator.pop(context);
  }

  @override
  void dispose() {
    _speech.stop();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 420),
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Header
              Row(
                children: [
                  CircleAvatar(
                    backgroundColor: Colors.red.withValues(alpha: 0.12),
                    radius: 20,
                    child: const Icon(Icons.mic_rounded, color: Colors.red, size: 22),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          '5-Second Voice Memo',
                          style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                        ),
                        Text(
                          '100% on-device speech recognition & parsing',
                          style: TextStyle(fontSize: 11, color: theme.hintColor),
                        ),
                      ],
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.close),
                    onPressed: () => Navigator.pop(context),
                  ),
                ],
              ),

              const SizedBox(height: 20),

              // Animated Mic Pulse Indicator
              GestureDetector(
                onTap: () {
                  if (!_isAvailable) {
                    _initSpeech();
                    return;
                  }
                  if (_isListening) {
                    _stopListening();
                  } else {
                    _startListening();
                  }
                },
                child: Container(
                  width: 80,
                  height: 80,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: _isListening ? Colors.red : Colors.blue,
                    boxShadow: [
                      BoxShadow(
                        color: (_isListening ? Colors.red : Colors.blue).withValues(alpha: 0.3),
                        blurRadius: _isListening ? (16 + _soundLevel * 2) : 10,
                        spreadRadius: _isListening ? (4 + _soundLevel) : 2,
                      ),
                    ],
                  ),
                  child: Icon(
                    _isListening ? Icons.mic : Icons.mic_none,
                    color: Colors.white,
                    size: 40,
                  ),
                ),
              ),

              const SizedBox(height: 12),
              Text(
                !_isAvailable
                    ? 'Microphone / Speech service initializing...'
                    : _isListening
                        ? 'Listening... Speak details of who you met'
                        : 'Tap mic to start speaking',
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  color: _isListening ? Colors.red : theme.hintColor,
                ),
              ),

              const SizedBox(height: 16),

              // Spoken Transcript Box
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: theme.scaffoldBackgroundColor,
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(color: theme.dividerColor.withValues(alpha: 0.3)),
                ),
                child: Text(
                  _wordsSpoken.isNotEmpty
                      ? _wordsSpoken
                      : 'e.g. "Met Anit Singh at Cam\'s Tech Talk, he\'s a mobile architect building Flutter and Android apps..."',
                  style: TextStyle(
                    fontSize: 13,
                    fontStyle: _wordsSpoken.isEmpty ? FontStyle.italic : FontStyle.normal,
                    color: _wordsSpoken.isEmpty ? theme.hintColor : theme.textTheme.bodyMedium?.color,
                  ),
                  maxLines: 4,
                  overflow: TextOverflow.ellipsis,
                ),
              ),

              if (_extractedName.isNotEmpty || _extractedSkills.isNotEmpty) ...[
                const SizedBox(height: 14),
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.green.withValues(alpha: 0.08),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: Colors.green.withValues(alpha: 0.25)),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Row(
                        children: [
                          Icon(Icons.auto_awesome, size: 14, color: Colors.green),
                          SizedBox(width: 6),
                          Text('Auto-Extracted Context:', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 11, color: Colors.green)),
                        ],
                      ),
                      const SizedBox(height: 6),
                      if (_extractedName.isNotEmpty)
                        Text('Name: $_extractedName', style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600)),
                      if (_extractedRole.isNotEmpty)
                        Text('Role: $_extractedRole', style: const TextStyle(fontSize: 12)),
                      if (_extractedEvent.isNotEmpty)
                        Text('Event: $_extractedEvent', style: const TextStyle(fontSize: 12)),
                      if (_extractedSkills.isNotEmpty)
                        Text('Skills: ${_extractedSkills.join(', ')}', style: const TextStyle(fontSize: 12, color: Colors.blue)),
                    ],
                  ),
                ),
              ],

              const SizedBox(height: 20),

              Row(
                children: [
                  Expanded(
                    child: OutlinedButton(
                      onPressed: () => Navigator.pop(context),
                      child: const Text('Cancel'),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: ElevatedButton.icon(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.blue,
                        foregroundColor: Colors.white,
                      ),
                      icon: const Icon(Icons.check, size: 18),
                      label: const Text('Save Contact'),
                      onPressed: _wordsSpoken.isNotEmpty ? _saveConnection : null,
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
