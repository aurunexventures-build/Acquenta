import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../models/contact_card.dart';
import '../models/event_context.dart';
import '../providers/cards_provider.dart';
import '../providers/connections_provider.dart';
import '../widgets/qr_share_dialog.dart';
import '../widgets/visiting_card_deck.dart';
import '../widgets/wallet_free_slots.dart';
import '../widgets/connection_memory_button.dart';
import 'card_detail_screen.dart';
import 'connection_detail_screen.dart';
import 'onboarding_card_builder_screen.dart';
import 'receive_card_screen.dart';
import 'smart_search_screen.dart';
import 'account_profile_screen.dart';

const _ink = Color(0xFF202128);
const _paper = Color(0xFFF6F5F1);
const _purple = Color(0xFF6554C0);

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});
  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  int _tab = 0;
  int _lastWalletTab = 0;
  int get _walletTab => _tab == 2 ? _lastWalletTab : _tab;
  void _selectTab(int value) => setState(() {
    if (value != 2) _lastWalletTab = value;
    _tab = value;
  });
  void _lockedCard() => ScaffoldMessenger.of(context)
    ..clearSnackBars()
    ..showSnackBar(
      const SnackBar(
        persist: false,
        duration: Duration(seconds: 3),
        content: Text(
          'Free accounts can use up to five cards. Remove a card to unlock this one.',
        ),
      ),
    );
  String _filter = 'All';
  String _query = '';

  void _open(Widget screen) =>
      Navigator.push(context, MaterialPageRoute(builder: (_) => screen));
  void _newCard() {
    final cards = context.read<CardsProvider>();
    if (!cards.canCreateCard) {
      ScaffoldMessenger.of(context)
        ..clearSnackBars()
        ..showSnackBar(
          const SnackBar(
            duration: Duration(seconds: 4),
            persist: false,
            content: Text(
              'Your free plan includes 5 cards. Edit or remove a card to add another.',
            ),
          ),
        );
      return;
    }
    _open(OnboardingCardBuilderScreen(storageService: cards.storageService));
  }

  void _share(ContactCard card) => showDialog(
    context: context,
    builder: (_) => QrShareDialog(
      card: card,
      defaultEventContext: context.read<CardsProvider>().activeEventMode,
    ),
  );
  void _event() {
    final provider = context.read<CardsProvider>();
    final name = TextEditingController(
      text: provider.activeEventMode?.eventName,
    );
    final location = TextEditingController(
      text: provider.activeEventMode?.location,
    );
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Where are you meeting?'),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: name,
                decoration: const InputDecoration(labelText: 'Event'),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: location,
                decoration: const InputDecoration(labelText: 'Location'),
              ),
            ],
          ),
        ),
        actions: [
          if (provider.activeEventMode != null)
            TextButton(
              onPressed: () {
                provider.setActiveEventMode(null);
                Navigator.pop(ctx);
              },
              child: const Text('Clear'),
            ),
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () {
              if (name.text.trim().isNotEmpty) {
                provider.setActiveEventMode(
                  EventContext(
                    eventName: name.text.trim(),
                    location: location.text.trim(),
                    date: DateTime.now(),
                  ),
                );
              }
              Navigator.pop(ctx);
            },
            child: const Text('Save'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final cards = context.watch<CardsProvider>();
    final connections = context.watch<ConnectionsProvider>();
    final size = MediaQuery.sizeOf(context);
    final wide = size.width >= 1000 && size.height >= 600;
    final keyboard = MediaQuery.viewInsetsOf(context).bottom > 0;
    return Scaffold(
      backgroundColor: _paper,
      body: Row(
        children: [
          if (wide)
            _sidebar(cards.cards.length, connections.connections.length),
          Expanded(
            child: SafeArea(
              child: Column(
                children: [
                  if (_tab != 2 && (wide || !keyboard)) _topbar(wide),
                  Expanded(
                    child: IndexedStack(
                      index: _tab == 2 ? 1 : 0,
                      children: [
                        _workspace(cards, connections, wide),
                        TickerMode(
                          enabled: _tab == 2,
                          child: const SmartSearchScreen(),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
      floatingActionButton: _tab != 0 || keyboard
          ? null
          : FloatingActionButton.small(
              heroTag: 'create-card',
              tooltip: 'Create a card',
              backgroundColor: _purple,
              foregroundColor: Colors.white,
              onPressed: _newCard,
              child: const Icon(Icons.add_rounded),
            ),
      bottomNavigationBar: wide || keyboard
          ? null
          : NavigationBar(
              backgroundColor: Colors.white,
              indicatorColor: const Color(0xFFE8E3FA),
              selectedIndex: _tab,
              onDestinationSelected: _selectTab,
              labelTextStyle: WidgetStateProperty.all(
                const TextStyle(color: _ink, fontSize: 11),
              ),
              destinations: const [
                NavigationDestination(
                  icon: Icon(Icons.style_outlined, color: _ink),
                  selectedIcon: Icon(Icons.style_rounded, color: _purple),
                  label: 'My Cards',
                ),
                NavigationDestination(
                  icon: Icon(Icons.people_outline_rounded, color: _ink),
                  selectedIcon: Icon(Icons.people_rounded, color: _purple),
                  label: 'Connections',
                ),
                NavigationDestination(
                  icon: Icon(Icons.auto_awesome_outlined, color: _ink),
                  selectedIcon: Icon(Icons.auto_awesome, color: _purple),
                  label: 'Smart Recall',
                ),
              ],
            ),
    );
  }

  Widget _sidebar(int cards, int connections) => Container(
    width: 220,
    color: const Color(0xFF202128),
    child: SafeArea(
      child: Padding(
        padding: const EdgeInsets.all(22),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const SizedBox(height: 12),
            FittedBox(
              fit: BoxFit.scaleDown,
              alignment: Alignment.centerLeft,
              child: _brand(light: true),
            ),
            const SizedBox(height: 56),
            const Text(
              'YOUR SPACE',
              style: TextStyle(
                color: Color(0xFF96969F),
                fontSize: 10,
                letterSpacing: 2,
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 20),
            _nav(0, Icons.style_outlined, 'My cards', '$cards'),
            _nav(
              1,
              Icons.people_outline_rounded,
              'Connections',
              '$connections',
            ),
            _nav(2, Icons.auto_awesome_outlined, 'Smart recall', ''),
            const Spacer(),
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: const Color(0xFF303139),
                borderRadius: BorderRadius.circular(18),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Icon(
                    Icons.qr_code_scanner_rounded,
                    color: Color(0xFFD8F397),
                    size: 28,
                  ),
                  const SizedBox(height: 14),
                  const Text(
                    'A hello worth keeping.',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                      color: Colors.white,
                    ),
                  ),
                  const SizedBox(height: 14),
                  SizedBox(
                    width: double.infinity,
                    child: FilledButton(
                      onPressed: () => _open(const ReceiveCardScreen()),
                      style: FilledButton.styleFrom(
                        backgroundColor: const Color(0xFFD8F397),
                        foregroundColor: _ink,
                      ),
                      child: const Text('Scan a card'),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 22),
            const Row(
              children: [
                Icon(Icons.circle, color: Color(0xFFD8F397), size: 6),
                SizedBox(width: 8),
                Expanded(
                  child: Text(
                    'Made for real connections',
                    style: TextStyle(color: Colors.white54, fontSize: 10),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    ),
  );

  Widget _nav(int index, IconData icon, String title, String count) => Padding(
    padding: const EdgeInsets.only(bottom: 8),
    child: Material(
      color: _tab == index ? const Color(0xFF3D3B49) : Colors.transparent,
      borderRadius: BorderRadius.circular(12),
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: () => _selectTab(index),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 15),
          child: Row(
            children: [
              Icon(
                icon,
                size: 19,
                color: _tab == index ? const Color(0xFFD8F397) : Colors.white54,
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  title,
                  style: TextStyle(
                    fontSize: 13,
                    color: _tab == index ? Colors.white : Colors.white60,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ),
              Text(
                count,
                style: const TextStyle(color: Colors.white38, fontSize: 11),
              ),
            ],
          ),
        ),
      ),
    ),
  );

  Widget _brand({bool light = false}) => Row(
    mainAxisSize: MainAxisSize.min,
    children: [
      Container(
        width: 32,
        height: 32,
        decoration: BoxDecoration(
          color: light ? const Color(0xFFD8F397) : _purple,
          borderRadius: BorderRadius.circular(10),
        ),
        clipBehavior: Clip.antiAlias,
        child: Image.asset(
          'assets/branding/acquenta-icon-v3.png',
          fit: BoxFit.cover,
          excludeFromSemantics: true,
        ),
      ),
      const SizedBox(width: 10),
      Text(
        'Acquenta',
        style: TextStyle(
          color: light ? Colors.white : _ink,
          fontSize: 22,
          fontWeight: FontWeight.w800,
          letterSpacing: -1.2,
        ),
      ),
    ],
  );

  Widget _topbar(bool wide) {
    return Container(
      height: wide ? 78 : 64,
      padding: EdgeInsets.symmetric(horizontal: wide ? 36 : 20),
      decoration: const BoxDecoration(
        border: Border(bottom: BorderSide(color: Color(0xFFE5E4DF))),
      ),
      child: Row(
        children: [
          if (!wide)
            Flexible(
              child: FittedBox(
                fit: BoxFit.scaleDown,
                alignment: Alignment.centerLeft,
                child: _brand(),
              ),
            )
          else
            Text(
              [
                'Your identity, beautifully shared.',
                'Your people, a little closer.',
                'A thought away.',
              ][_tab],
              style: const TextStyle(color: Color(0xFF777780), fontSize: 13),
            ),
          const Spacer(),
          IconButton(
            tooltip: 'Event',
            onPressed: _event,
            icon: const Icon(Icons.event_outlined, color: _ink, size: 21),
          ),
          const SizedBox(width: 8),
          IconButton(
            tooltip: 'Your account',
            onPressed: () => _open(const AccountProfileScreen()),
            icon: const CircleAvatar(
              radius: 17,
              backgroundColor: Color(0xFFEAE5F8),
              child: Icon(
                Icons.person_outline_rounded,
                color: _purple,
                size: 19,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _workspace(
    CardsProvider cards,
    ConnectionsProvider people,
    bool wide,
  ) => SingleChildScrollView(
    key: PageStorageKey('wallet-tab-$_walletTab'),
    keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
    padding: EdgeInsets.fromLTRB(wide ? 36 : 20, 16, wide ? 36 : 20, 88),
    child: Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 1240),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (wide) ...[
              _hero(cards, people, wide),
              const SizedBox(height: 30),
            ],
            SizedBox(
              key: const ValueKey('wallet-heading'),
              width: double.infinity,
              child: Row(
                children: [
                  Expanded(
                    child: Text(
                      _walletTab == 0 ? 'My cards' : 'Connections',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        color: _ink,
                        fontSize: 22,
                        fontWeight: FontWeight.w700,
                        letterSpacing: -.6,
                      ),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 9,
                      vertical: 4,
                    ),
                    decoration: BoxDecoration(
                      color: const Color(0xFFE8E5DF),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Text(
                      '${_walletTab == 0 ? cards.cards.length : people.connections.length}',
                      style: const TextStyle(color: _ink, fontSize: 11),
                    ),
                  ),
                  IconButton(
                    tooltip: 'Receive a card',
                    onPressed: () => _open(const ReceiveCardScreen()),
                    icon: const Icon(
                      Icons.qr_code_scanner_rounded,
                      color: _purple,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),
            if (_walletTab == 0) _identityGrid(cards) else _peopleGrid(people),
            const SizedBox(height: 24),
          ],
        ),
      ),
    ),
  );

  Widget _hero(CardsProvider cards, ConnectionsProvider people, bool wide) {
    final first = _walletTab == 0;
    final event = cards.activeEventMode;

    final heading = Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          first ? 'A LITTLE MORE YOU' : 'BEYOND THE FIRST HELLO',
          style: const TextStyle(
            color: _purple,
            letterSpacing: 2,
            fontSize: 10,
            fontWeight: FontWeight.w700,
          ),
        ),
        const SizedBox(height: 13),
        Text(
          first
              ? 'One you.\nMany possibilities.'
              : 'Remember the moment.\nRecall the person.',
          style: TextStyle(
            color: _ink,
            fontSize: wide ? 44 : 28,
            height: 1.08,
            fontWeight: FontWeight.w700,
            letterSpacing: -1.8,
          ),
        ),
        const SizedBox(height: 14),
        Text(
          first
              ? 'Pick the side of you the world gets to meet.'
              : 'A conversation, a place, a detail. Your cue to reconnect.',
          style: const TextStyle(color: Color(0xFF777780), fontSize: 13),
        ),
        const SizedBox(height: 20),
        Wrap(
          spacing: 10,
          runSpacing: 10,
          children: [
            if (event != null)
              ActionChip(
                avatar: const Icon(
                  Icons.event_outlined,
                  size: 16,
                  color: _purple,
                ),
                label: Text(
                  event.eventName,
                  style: const TextStyle(color: _ink, fontSize: 11),
                ),
                onPressed: _event,
                backgroundColor: const Color(0xFFE8E3FA),
              ),
          ],
        ),
      ],
    );
    if (!first) return heading;
    final visual = _HoverPanel(
      onTap: () => _selectTab(2),
      child: Container(
        height: wide ? 224 : null,
        clipBehavior: Clip.antiAlias,
        decoration: BoxDecoration(
          color: const Color(0xFFE6E0F5),
          borderRadius: BorderRadius.circular(24),
        ),
        child: Stack(
          children: [
            Positioned(
              right: -20,
              top: -50,
              child: _ring(190, Colors.white.withValues(alpha: .45)),
            ),
            Positioned(
              right: 45,
              bottom: -80,
              child: _ring(160, Colors.white.withValues(alpha: .35)),
            ),
            Padding(
              padding: const EdgeInsets.all(24),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(10),
                        decoration: BoxDecoration(
                          color: Colors.white.withValues(alpha: .65),
                          borderRadius: BorderRadius.circular(14),
                        ),
                        child: Icon(
                          Icons.auto_awesome_rounded,
                          color: _purple,
                          size: 23,
                        ),
                      ),
                      const Spacer(),
                      const Icon(
                        Icons.north_east_rounded,
                        color: _ink,
                        size: 20,
                      ),
                    ],
                  ),
                  SizedBox(height: wide ? 0 : 16),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Remember the person,\nnot just the name.',
                        style: TextStyle(
                          color: _ink,
                          fontSize: wide ? 23 : 18,
                          height: 1.15,
                          fontWeight: FontWeight.w600,
                          letterSpacing: -.6,
                        ),
                      ),
                      if (wide) ...[
                        const SizedBox(height: 8),
                        Text(
                          'Explore smart recall',
                          style: const TextStyle(
                            color: Color(0xFF6D687B),
                            fontSize: 12,
                          ),
                        ),
                      ],
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
    return wide
        ? Row(
            children: [
              Expanded(flex: 6, child: heading),
              const SizedBox(width: 30),
              Expanded(flex: 4, child: visual),
            ],
          )
        : Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [heading, const SizedBox(height: 24), visual],
          );
  }

  Widget _ring(double size, Color color) => Container(
    width: size,
    height: size,
    decoration: BoxDecoration(
      shape: BoxShape.circle,
      border: Border.all(width: 28, color: color),
    ),
  );

  Widget _identityGrid(CardsProvider provider) {
    Widget deck(List<ContactCard> cards) => VisitingCardDeck(
      entries: cards
          .map(
            (card) => WalletEntry.own(
              card,
              locked: provider.isCardLocked(card.id),
              onOpen: provider.isCardLocked(card.id)
                  ? _lockedCard
                  : () => _open(CardDetailScreen(cardId: card.id)),
              onSend: provider.isCardLocked(card.id)
                  ? _lockedCard
                  : () => _share(card),
            ),
          )
          .toList(),
    );
    final primary = provider.defaultCard;
    final others = provider.walletCards
        .where((c) => c.id != primary?.id)
        .toList();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(
          '${provider.cards.length.clamp(0, CardsProvider.freeCardLimit)}/5 active cards · Free plan${provider.cards.length > CardsProvider.freeCardLimit ? ' · ${provider.cards.length - CardsProvider.freeCardLimit} locked' : ''}',
          style: Theme.of(context).textTheme.bodySmall,
        ),
        const SizedBox(height: 12),
        if (primary != null) ...[
          const Text('Primary card'),
          const SizedBox(height: 8),
          deck([primary]),
        ] else if (provider.cards.isNotEmpty) ...[
          const Text('Choose a primary card from its details or when editing.'),
          const SizedBox(height: 12),
        ],
        if (others.isNotEmpty) ...[
          if (primary != null) ...[
            const SizedBox(height: 20),
            const Text('Other cards'),
            const SizedBox(height: 12),
          ],
          deck(others),
        ],
        if (provider.remainingCardSlots > 0) ...[
          const SizedBox(height: 20),
          WalletFreeSlots(
            used: provider.cards.length,
            remaining: provider.remainingCardSlots,
            onAdd: _newCard,
          ),
        ],
      ],
    );
  }

  Widget _peopleGrid(ConnectionsProvider provider) {
    final people = provider.connections.where((p) {
      final text =
          '${p.fullName} ${p.role} ${p.eventContext.eventName} ${p.techStack.join(' ')}'
              .toLowerCase();
      if (!text.contains(_query.toLowerCase())) return false;
      return switch (_filter) {
        'Favourites' => p.isFavorite,
        'Creators' => RegExp(
          'creator|influencer|artist|photographer',
        ).hasMatch(text),
        'Tech' => RegExp('developer|architect| ai ').hasMatch(text),
        _ => true,
      };
    }).toList();
    return Column(
      children: [
        TextField(
          style: const TextStyle(color: _ink, fontSize: 14),
          decoration: InputDecoration(
            hintText: 'Find a familiar face…',
            hintStyle: const TextStyle(color: Color(0xFF8D8B95)),
            prefixIcon: const Icon(Icons.search_rounded, color: _purple),
            filled: true,
            fillColor: Colors.white,
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(14),
              borderSide: BorderSide.none,
            ),
          ),
          onChanged: (value) => setState(() => _query = value),
        ),
        const SizedBox(height: 14),
        Align(
          alignment: Alignment.centerLeft,
          child: Wrap(
            spacing: 8,
            runSpacing: 8,
            children: ['All', 'Favourites', 'Creators', 'Tech']
                .map(
                  (f) => ChoiceChip(
                    label: Text(f),
                    selected: _filter == f,
                    onSelected: (_) => setState(() => _filter = f),
                    selectedColor: const Color(0xFFE8E3FA),
                    backgroundColor: Colors.white,
                    side: BorderSide.none,
                    labelStyle: TextStyle(
                      color: _filter == f ? _purple : const Color(0xFF777780),
                      fontSize: 12,
                    ),
                  ),
                )
                .toList(),
          ),
        ),
        const SizedBox(height: 18),
        if (people.isNotEmpty)
          VisitingCardDeck(
            entries: people
                .asMap()
                .entries
                .map(
                  (entry) => WalletEntry.person(
                    entry.value,
                    index: entry.key,
                    onOpen: () => _open(
                      ConnectionDetailScreen(connectionId: entry.value.id),
                    ),
                    trailing: ConnectionMemoryButton(connection: entry.value),
                  ),
                )
                .toList(),
          ),
        if (people.isEmpty)
          _empty(
            _query.isEmpty
                ? 'Your people belong here.'
                : 'Try another name or memory.',
            Icons.people_outline_rounded,
            () => _open(const ReceiveCardScreen()),
          ),
      ],
    );
  }

  Widget _empty(String text, IconData icon, VoidCallback action) => Padding(
    padding: const EdgeInsets.all(32),
    child: Column(
      children: [
        Icon(icon, color: _purple, size: 40),
        const SizedBox(height: 14),
        Text(text, style: const TextStyle(color: _ink)),
        const SizedBox(height: 14),
        TextButton(onPressed: action, child: const Text('Get started')),
      ],
    ),
  );
}

class _HoverPanel extends StatefulWidget {
  final Widget child;
  final VoidCallback onTap;
  const _HoverPanel({required this.child, required this.onTap});
  @override
  State<_HoverPanel> createState() => _HoverPanelState();
}

class _HoverPanelState extends State<_HoverPanel> {
  bool hover = false;
  @override
  Widget build(BuildContext context) => MouseRegion(
    cursor: SystemMouseCursors.click,
    onEnter: (_) => setState(() => hover = true),
    onExit: (_) => setState(() => hover = false),
    child: AnimatedContainer(
      duration: const Duration(milliseconds: 180),
      curve: Curves.easeOut,
      transform: Matrix4.translationValues(0, hover ? -4 : 0, 0),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(24),
        boxShadow: hover
            ? [
                BoxShadow(
                  color: Colors.black.withValues(alpha: .12),
                  blurRadius: 24,
                  offset: const Offset(0, 10),
                ),
              ]
            : [],
      ),
      child: Material(
        color: Colors.transparent,
        borderRadius: BorderRadius.circular(24),
        clipBehavior: Clip.antiAlias,
        child: InkWell(onTap: widget.onTap, child: widget.child),
      ),
    ),
  );
}
