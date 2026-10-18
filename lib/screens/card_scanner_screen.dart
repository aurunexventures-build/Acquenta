import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:provider/provider.dart';
import 'package:uuid/uuid.dart';
import '../models/event_context.dart';
import '../models/saved_connection.dart';
import '../providers/cards_provider.dart';
import '../providers/connections_provider.dart';
import '../services/card_ocr_service.dart';
import '../services/contact_import_service.dart';
import '../services/duplicate_service.dart';
import 'connection_detail_screen.dart';

class CardScannerScreen extends StatefulWidget {
  final CardOcrService? service;
  const CardScannerScreen({super.key, this.service});
  @override
  State<CardScannerScreen> createState() => _CardScannerScreenState();
}

class _CardScannerScreenState extends State<CardScannerScreen> {
  final _name = TextEditingController(),
      _email = TextEditingController(),
      _phone = TextEditingController(),
      _company = TextEditingController(),
      _role = TextEditingController(),
      _raw = TextEditingController();
  bool _busy = false;
  String _status = '';
  String? _scope;
  @override
  void dispose() {
    for (final c in [_name, _email, _phone, _company, _role, _raw]) {
      c.dispose();
    }
    super.dispose();
  }

  Future<void> _scan(ImageSource source) async {
    setState(() => _busy = true);
    try {
      final photo = await ImagePicker().pickImage(
        source: source,
        maxWidth: 2000,
        imageQuality: 90,
      );
      if (photo == null) return;
      final text = await (widget.service ?? CardOcrService()).read(photo.path);
      if (!mounted) return;
      final fields = CardOcrService.extract(text);
      setState(() {
        _raw.text = text;
        _name.text = fields['fullName']!;
        _email.text = fields['email']!;
        _phone.text = fields['phone']!;
        _status = 'Review every field. OCR can misread names and numbers.';
      });
    } catch (e) {
      if (mounted) {
        setState(
          () => _status = e is FormatException
              ? e.message
              : 'Photo could not be read. Check camera/photo permission, retry, or type details.',
        );
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _save() async {
    final p = context.read<ConnectionsProvider>();
    if (p.walletScope != _scope) {
      setState(() => _status = 'Account changed. Reopen scanner.');
      return;
    }
    setState(() => _busy = true);
    try {
      final now = DateTime.now();
      final event = context.read<CardsProvider>().activeEventMode;
      final c = SavedConnection(
        id: const Uuid().v4(),
        fullName: _name.text.trim(),
        email: _email.text.trim(),
        phone: _phone.text.trim(),
        company: _company.text.trim(),
        role: _role.text.trim(),
        eventContext:
            (event ?? EventContext(eventName: 'Scanned card', date: now))
                .copyWith(notes: _raw.text.trim()),
        savedAt: now,
      );
      ContactImportService.validate(c);
      final matches = DuplicateService.matches(c, p.connections);
      if (matches.isNotEmpty) {
        final keep = await showDialog<SavedConnection>(
          context: context,
          builder: (ctx) => SimpleDialog(
            title: const Text('Review matching contact'),
            children: [
              const Padding(
                padding: EdgeInsets.all(16),
                child: Text(
                  'Merge reviewed details into an existing contact? Existing values stay; other details are saved in private history. The source photo is excluded.',
                ),
              ),
              for (final existing in matches)
                SimpleDialogOption(
                  onPressed: () => Navigator.pop(ctx, existing),
                  child: Text(
                    '${existing.fullName} · ${existing.email} · ${existing.company}',
                  ),
                ),
              SimpleDialogOption(
                onPressed: () => Navigator.pop(ctx),
                child: const Text('Cancel'),
              ),
            ],
          ),
        );
        if (keep == null || !mounted || p.walletScope != _scope) return;
        await p.mergeIncoming(keep, c);
        if (mounted) {
          Navigator.pushReplacement(
            context,
            MaterialPageRoute(
              builder: (_) => ConnectionDetailScreen(connectionId: keep.id),
            ),
          );
        }
        return;
      }
      await p.addConnection(c);
      if (mounted) {
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(
            builder: (_) => ConnectionDetailScreen(connectionId: c.id),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        setState(
          () => _status = e is FormatException
              ? e.message
              : 'Could not save. Your draft is still here.',
        );
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    _scope ??= context.read<ConnectionsProvider>().walletScope;
    return Scaffold(
      appBar: AppBar(title: const Text('Scan a business card')),
      body: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          const Text(
            'Text recognition runs on-device. Review before saving; the card photo is not uploaded. Latin-script cards are supported.',
          ),
          if (CardOcrService.supported)
            Wrap(
              spacing: 8,
              children: [
                OutlinedButton.icon(
                  onPressed: _busy ? null : () => _scan(ImageSource.camera),
                  icon: const Icon(Icons.camera_alt_outlined),
                  label: const Text('Take photo'),
                ),
                OutlinedButton.icon(
                  onPressed: _busy ? null : () => _scan(ImageSource.gallery),
                  icon: const Icon(Icons.photo_library_outlined),
                  label: const Text('Choose photo'),
                ),
              ],
            )
          else
            const Text(
              'Photo OCR is available in the Android and iPhone apps. Enter details below on this device.',
            ),
          for (final field in [
            (_name, 'Name'),
            (_email, 'Email'),
            (_phone, 'Phone'),
            (_company, 'Company'),
            (_role, 'Role'),
          ])
            TextField(
              controller: field.$1,
              maxLength: field.$2 == 'Name' ? 200 : 2000,
              decoration: InputDecoration(labelText: field.$2),
            ),
          TextField(
            controller: _raw,
            minLines: 3,
            maxLines: 7,
            maxLength: 6000,
            decoration: const InputDecoration(
              labelText: 'Extracted text / notes',
            ),
          ),
          FilledButton(
            onPressed: _busy ? null : _save,
            child: Text(_busy ? 'Working…' : 'Save reviewed contact'),
          ),
          if (_status.isNotEmpty) Text(_status),
        ],
      ),
    );
  }
}
