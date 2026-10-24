import 'dart:async';
import '../services/nearby_card_service.dart';
import 'nearby_exchange_screen.dart';
import '../services/nfc_share_service.dart';
import 'contact_import_screen.dart';
import 'duplicate_contacts_screen.dart';
import 'card_scanner_screen.dart';
import '../widgets/face_avatar.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:mobile_scanner/mobile_scanner.dart';
import 'package:provider/provider.dart';
import '../models/saved_connection.dart';
import '../providers/cards_provider.dart';
import '../providers/connections_provider.dart';
import '../services/card_exchange_service.dart';
import '../widgets/voice_capture_dialog.dart';
import 'connection_detail_screen.dart';

class ReceiveCardScreen extends StatefulWidget {
  final bool enableCamera;
  const ReceiveCardScreen({super.key, this.enableCamera = true});
  @override
  State<ReceiveCardScreen> createState() => _ReceiveCardScreenState();
}

class _ReceiveCardScreenState extends State<ReceiveCardScreen>
    with WidgetsBindingObserver {
  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (!_scanning || _preview != null) return;
    if (state == AppLifecycleState.resumed &&
        ModalRoute.of(context)?.isCurrent == true) {
      _camera.start().catchError((Object _) {});
      unawaited(_listenNfc());
    } else if (state == AppLifecycleState.inactive) {
      _camera.stop().catchError((Object _) {});
      unawaited(_nfc.stopReceiving());
    }
  }

  final _text = TextEditingController();
  final _nfc = NfcShareService();
  bool _nfcListening = false;
  Future<void> _listenNfc() async {
    if (!widget.enableCamera ||
        !NfcShareService.supportedPlatform ||
        _nfcListening ||
        !mounted ||
        _preview != null) {
      return;
    }
    _nfcListening = true;
    try {
      final value = await _nfc.receive();
      if (mounted &&
          value != null &&
          ModalRoute.of(context)?.isCurrent == true) {
        await _decode(value);
      }
    } catch (_) {
      /* QR stays available when NFC is off, cancelled or unsupported. */
    } finally {
      _nfcListening = false;
    }
  }

  final _camera = MobileScannerController(
    autoStart: false,
    formats: [BarcodeFormat.qrCode],
  );
  bool _scanning = false, _busy = false;
  bool get _cameraSupported =>
      widget.enableCamera &&
      (kIsWeb ||
          ![
            TargetPlatform.linux,
            TargetPlatform.windows,
          ].contains(defaultTargetPlatform));
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _scanning = false;
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      if (!mounted || !_scanning) return;
      unawaited(_listenNfc());
      try {
        await _camera.start();
      } catch (_) {
        if (mounted) {
          setState(
            () => _error = 'Allow camera access to scan, or use More options.',
          );
        }
      }
    });
  }

  Future<void> _scanQr() async {
    if (!_cameraSupported) return;
    setState(() {
      _scanning = true;
      _error = '';
    });
    await WidgetsBinding.instance.endOfFrame;
    if (!mounted ||
        !_scanning ||
        !(ModalRoute.of(context)?.isCurrent ?? false)) {
      return;
    }
    try {
      await _camera.start();
    } catch (_) {
      if (mounted) {
        setState(
          () => _error =
              'Allow camera access, or paste a card from More options.',
        );
      }
    }
  }

  Future<void> _nearby() async {
    if (_scanning) {
      try {
        await _camera.stop();
      } catch (_) {}
    }
    await _nfc.stopReceiving();
    if (!mounted) return;
    setState(() => _scanning = false);
    await Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => const NearbyExchangeScreen()),
    );
  }

  String _error = '';
  SavedConnection? _preview;
  Future<void> _decode(String value) async {
    if (_busy || _preview != null) return;
    final event = context.read<CardsProvider>().activeEventMode;
    setState(() {
      _busy = true;
      _error = '';
    });
    try {
      final result = await CardExchangeService.decode(
        value,
        activeEvent: event,
      );
      if (_scanning) await _camera.stop();
      unawaited(_nfc.stopReceiving());
      if (mounted) {
        setState(() {
          _preview = result;
          _scanning = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(
          () => _error = e is FormatException
              ? e.message
              : 'Could not load this card. A contact QR works without internet.',
        );
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _save() async {
    final provider = context.read<ConnectionsProvider>();
    final preview = _preview!;
    final existing = provider.connections
        .where((c) => c.id == preview.id)
        .firstOrNull;
    setState(() => _busy = true);
    try {
      await provider.addConnection(preview);
      if (!mounted) return;
      final addCue = existing == null
          ? await showDialog<bool>(
              context: context,
              builder: (dialogContext) => AlertDialog(
                title: const Text('Saved to your wallet'),
                content: Text(
                  'What stood out about ${preview.fullName}? Speak or type a quick memory, or do it later.',
                ),
                actions: [
                  TextButton(
                    onPressed: () => Navigator.pop(dialogContext, false),
                    child: const Text('Later'),
                  ),
                  FilledButton(
                    onPressed: () => Navigator.pop(dialogContext, true),
                    child: const Text('Add a cue'),
                  ),
                ],
              ),
            )
          : false;
      if (!mounted) return;
      if (addCue == true) {
        await showDialog(
          context: context,
          builder: (_) => VoiceCaptureDialog(
            guided: true,
            connection: existing ?? preview,
            onCaptured: provider.updateConnection,
          ),
        );
      }
      if (!mounted) return;
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(
          builder: (_) => ConnectionDetailScreen(connectionId: preview.id),
        ),
      );
    } catch (_) {
      if (mounted) {
        setState(() {
          _busy = false;
          _error = 'Could not save. Please try again.';
        });
      }
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    unawaited(_nfc.stopReceiving());
    _text.dispose();
    _camera.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(
      title: const Text('Receive a card'),
      actions: [
        PopupMenuButton<String>(
          tooltip: 'More options',
          onSelected: (value) async {
            if (_nfcListening) await _nfc.stopReceiving();
            if (_scanning) {
              try {
                await _camera.stop();
              } catch (_) {}
            }
            if (!context.mounted) return;
            if (value == 'paste') {
              await showDialog<void>(
                context: context,
                builder: (dialogContext) => AlertDialog(
                  title: const Text('Paste a card link'),
                  content: TextField(
                    controller: _text,
                    maxLines: 3,
                    decoration: const InputDecoration(
                      hintText: 'Card link or contact text',
                    ),
                  ),
                  actions: [
                    TextButton(
                      onPressed: () => Navigator.pop(dialogContext),
                      child: const Text('Cancel'),
                    ),
                    FilledButton(
                      onPressed: () {
                        Navigator.pop(dialogContext);
                        _decode(_text.text);
                      },
                      child: const Text('Read card'),
                    ),
                  ],
                ),
              );
            } else {
              await Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => value == 'paper'
                      ? const CardScannerScreen()
                      : value == 'import'
                      ? const ContactImportScreen()
                      : const DuplicateContactsScreen(),
                ),
              );
            }
            if (mounted && _preview == null && _scanning) {
              unawaited(_listenNfc());
              try {
                await _camera.start();
              } catch (_) {}
            }
          },
          itemBuilder: (_) => const [
            PopupMenuItem(value: 'paste', child: Text('Paste card link')),
            PopupMenuItem(value: 'paper', child: Text('Scan paper card')),
            PopupMenuItem(value: 'import', child: Text('Import contacts')),
            PopupMenuItem(
              value: 'duplicates',
              child: Text('Review duplicates'),
            ),
          ],
        ),
      ],
    ),
    body: ListView(
      padding: const EdgeInsets.all(20),
      children: [
        if (_preview == null) ...[
          const Text('Choose how to receive. No internet needed.'),
          const SizedBox(height: 12),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              FilledButton.icon(
                onPressed: _cameraSupported ? _scanQr : null,
                icon: const Icon(Icons.qr_code_scanner),
                label: const Text('Scan QR'),
              ),
              OutlinedButton.icon(
                onPressed: NearbyCardService.supported ? _nearby : null,
                icon: const Icon(Icons.near_me_outlined),
                label: const Text('Nearby · iPhone'),
              ),
              if (NfcShareService.supportedPlatform)
                OutlinedButton.icon(
                  onPressed: () {
                    setState(
                      () => _error =
                          'Open Send by NFC on the other Android phone and hold the phones back to back.',
                    );
                    _listenNfc();
                  },
                  icon: const Icon(Icons.nfc),
                  label: const Text('Receive by NFC'),
                ),
            ],
          ),
          if (!NearbyCardService.supported)
            const Padding(
              padding: EdgeInsets.only(top: 8),
              child: Text(
                'Nearby exchange is available in the iPhone app. QR works across phones.',
                style: TextStyle(fontSize: 12),
              ),
            ),
        ],
        const SizedBox(height: 16),
        if (_preview == null) ...[
          if (_scanning)
            SizedBox(
              height: (MediaQuery.sizeOf(context).height - 200).clamp(
                240.0,
                520.0,
              ),
              child: MobileScanner(
                controller: _camera,
                onDetect: (capture) {
                  final value = capture.barcodes.firstOrNull?.rawValue;
                  if (value != null) _decode(value);
                },
                errorBuilder: (context, error) => const Center(
                  child: Text(
                    'Allow camera access, or use More options to paste a card link.',
                  ),
                ),
              ),
            ),
          if (!_cameraSupported)
            const Text('Use More options to paste a card link.'),
        ] else ...[
          Card(
            child: Padding(
              padding: const EdgeInsets.all(20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  FaceAvatar(
                    name: _preview!.fullName,
                    photo: _preview!.avatarUrl,
                    radius: 36,
                  ),
                  const SizedBox(height: 12),
                  Text(
                    _preview!.fullName,
                    style: Theme.of(context).textTheme.headlineSmall,
                  ),
                  Text('${_preview!.role} ${_preview!.company}'),
                  Text(_preview!.email),
                  Text(_preview!.phone),
                  Text(_preview!.techStack.join(' · ')),
                  Text('Met at: ${_preview!.eventContext.eventName}'),
                  for (final link in _preview!.links)
                    Text('${link.title}: ${link.url}'),
                ],
              ),
            ),
          ),
          FilledButton(
            onPressed: _busy ? null : _save,
            child: const Text('Save to my wallet'),
          ),
          TextButton(
            onPressed: _busy
                ? null
                : () {
                    setState(() {
                      _preview = null;
                      _scanning = _cameraSupported;
                    });
                    if (_scanning) _camera.start();
                  },
            child: const Text('Choose another card'),
          ),
        ],
        if (_error.isNotEmpty)
          Text(_error, style: const TextStyle(color: Colors.amber)),
      ],
    ),
  );
}
