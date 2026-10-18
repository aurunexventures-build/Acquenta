import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:file_picker/file_picker.dart';
import 'package:provider/provider.dart';
import '../models/saved_connection.dart';
import '../providers/connections_provider.dart';
import '../services/contact_import_service.dart';
import '../services/duplicate_service.dart';

class ContactImportScreen extends StatefulWidget {
  const ContactImportScreen({super.key});
  @override
  State<ContactImportScreen> createState() => _ContactImportScreenState();
}

class _ContactImportScreenState extends State<ContactImportScreen> {
  final _text = TextEditingController();
  ContactImportPreview? _preview;
  final Set<int> _selected = {};
  String _status = '';
  String? _scope;
  bool _busy = false;
  @override
  void dispose() {
    _text.dispose();
    super.dispose();
  }

  void _parse(String value) {
    try {
      final preview = ContactImportService.parse(value);
      final existing = context.read<ConnectionsProvider>().connections;
      final seen = [...existing];
      final selected = <int>{};
      for (var i = 0; i < preview.contacts.length; i++) {
        final c = preview.contacts[i];
        if (DuplicateService.matches(c, seen).isEmpty) selected.add(i);
        seen.add(c);
      }
      setState(() {
        _preview = preview;
        _selected
          ..clear()
          ..addAll(selected);
        _status = '';
      });
    } catch (e) {
      setState(
        () => _status = e is FormatException
            ? e.message
            : 'Could not read the file. Use UTF-8 CSV or vCard.',
      );
    }
  }

  Future<void> _pick() async {
    setState(() => _busy = true);
    try {
      final result = await FilePicker.platform.pickFiles(
        type: FileType.custom,
        allowedExtensions: ['csv', 'vcf'],
        withData: false,
        withReadStream: true,
      );
      if (!mounted || result == null) return;
      final file = result.files.single;
      if (file.size > 1000000 || file.readStream == null) {
        throw const FormatException(
          'Choose a readable file smaller than 1 MB.',
        );
      }
      final bytes = <int>[];
      await for (final chunk in file.readStream!) {
        if (bytes.length + chunk.length > 1000000) {
          throw const FormatException('Choose a file smaller than 1 MB.');
        }
        bytes.addAll(chunk);
      }
      if (mounted) _parse(utf8.decode(bytes));
    } catch (e) {
      if (mounted) {
        setState(
          () => _status = e is FormatException
              ? e.message
              : 'Could not open file. You can paste its contents instead.',
        );
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _merge(int index) async {
    final p = context.read<ConnectionsProvider>();
    final scope = p.walletScope;
    final incoming = _preview!.contacts[index];
    final matches = DuplicateService.matches(incoming, p.connections);
    final keep = await showDialog<SavedConnection>(
      context: context,
      builder: (ctx) => SimpleDialog(
        title: const Text('Merge into which contact?'),
        children: [
          const Padding(
            padding: EdgeInsets.all(16),
            child: Text(
              'Existing fields stay; other imported details are archived in private history. Source photo is excluded. Only one reminder remains active.',
            ),
          ),
          for (final c in matches)
            SimpleDialogOption(
              onPressed: () => Navigator.pop(ctx, c),
              child: Text('${c.fullName} · ${c.email} · ${c.company}'),
            ),
        ],
      ),
    );
    if (keep == null || !mounted || scope != p.walletScope) return;
    setState(() => _busy = true);
    try {
      await p.mergeIncoming(keep, incoming);
      if (mounted) {
        setState(() {
          _selected.remove(index);
          _status = 'Imported details merged into ${keep.fullName}.';
        });
      }
    } catch (_) {
      if (mounted) {
        setState(
          () => _status =
              'Could not merge. Review the contact again or keep your source file.',
        );
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _save() async {
    final p = context.read<ConnectionsProvider>();
    if (p.walletScope != _scope) {
      setState(() => _status = 'Account changed. Reopen import.');
      return;
    }
    setState(() => _busy = true);
    var added = 0, skipped = 0;
    try {
      for (final i in _selected.toList()..sort()) {
        if (p.walletScope != _scope) throw StateError('Account changed.');
        final c = _preview!.contacts[i];
        if (DuplicateService.matches(c, p.connections).isNotEmpty) {
          skipped++;
          continue;
        }
        await p.addConnection(c);
        added++;
      }
      if (mounted) {
        setState(() {
          _selected.clear();
          _status =
              '$added imported. $skipped possible duplicates skipped. Use Review duplicates to combine existing contacts.';
        });
      }
    } catch (_) {
      if (mounted) {
        setState(
          () => _status =
              '$added imported before the error. Local contacts are kept; retry safely.',
        );
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final p = context.watch<ConnectionsProvider>();
    _scope ??= p.walletScope;
    return Scaffold(
      appBar: AppBar(title: const Text('Import contacts')),
      body: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          const Text(
            'Choose a CSV or vCard export from your contacts app. Review before saving. Possible duplicates are skipped; your address book is never modified.',
          ),
          const SizedBox(height: 12),
          OutlinedButton.icon(
            onPressed: _busy ? null : _pick,
            icon: const Icon(Icons.upload_file),
            label: const Text('Choose CSV / vCard file'),
          ),
          TextField(
            controller: _text,
            minLines: 3,
            maxLines: 6,
            maxLength: 1000000,
            decoration: const InputDecoration(
              labelText: 'Or paste CSV / vCard text',
            ),
          ),
          TextButton(
            onPressed: _busy ? null : () => _parse(_text.text),
            child: const Text('Preview import'),
          ),
          if (_preview != null) ...[
            Text(
              '${_preview!.contacts.length} contacts found · ${_selected.length} selected',
            ),
            for (final warning in _preview!.warnings) Text(warning),
            for (var i = 0; i < _preview!.contacts.length; i++)
              CheckboxListTile(
                value: _selected.contains(i),
                onChanged: _busy
                    ? null
                    : (selected) => setState(() {
                        if (selected == true) {
                          _selected.add(i);
                        } else {
                          _selected.remove(i);
                        }
                      }),
                secondary:
                    DuplicateService.matches(
                      _preview!.contacts[i],
                      p.connections,
                    ).isEmpty
                    ? null
                    : IconButton(
                        tooltip: 'Review merge',
                        icon: const Icon(Icons.merge),
                        onPressed: _busy ? null : () => _merge(i),
                      ),
                title: Text(_preview!.contacts[i].fullName),
                subtitle: Text(
                  [
                    _preview!.contacts[i].email,
                    _preview!.contacts[i].phone,
                    if (DuplicateService.matches(
                      _preview!.contacts[i],
                      p.connections,
                    ).isNotEmpty)
                      'Possible duplicate — will be skipped',
                  ].where((s) => s.isNotEmpty).join(' · '),
                ),
              ),
            FilledButton(
              onPressed: _busy || _selected.isEmpty ? null : _save,
              child: Text(_busy ? 'Importing…' : 'Import selected'),
            ),
          ],
          if (_status.isNotEmpty) Text(_status),
        ],
      ),
    );
  }
}
