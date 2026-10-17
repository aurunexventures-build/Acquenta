import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import '../models/event_context.dart';
import '../providers/cards_provider.dart';
import '../providers/connections_provider.dart';
import '../widgets/contact_card_widget.dart';
import '../widgets/qr_share_dialog.dart';
import '../widgets/tag_chip.dart';
import 'card_editor_screen.dart';
import 'card_detail_screen.dart';
import 'add_connection_screen.dart';
import 'connection_detail_screen.dart';
import 'smart_search_screen.dart';
import '../widgets/voice_capture_dialog.dart';
import '../widgets/cloud_sync_dialog.dart';
import '../widgets/wallet_card_stack.dart';
import '../widgets/connections_wallet_stack.dart';
import 'onboarding_card_builder_screen.dart';
import '../services/auth_service.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  int _currentIndex = 0;

  void _showSetEventDialog(BuildContext context) {
    final cardsProvider = Provider.of<CardsProvider>(context, listen: false);
    final current = cardsProvider.activeEventMode;
    final eventNameController = TextEditingController(text: current?.eventName ?? '');
    final locationController = TextEditingController(text: current?.location ?? '');

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Row(
          children: [
            Icon(Icons.location_on_rounded, color: Colors.amber),
            SizedBox(width: 8),
            Text('Active Event Mode'),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Set the event you are currently attending. Every card you share or contact you save will automatically be stamped with this context!',
              style: TextStyle(fontSize: 12),
            ),
            const SizedBox(height: 14),
            TextField(
              controller: eventNameController,
              decoration: const InputDecoration(
                labelText: 'Event Name',
                hintText: 'e.g. Cam\'s Tech Talk, Google I/O',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 10),
            TextField(
              controller: locationController,
              decoration: const InputDecoration(
                labelText: 'Location / City',
                hintText: 'e.g. London, SF, Virtual',
                border: OutlineInputBorder(),
              ),
            ),
          ],
        ),
        actions: [
          if (current != null)
            TextButton(
              onPressed: () {
                cardsProvider.setActiveEventMode(null);
                Navigator.pop(ctx);
              },
              child: const Text('Turn Off', style: TextStyle(color: Colors.red)),
            ),
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () {
              final name = eventNameController.text.trim();
              if (name.isNotEmpty) {
                cardsProvider.setActiveEventMode(
                  EventContext(
                    eventName: name,
                    location: locationController.text.trim(),
                    date: DateTime.now(),
                  ),
                );
              }
              Navigator.pop(ctx);
            },
            child: const Text('Set Active'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: IndexedStack(
        index: _currentIndex,
        children: [
          TickerMode(enabled: _currentIndex == 0, child: _buildMyCardsTab(context)),
          TickerMode(enabled: _currentIndex == 1, child: _buildConnectionsTab(context)),
          TickerMode(enabled: _currentIndex == 2, child: const SmartSearchScreen()),
        ],
      ),
      bottomNavigationBar: NavigationBar(
        selectedIndex: _currentIndex,
        onDestinationSelected: (i) => setState(() => _currentIndex = i),
        destinations: const [
          NavigationDestination(
            icon: Icon(Icons.badge_outlined),
            selectedIcon: Icon(Icons.badge),
            label: 'My Cards',
          ),
          NavigationDestination(
            icon: Icon(Icons.people_outline),
            selectedIcon: Icon(Icons.people),
            label: 'Connections',
          ),
          NavigationDestination(
            icon: Icon(Icons.psychology_outlined),
            selectedIcon: Icon(Icons.psychology),
            label: 'Smart Recall',
          ),
        ],
      ),
    );
  }

  // --- TAB 1: MY CARDS (WALLET ARCHITECTURE) ---
  Widget _buildMyCardsTab(BuildContext context) {
    final cardsProvider = Provider.of<CardsProvider>(context);
    final cards = cardsProvider.cards;
    final activeEvent = cardsProvider.activeEventMode;

    return Scaffold(
      backgroundColor: const Color(0xFF0D0F12),
      appBar: AppBar(
        backgroundColor: const Color(0xFF0D0F12),
        elevation: 0,
        title: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(6),
              decoration: BoxDecoration(
                color: Colors.blueAccent.withValues(alpha: 0.15),
                borderRadius: BorderRadius.circular(10),
              ),
              child: const Icon(Icons.wallet_rounded, color: Colors.blueAccent, size: 18),
            ),
            const SizedBox(width: 10),
            const Text(
              'MetCue Wallet',
              style: TextStyle(
                fontWeight: FontWeight.w800,
                fontSize: 19,
                letterSpacing: -0.4,
                color: Colors.white,
              ),
            ),
          ],
        ),
        actions: [
          Consumer<AuthService>(
            builder: (context, auth, _) => IconButton(
              icon: Stack(
                clipBehavior: Clip.none,
                children: [
                  Icon(
                    auth.isAuthenticated ? Icons.cloud_done_rounded : Icons.cloud_queue_rounded,
                    color: auth.isAuthenticated ? Colors.blueAccent : Colors.white38,
                    size: 22,
                  ),
                  if (auth.isAuthenticated)
                    Positioned(
                      right: -1,
                      top: -1,
                      child: Container(
                        width: 7,
                        height: 7,
                        decoration: const BoxDecoration(
                          color: Colors.greenAccent,
                          shape: BoxShape.circle,
                        ),
                      ),
                    ),
                ],
              ),
              tooltip: auth.isAuthenticated ? 'Cloudflare Edge Sync (Online)' : 'Connect Cloud & Firebase',
              onPressed: () {
                showDialog(
                  context: context,
                  builder: (_) => const CloudSyncDialog(),
                );
              },
            ),
          ),
          IconButton(
            icon: const Icon(Icons.add_rounded, size: 24, color: Colors.white),
            tooltip: 'Craft New Card',
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => OnboardingCardBuilderScreen(
                    storageService: cardsProvider.storageService,
                  ),
                ),
              );
            },
          ),
        ],
      ),
      body: cardsProvider.isLoading
          ? const Center(child: CircularProgressIndicator(color: Colors.blueAccent))
          : Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // Minimalist Dynamic Island Event Pill
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 6),
                  child: InkWell(
                    onTap: () => _showSetEventDialog(context),
                    borderRadius: BorderRadius.circular(20),
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                      decoration: BoxDecoration(
                        color: activeEvent != null
                            ? Colors.amber.withValues(alpha: 0.12)
                            : Colors.white.withValues(alpha: 0.04),
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(
                          color: activeEvent != null
                              ? Colors.amber.withValues(alpha: 0.3)
                              : Colors.white.withValues(alpha: 0.08),
                        ),
                      ),
                      child: Row(
                        children: [
                          Icon(
                            activeEvent != null ? Icons.location_on_rounded : Icons.radar_rounded,
                            size: 14,
                            color: activeEvent != null ? Colors.amberAccent : Colors.white38,
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              activeEvent != null
                                  ? 'Active Event: ${activeEvent.eventName}'
                                  : 'Active Event Mode: Tap to stamp your event',
                              style: TextStyle(
                                fontSize: 11,
                                fontWeight: FontWeight.w600,
                                color: activeEvent != null ? Colors.amber : Colors.white60,
                              ),
                            ),
                          ),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                            decoration: BoxDecoration(
                              color: activeEvent != null
                                  ? Colors.amber.withValues(alpha: 0.2)
                                  : Colors.white.withValues(alpha: 0.08),
                              borderRadius: BorderRadius.circular(10),
                            ),
                            child: Text(
                              activeEvent != null ? 'ACTIVE' : 'OFF',
                              style: TextStyle(
                                fontSize: 9,
                                fontWeight: FontWeight.bold,
                                color: activeEvent != null ? Colors.amber : Colors.white38,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),

                // Interactive Wallet Card Stack
                Expanded(
                  child: WalletCardStack(
                    cards: cards,
                    activeEvent: activeEvent,
                    onAddNewCard: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) => OnboardingCardBuilderScreen(
                            storageService: cardsProvider.storageService,
                          ),
                        ),
                      );
                    },
                  ),
                ),
              ],
            ),
    );
  }

  // --- TAB 2: CONNECTIONS (ROLODEX) ---
  // --- TAB 2: CONNECTIONS (ROLODEX WALLET) ---
  Widget _buildConnectionsTab(BuildContext context) {
    final connProvider = Provider.of<ConnectionsProvider>(context);
    final connections = connProvider.connections;

    return Scaffold(
      backgroundColor: const Color(0xFF0D0F12),
      appBar: AppBar(
        backgroundColor: const Color(0xFF0D0F12),
        elevation: 0,
        title: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(6),
              decoration: BoxDecoration(
                color: Colors.purpleAccent.withValues(alpha: 0.15),
                borderRadius: BorderRadius.circular(10),
              ),
              child: const Icon(Icons.people_alt_rounded, color: Colors.purpleAccent, size: 18),
            ),
            const SizedBox(width: 10),
            Text(
              'Connections (${connections.length})',
              style: const TextStyle(
                fontWeight: FontWeight.w800,
                fontSize: 19,
                letterSpacing: -0.4,
                color: Colors.white,
              ),
            ),
          ],
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.mic_rounded, color: Colors.redAccent, size: 22),
            tooltip: '5-Second Voice Memo',
            onPressed: () {
              final activeEvent = Provider.of<CardsProvider>(context, listen: false).activeEventMode;
              showDialog(
                context: context,
                builder: (_) => VoiceCaptureDialog(
                  activeEventName: activeEvent?.eventName,
                  onCaptured: (conn) {
                    connProvider.addConnection(conn);
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text('Saved "${conn.fullName}" via Voice Memo!'),
                        action: SnackBarAction(
                          label: 'View',
                          onPressed: () {
                            Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (_) => ConnectionDetailScreen(connectionId: conn.id),
                              ),
                            );
                          },
                        ),
                      ),
                    );
                  },
                ),
              );
            },
          ),
          IconButton(
            icon: const Icon(Icons.person_add_rounded, color: Colors.white, size: 22),
            tooltip: 'Add Connection Met at Event',
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const AddConnectionScreen()),
              );
            },
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        icon: const Icon(Icons.mic_rounded, color: Colors.white, size: 20),
        label: const Text('Voice Memo', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 13)),
        backgroundColor: Colors.blueAccent,
        onPressed: () {
          final activeEvent = Provider.of<CardsProvider>(context, listen: false).activeEventMode;
          showDialog(
            context: context,
            builder: (_) => VoiceCaptureDialog(
              activeEventName: activeEvent?.eventName,
              onCaptured: (conn) {
                connProvider.addConnection(conn);
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text('Saved "${conn.fullName}" via Voice Memo!'),
                  ),
                );
              },
            ),
          );
        },
      ),
      body: connProvider.isLoading
          ? const Center(child: CircularProgressIndicator(color: Colors.blueAccent))
          : ConnectionsWalletStack(
              connections: connections,
              onAddConnection: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(builder: (_) => const AddConnectionScreen()),
                );
              },
            ),
    );
  }
}
