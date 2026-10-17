import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:qr_flutter/qr_flutter.dart';
import 'package:share_plus/share_plus.dart';
import '../models/contact_card.dart';
import '../models/event_context.dart';
import '../services/vcard_service.dart';

class QrShareDialog extends StatefulWidget {
  final ContactCard card;
  final EventContext? defaultEventContext;

  const QrShareDialog({
    super.key,
    required this.card,
    this.defaultEventContext,
  });

  @override
  State<QrShareDialog> createState() => _QrShareDialogState();
}

class _QrShareDialogState extends State<QrShareDialog> {
  late bool _attachEvent;
  late TextEditingController _eventNameController;
  late TextEditingController _notesController;

  @override
  void initState() {
    super.initState();
    _attachEvent = widget.defaultEventContext != null;
    _eventNameController = TextEditingController(
      text: widget.defaultEventContext?.eventName ?? '',
    );
    _notesController = TextEditingController(
      text: widget.defaultEventContext?.notes ?? '',
    );
  }

  @override
  void dispose() {
    _eventNameController.dispose();
    _notesController.dispose();
    super.dispose();
  }

  EventContext? _getCurrentEventContext() {
    if (!_attachEvent || _eventNameController.text.trim().isEmpty) {
      return null;
    }
    return EventContext(
      eventName: _eventNameController.text.trim(),
      location: widget.defaultEventContext?.location ?? '',
      date: DateTime.now(),
      notes: _notesController.text.trim(),
      tags: widget.card.techStack,
    );
  }

  String _getVCardString() {
    return VCardService.generateVCard(
      card: widget.card,
      eventContext: _getCurrentEventContext(),
    );
  }

  Color _parseColor(String hex) {
    try {
      final clean = hex.replaceAll('#', '');
      return Color(int.parse('FF$clean', radix: 16));
    } catch (_) {
      return const Color(0xFF2563EB);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final accentColor = _parseColor(widget.card.themeColorHex);
    final vCardData = _getVCardString();

    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 420),
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Header
              Row(
                children: [
                  CircleAvatar(
                    backgroundColor: accentColor.withValues(alpha: 0.15),
                    radius: 20,
                    child: Icon(Icons.qr_code_rounded, color: accentColor, size: 22),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          widget.card.fullName,
                          style: theme.textTheme.titleMedium?.copyWith(
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        Text(
                          widget.card.title,
                          style: TextStyle(fontSize: 12, color: theme.hintColor),
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

              // QR Code Container
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(20),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.08),
                      blurRadius: 16,
                      offset: const Offset(0, 4),
                    ),
                  ],
                ),
                child: QrImageView(
                  data: vCardData,
                  version: QrVersions.auto,
                  size: 220.0,
                  eyeStyle: QrEyeStyle(
                    eyeShape: QrEyeShape.square,
                    color: accentColor,
                  ),
                  dataModuleStyle: const QrDataModuleStyle(
                    dataModuleShape: QrDataModuleShape.square,
                    color: Color(0xFF1E293B),
                  ),
                  errorCorrectionLevel: QrErrorCorrectLevel.M,
                ),
              ),

              const SizedBox(height: 16),
              Text(
                'Scan to save contact directly into Apple or Android Contacts',
                style: TextStyle(fontSize: 12, color: theme.hintColor),
                textAlign: TextAlign.center,
              ),

              const SizedBox(height: 16),
              const Divider(),

              // Event Context Stamping Section
              CheckboxListTile(
                value: _attachEvent,
                contentPadding: EdgeInsets.zero,
                dense: true,
                title: const Text(
                  'Attach Meeting Context to QR / Card',
                  style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
                ),
                subtitle: const Text(
                  'Embeds the event name and discussion topics in recipient\'s contact notes',
                  style: TextStyle(fontSize: 11),
                ),
                onChanged: (val) {
                  setState(() {
                    _attachEvent = val ?? false;
                  });
                },
              ),

              if (_attachEvent) ...[
                const SizedBox(height: 8),
                TextField(
                  controller: _eventNameController,
                  decoration: const InputDecoration(
                    labelText: 'Event / Meetup Name',
                    hintText: 'e.g. Cam\'s Tech Talk, Google I/O',
                    isDense: true,
                    prefixIcon: Icon(Icons.event, size: 18),
                    border: OutlineInputBorder(),
                  ),
                  onChanged: (_) => setState(() {}),
                ),
                const SizedBox(height: 8),
                TextField(
                  controller: _notesController,
                  maxLines: 2,
                  decoration: const InputDecoration(
                    labelText: 'Quick Topic / Discussion Note',
                    hintText: 'e.g. Discussed Flutter & Android side projects',
                    isDense: true,
                    prefixIcon: Icon(Icons.notes, size: 18),
                    border: OutlineInputBorder(),
                  ),
                  onChanged: (_) => setState(() {}),
                ),
              ],

              const SizedBox(height: 20),

              // Action Buttons
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton.icon(
                      icon: const Icon(Icons.copy, size: 16),
                      label: const Text('Copy vCard'),
                      onPressed: () {
                        Clipboard.setData(ClipboardData(text: vCardData));
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(
                            content: Text('vCard copied to clipboard!'),
                            duration: Duration(seconds: 2),
                          ),
                        );
                      },
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: ElevatedButton.icon(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: accentColor,
                        foregroundColor: Colors.white,
                      ),
                      icon: const Icon(Icons.share, size: 16),
                      label: const Text('Share'),
                      onPressed: () {
                        Share.share(
                          'Contact Card: ${widget.card.fullName} (${widget.card.title})\n'
                          '${widget.card.email.isNotEmpty ? "Email: ${widget.card.email}\n" : ""}'
                          '${widget.card.phone.isNotEmpty ? "Phone: ${widget.card.phone}\n" : ""}'
                          '${_attachEvent && _eventNameController.text.isNotEmpty ? "Met at: ${_eventNameController.text}\n" : ""}',
                          subject: '${widget.card.fullName}\'s Contact Card',
                        );
                      },
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
