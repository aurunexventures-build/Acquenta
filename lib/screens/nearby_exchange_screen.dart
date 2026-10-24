import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import '../models/contact_card.dart';
import '../models/saved_connection.dart';
import '../providers/connections_provider.dart';
import '../services/nearby_card_service.dart';
import '../services/card_exchange_service.dart';
import '../services/vcard_service.dart';
import '../services/text_safety.dart';
import '../services/conversation_screen_awake.dart';

class NearbyExchangeScreen extends StatefulWidget {
  final ContactCard? card;
  final NearbyCardTransport? transport;
  const NearbyExchangeScreen({super.key, this.card, this.transport});
  @override
  State<NearbyExchangeScreen> createState() => _NearbyExchangeScreenState();
}

class _NearbyExchangeScreenState extends State<NearbyExchangeScreen>
    with WidgetsBindingObserver, SingleTickerProviderStateMixin {
  late final NearbyCardTransport _transport;
  late final AnimationController _flight;
  final _awake = ConversationScreenAwake();
  StreamSubscription<Map<String, dynamic>>? _subscription;
  final _peers = <String, String>{};
  String _phase = 'starting',
      _device = '',
      _code = '',
      _remote = '',
      _message = '';
  String? _scope;
  SavedConnection? _received;
  bool _busy = false, _confirmed = false;
  bool get _sending => widget.card != null;
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _transport = widget.transport ?? NearbyCardService();
    _flight = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 700),
    );
    _scope = context.read<ConnectionsProvider?>()?.walletScope;
    _subscription = _transport.events.listen(_event);
    WidgetsBinding.instance.addPostFrameCallback((_) => _start());
  }

  bool get _current =>
      mounted &&
      (_scope == null ||
          context.read<ConnectionsProvider?>()?.walletScope == _scope);
  Future<void> _start() async {
    if (!mounted) return;
    setState(() {
      _phase = 'starting';
      _peers.clear();
      _received = null;
      _confirmed = false;
      _message = '';
      _code = '';
      _busy = false;
    });
    _flight.reset();
    try {
      if (!await _transport.available()) {
        if (mounted) setState(() => _phase = 'unsupported');
        return;
      }
      final device = await _transport.start(_sending);
      if (!_current) {
        await _transport.stop();
        return;
      }
      _awake.open();
      setState(() {
        _device = device;
        _phase = 'searching';
      });
    } catch (_) {
      _failed(
        'Nearby sharing could not start. Allow nearby-device access, or use the QR.',
      );
    }
  }

  void _failed(String message) {
    if (!mounted) return;
    _awake.close();
    unawaited(_transport.stop());
    setState(() {
      _phase = 'error';
      _busy = false;
      _message = message;
    });
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if ([
          AppLifecycleState.paused,
          AppLifecycleState.hidden,
          AppLifecycleState.detached,
        ].contains(state) &&
        _phase != 'saved') {
      _failed('Sharing paused. Keep both apps open and try again.');
    }
  }

  void _event(Map<String, dynamic> value) {
    if (!_current) {
      unawaited(_transport.stop());
      return;
    }
    final type = value['type'];
    switch (type) {
      case 'found':
        if (_phase == 'searching') {
          setState(
            () => _peers[value['id'] as String] = value['name'] as String,
          );
        }
      case 'lost':
        setState(() => _peers.remove(value['id']));
      case 'incoming':
        setState(() {
          _phase = 'incoming';
          _remote = value['name'] as String;
        });
      case 'connecting':
        setState(() => _phase = 'connecting');
      case 'verification':
        setState(() {
          _phase = 'verify';
          _code = value['code'] as String;
          _remote = value['name'] as String;
        });
      case 'ready':
        setState(() {
          _phase = 'ready';
          _busy = false;
        });
      case 'sent':
        setState(() => _phase = 'waiting');
      case 'card':
        try {
          // Nearby accepts a bounded vCard only; it never follows a supplied web link.
          final result = CardExchangeService.parseVCard(
            value['card'] as String,
          );
          setState(() {
            _received = result;
            _phase = 'preview';
            _busy = false;
          });
        } catch (_) {
          unawaited(_transport.decline());
          _failed('That card could not be read. Ask them to use the QR.');
        }
      case 'saved':
        _awake.close();
        HapticFeedback.mediumImpact();
        setState(() => _phase = 'saved');
      case 'closed':
        if (_phase != 'saved') _failed('The other phone closed sharing.');
      case 'disconnected':
        if (_phase != 'saved') {
          _failed('The phones disconnected. Bring them closer and try again.');
        }
      case 'declined':
        _failed('The other person declined this exchange.');
      case 'timeout':
        _failed('Nearby sharing timed out. Try again with both apps open.');
      case 'paused':
        if (_phase != 'saved') {
          _failed('Sharing paused. Keep both apps open and retry.');
        }
      case 'error':
        _failed(
          'Nearby sharing was interrupted. Allow Local Network access and keep Bluetooth and Wi-Fi enabled.',
        );
    }
  }

  Future<void> _act(Future<void> Function() action) async {
    if (_busy || !_current) return;
    setState(() => _busy = true);
    try {
      await action();
    } catch (_) {
      _failed('Could not continue. Retry or use the offline QR.');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _send() async {
    if (_phase != 'ready' || !_sending) return;
    await _act(() async {
      TextSafety.validateFields(widget.card!.toJson());
      final payload = VCardService.generateVCard(
        card: widget.card!.copyWith(avatarUrl: ''),
      );
      await _transport.send(payload);
      if (!_current) return;
      setState(() => _phase = 'waiting');
      if (!mounted) return;
      if (MediaQuery.disableAnimationsOf(context)) {
        _flight.value = 1;
      } else {
        unawaited(_flight.forward());
      }
      HapticFeedback.selectionClick();
    });
  }

  Future<void> _save() async {
    if (_received == null || _phase != 'preview') return;
    await _act(() async {
      final provider = context.read<ConnectionsProvider>();
      if (provider.walletScope != _scope) throw StateError('Account changed');
      await provider.addConnection(_received!);
      if (!_current) return;
      // The sender gets success only after the local wallet write completes.
      try {
        await _transport.saved();
      } catch (_) {
        if (mounted) {
          setState(
            () => _message =
                'Saved here. The other phone may not have received the confirmation.',
          );
        }
      }
      _awake.close();
      setState(() => _phase = 'saved');
      if (!mounted) return;
      if (MediaQuery.disableAnimationsOf(context)) {
        _flight.value = 1;
      } else {
        unawaited(_flight.forward());
      }
      HapticFeedback.mediumImpact();
    });
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _awake.close();
    unawaited(_subscription?.cancel());
    unawaited(_transport.dispose());
    _flight.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final success = _phase == 'saved';
    final name = _sending
        ? widget.card!.fullName
        : _received?.fullName ?? 'Your next connection';
    final role = _sending ? widget.card!.role : _received?.role ?? '';
    final purple = Theme.of(context).colorScheme.primary;
    return Scaffold(
      appBar: AppBar(title: Text(_sending ? 'Send nearby' : 'Receive nearby')),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.all(24),
          children: [
            Text(
              success
                  ? (_sending
                        ? 'Saved in their wallet'
                        : 'Added to your wallet')
                  : _sending
                  ? 'A little closer. A new connection.'
                  : 'Ready for a new connection.',
              style: Theme.of(context).textTheme.headlineSmall,
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 8),
            Text(
              _phase == 'unsupported'
                  ? 'Nearby exchange is available in the iPhone app. Use the offline QR on this device.'
                  : 'No internet needed · Both people keep Acquenta open',
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 28),
            SizedBox(
              height: 180,
              child: Stack(
                alignment: Alignment.center,
                children: [
                  Icon(
                    success
                        ? Icons.check_circle_outline
                        : Icons.wallet_outlined,
                    size: 100,
                    color: purple.withValues(alpha: .18),
                  ),
                  AnimatedBuilder(
                    animation: _flight,
                    builder: (context, child) => Transform.translate(
                      offset: Offset(
                        0,
                        (_sending ? -150 : 150) * _flight.value,
                      ),
                      child: Transform.scale(
                        scale: 1 - .15 * _flight.value,
                        child: Opacity(
                          opacity: 1 - _flight.value,
                          child: child,
                        ),
                      ),
                    ),
                    child: Container(
                      key: const ValueKey('nearby-transfer-card'),
                      width: 280,
                      padding: const EdgeInsets.all(22),
                      decoration: BoxDecoration(
                        color: _sending
                            ? Color(
                                int.tryParse(
                                      widget.card!.themeColorHex.replaceFirst(
                                        '#',
                                        'FF',
                                      ),
                                      radix: 16,
                                    ) ??
                                    0xFF2563EB,
                              )
                            : purple,
                        borderRadius: BorderRadius.circular(22),
                        boxShadow: const [
                          BoxShadow(
                            color: Colors.black26,
                            blurRadius: 20,
                            offset: Offset(0, 10),
                          ),
                        ],
                      ),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Icon(
                            Icons.contact_page_outlined,
                            color: Colors.white,
                          ),
                          const SizedBox(height: 16),
                          Text(
                            name,
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 22,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          if (role.isNotEmpty)
                            Text(
                              role,
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(color: Colors.white70),
                            ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 20),
            if (_device.isNotEmpty)
              Text('This phone: $_device', textAlign: TextAlign.center),
            if (_phase == 'starting' || _phase == 'connecting')
              const Padding(
                padding: EdgeInsets.all(20),
                child: Center(child: CircularProgressIndicator()),
              ),
            if (_phase == 'searching') ...[
              const SizedBox(height: 16),
              Text(
                _sending
                    ? 'Ask them to open Receive → Nearby, then choose their phone.'
                    : 'Ask them to open Send → Nearby and choose this phone.',
                textAlign: TextAlign.center,
              ),
              if (_sending && _peers.isEmpty)
                const Padding(
                  padding: EdgeInsets.all(20),
                  child: Text(
                    'Looking for nearby iPhones…',
                    textAlign: TextAlign.center,
                  ),
                ),
              for (final peer in _peers.entries)
                ListTile(
                  leading: const Icon(Icons.phone_iphone),
                  title: Text(peer.value),
                  trailing: const Icon(Icons.chevron_right),
                  onTap: _busy
                      ? null
                      : () => _act(() => _transport.invite(peer.key)),
                ),
            ],
            if (_phase == 'incoming') ...[
              Text('$_remote wants to connect.', textAlign: TextAlign.center),
              FilledButton(
                onPressed: _busy
                    ? null
                    : () => _act(() => _transport.accept(true)),
                child: const Text('Connect'),
              ),
              TextButton(
                onPressed: _busy
                    ? null
                    : () => _act(() async {
                        await _transport.accept(false);
                        setState(() => _phase = 'searching');
                      }),
                child: const Text('Decline'),
              ),
            ],
            if (_phase == 'verify') ...[
              Text(
                _code,
                key: const ValueKey('nearby-verification-code'),
                textAlign: TextAlign.center,
                style: Theme.of(
                  context,
                ).textTheme.headlineLarge?.copyWith(letterSpacing: 8),
              ),
              const SizedBox(height: 12),
              const Text(
                'Check that both phones show this same code before continuing.',
                textAlign: TextAlign.center,
              ),
              FilledButton(
                onPressed: _busy || _confirmed
                    ? null
                    : () => _act(() async {
                        await _transport.confirm();
                        if (mounted) setState(() => _confirmed = true);
                      }),
                child: Text(
                  _confirmed
                      ? 'Waiting for their confirmation…'
                      : 'Codes match',
                ),
              ),
              TextButton(
                onPressed: () => _failed(
                  'Codes did not match. Try again with the correct phone.',
                ),
                child: const Text('Codes do not match'),
              ),
            ],
            if (_phase == 'ready' && _sending)
              GestureDetector(
                onVerticalDragEnd: (details) {
                  if ((details.primaryVelocity ?? 0) < -100) _send();
                },
                child: FilledButton.icon(
                  onPressed: _busy ? null : _send,
                  icon: const Icon(Icons.north_rounded),
                  label: const Text('Swipe up or tap to send'),
                ),
              ),
            if (_phase == 'ready' && !_sending)
              const Text(
                'Connected. Waiting for their card…',
                textAlign: TextAlign.center,
              ),
            if (_phase == 'waiting')
              const Text(
                'Card sent. Waiting for them to save it…',
                textAlign: TextAlign.center,
              ),
            if (_phase == 'preview') ...[
              Text(
                [
                  _received!.company,
                  _received!.email,
                  _received!.phone,
                  _received!.techStack.join(' · '),
                ].where((v) => v.isNotEmpty).join('\n'),
                textAlign: TextAlign.center,
              ),
              FilledButton(
                onPressed: _busy ? null : _save,
                child: Text(_busy ? 'Saving…' : 'Save to my wallet'),
              ),
              TextButton(
                onPressed: _busy
                    ? null
                    : () => _act(() async {
                        await _transport.decline();
                        _failed('Card declined. Nothing was added.');
                      }),
                child: const Text('Decline card'),
              ),
            ],
            if (_phase == 'error') ...[
              Text(_message, textAlign: TextAlign.center),
              FilledButton(onPressed: _start, child: const Text('Try again')),
            ],
            if (success) ...[
              if (_message.isNotEmpty) Text(_message),
              FilledButton(
                onPressed: () => Navigator.pop(context),
                child: const Text('Done'),
              ),
            ],
            if (!success)
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: const Text('Use QR instead'),
              ),
            const SizedBox(height: 12),
            const Text(
              'Only this card’s contact details are shared. Your private notes and other cards stay with you.',
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 12),
            ),
          ],
        ),
      ),
    );
  }
}
