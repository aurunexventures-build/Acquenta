import 'dart:async';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:qr_flutter/qr_flutter.dart';
import 'package:share_plus/share_plus.dart';
import '../models/contact_card.dart';
import '../models/event_context.dart';
import '../services/auth_service.dart';
import '../services/sync_service.dart';
import '../services/vcard_service.dart';
import '../services/offline_card_share.dart';
import '../services/nfc_share_service.dart';
import '../services/nearby_card_service.dart';
import '../screens/nearby_exchange_screen.dart';

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

class _QrShareDialogState extends State<QrShareDialog>
    with WidgetsBindingObserver {
  final _service = SyncService();
  final _nfc = NfcShareService();
  bool _busy = false, _nfcActive = false, _attachEvent = false;
  String? _url;
  String _status = '', _availability = 'unsupported';
  Timer? _expiry;
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _nfc.availability().then((value) {
      if (mounted) setState(() => _availability = value);
    });
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state != AppLifecycleState.resumed && _nfcActive) {
      unawaited(_stopNfc());
    }
  }

  Future<void> _stopNfc() async {
    _expiry?.cancel();
    await _nfc.stop();
    if (mounted) setState(() => _nfcActive = false);
  }

  Future<void> _startNfc() async {
    if (_nfcActive) {
      await _stopNfc();
      return;
    }
    final available = await _nfc.availability();
    if (!mounted) return;
    if (available != 'available') {
      setState(
        () => _status = available == 'disabled'
            ? 'Turn on NFC in your phone settings, then try again.'
            : 'NFC sharing is unavailable. Use the QR or contact file.',
      );
      return;
    }
    try {
      await _nfc.start(
        VCardService.generateVCard(
          card: widget.card,
          eventContext: _attachEvent ? widget.defaultEventContext : null,
        ),
      );
      if (!mounted) {
        await _nfc.stop();
        return;
      }
      setState(() {
        _nfcActive = true;
        _status =
            'Open Receive card in Acquenta on the other Android phone, then hold the unlocked phones back to back. If it does not respond, use the QR.';
      });
      _expiry = Timer(const Duration(minutes: 2), () {
        _stopNfc();
        if (mounted) {
          setState(
            () => _status = 'NFC sharing ended. Start again or use the QR.',
          );
        }
      });
    } catch (_) {
      if (mounted) {
        setState(
          () => _status =
              'NFC could not start. Use the QR or send the contact file.',
        );
      }
    }
  }

  Future<void> _publish({bool revoke = false}) async {
    final auth = context.read<AuthService?>();
    if (auth == null || !auth.isAuthenticated) {
      setState(
        () => _status =
            'Sign in to create an online link. Offline sharing still works.',
      );
      return;
    }
    setState(() => _busy = true);
    try {
      final result = await _service.request(
        '/api/v1/cards/publish',
        revoke ? {'id': widget.card.id} : {'card': widget.card.toJson()},
        auth,
        method: revoke ? 'DELETE' : 'POST',
      );
      if (mounted) {
        setState(() {
          _url = revoke ? null : result['url'] as String;
          _status = revoke
              ? 'Online link revoked.'
              : 'Link created. Opening this link requires internet.';
        });
      }
    } catch (_) {
      if (mounted) {
        setState(
          () => _status =
              'Online sharing is unavailable. The offline QR and contact file still work.',
        );
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _expiry?.cancel();
    unawaited(_nfc.stop());
    _service.close();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final event = _attachEvent ? widget.defaultEventContext : null;
    final full = VCardService.generateVCard(
      card: widget.card,
      eventContext: event,
    );
    final qr = OfflineCardShare.qr(widget.card, event: event);
    final fits = utf8.encode(qr).length <= 2000;
    return Dialog(
      insetPadding: const EdgeInsets.all(16),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 420),
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Text(
                      'Send my card',
                      style: Theme.of(context).textTheme.titleLarge,
                    ),
                  ),
                  IconButton(
                    tooltip: 'Close',
                    onPressed: () => Navigator.pop(context),
                    icon: const Icon(Icons.close),
                  ),
                ],
              ),
              Text(
                widget.card.fullName,
                style: const TextStyle(fontWeight: FontWeight.w600),
              ),
              const SizedBox(height: 12),
              OutlinedButton.icon(
                onPressed: NearbyCardService.supported
                    ? () async {
                        await _stopNfc();
                        if (!context.mounted) return;
                        await Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (_) =>
                                NearbyExchangeScreen(card: widget.card),
                          ),
                        );
                      }
                    : null,
                icon: const Icon(Icons.near_me_outlined),
                label: const Text('Send nearby · iPhone'),
              ),
              if (!NearbyCardService.supported)
                const Text(
                  'Nearby exchange works in the iPhone app. This QR works offline here.',
                  textAlign: TextAlign.center,
                  style: TextStyle(fontSize: 11),
                ),
              const SizedBox(height: 16),
              if (fits)
                Center(
                  child: Container(
                    color: Colors.white,
                    padding: const EdgeInsets.all(12),
                    child: LayoutBuilder(
                      builder: (context, box) => QrImageView(
                        data: qr,
                        version: QrVersions.auto,
                        size: box.maxWidth.clamp(160.0, 224.0),
                        errorCorrectionLevel: QrErrorCorrectLevel.M,
                      ),
                    ),
                  ),
                )
              else
                const Padding(
                  padding: EdgeInsets.all(16),
                  child: Text(
                    'This contact is too large for a QR. Send the contact file below.',
                  ),
                ),
              const SizedBox(height: 12),
              const Text(
                'Scan to save. No internet needed.',
                textAlign: TextAlign.center,
              ),
              if (qr != full)
                const Padding(
                  padding: EdgeInsets.only(top: 6),
                  child: Text(
                    'QR contains basic contact details. The contact file includes the full card.',
                    textAlign: TextAlign.center,
                    style: TextStyle(fontSize: 12),
                  ),
                ),
              const SizedBox(height: 16),
              FilledButton.icon(
                onPressed: () async {
                  try {
                    final box = context.findRenderObject() as RenderBox?;
                    await VCardService.shareVCard(
                      card: widget.card,
                      eventContext: event,
                      sharePositionOrigin: box == null
                          ? null
                          : box.localToGlobal(Offset.zero) & box.size,
                    );
                  } catch (_) {
                    if (mounted) {
                      setState(
                        () => _status =
                            'Could not open sharing. You can still use the QR.',
                      );
                    }
                  }
                },
                icon: const Icon(Icons.ios_share),
                label: const Text('Send contact file'),
              ),
              const Text(
                'Choose a nearby sharing option on your phone.',
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 11),
              ),
              if (_availability != 'unsupported')
                OutlinedButton.icon(
                  onPressed: _startNfc,
                  icon: const Icon(Icons.nfc),
                  label: Text(
                    _nfcActive ? 'Stop NFC' : 'Send by NFC (Android)',
                  ),
                ),
              if (_status.isNotEmpty)
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 10),
                  child: Text(
                    _status,
                    style: TextStyle(
                      color: Theme.of(context).colorScheme.primary,
                    ),
                  ),
                ),
              ExpansionTile(
                tilePadding: EdgeInsets.zero,
                title: const Text('More sharing options'),
                children: [
                  if (widget.defaultEventContext != null)
                    CheckboxListTile(
                      value: _attachEvent,
                      onChanged: (value) =>
                          setState(() => _attachEvent = value ?? false),
                      title: Text(
                        'Include ${widget.defaultEventContext!.eventName}',
                      ),
                      subtitle: const Text('Also shares the event notes.'),
                      contentPadding: EdgeInsets.zero,
                    ),
                  TextButton.icon(
                    onPressed: () {
                      Clipboard.setData(ClipboardData(text: full));
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(content: Text('Contact copied.')),
                      );
                    },
                    icon: const Icon(Icons.copy),
                    label: const Text('Copy contact'),
                  ),
                  TextButton.icon(
                    onPressed: _busy ? null : () => _publish(),
                    icon: const Icon(Icons.link),
                    label: Text(
                      _busy ? 'Creating link…' : 'Create online link',
                    ),
                  ),
                  if (_url != null) ...[
                    SelectableText(_url!),
                    TextButton(
                      onPressed: () => Share.share(_url!),
                      child: const Text('Send online link'),
                    ),
                  ],
                  TextButton(
                    onPressed: _busy ? null : () => _publish(revoke: true),
                    child: const Text('Revoke online link'),
                  ),
                  const Text(
                    'Offline sharing sends contact details. Portraits and web links may load later when internet is available.',
                    style: TextStyle(fontSize: 11),
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
