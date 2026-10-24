import '../services/connection_insights.dart';
import '../widgets/customize_card_dialog.dart';
import '../widgets/thinking_recall_icon.dart';
import '../widgets/acquenta_bot_icon.dart';
import '../widgets/account_avatar.dart';
import '../services/auth_service.dart';
import '../services/sync_service.dart';
import '../widgets/voice_people_search_field.dart';
import '../widgets/people_card_pile.dart';
import '../providers/account_profile_provider.dart';
import '../widgets/delete_card_dialog.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../models/contact_card.dart';
import '../models/event_context.dart';
import '../providers/cards_provider.dart';
import '../providers/connections_provider.dart';
import '../widgets/qr_share_dialog.dart';
import '../widgets/visiting_card_deck.dart';
import '../widgets/wallet_card_pile.dart';
import '../widgets/connection_memory_button.dart';
import 'card_detail_screen.dart';
import 'connection_detail_screen.dart';
import 'onboarding_card_builder_screen.dart';
import 'receive_card_screen.dart';
import 'smart_search_screen.dart';
import 'account_profile_screen.dart';

const _ink = Color(0xFF202128);
const _paper = Color(0xFFF6F5F1);
const _purple = Color(0xFF2563EB);

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
  String _peopleSort = 'Newest first';
  String _query = '';
  final _peopleQuery = TextEditingController();
  final _peopleSearchService = SyncService();
  @override
  void dispose() {
    _peopleQuery.dispose();
    _peopleSearchService.close();
    super.dispose();
  }

  Future<Map<String, dynamic>> _peopleRequest(
    String path,
    Map<String, dynamic> body,
  ) async {
    final auth = context.read<AuthService?>();
    if (auth == null || !auth.isAuthenticated) {
      throw StateError('Sign in to use voice search.');
    }
    final uid = auth.currentUser?.uid;
    final result = await _peopleSearchService.request(path, body, auth);
    if (!mounted || uid != auth.currentUser?.uid) {
      throw StateError('Account changed.');
    }
    return result;
  }

  Future<String> _organisePeopleQuery(String text) async {
    final result = await _peopleRequest('/api/v1/text/organise', {
      'text': text,
      'purpose': 'search',
    });
    final query = result['text'];
    if (query is! String || query.trim().isEmpty) throw const FormatException();
    return query.trim();
  }

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
                  if (wide || !keyboard) _topbar(wide),
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
              indicatorColor: const Color(0xFFE6EEFF),
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
                  icon: ThinkingRecallIcon(),
                  selectedIcon: ThinkingRecallIcon(size: 32),
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
                    color: Color(0xFFE7EFFF),
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
                        backgroundColor: const Color(0xFFE7EFFF),
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
                Icon(Icons.circle, color: Color(0xFFE7EFFF), size: 6),
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
              if (index == 2)
                const AcquentaBotIcon(size: 19)
              else
                Icon(
                  icon,
                  size: 19,
                  color: _tab == index
                      ? const Color(0xFFE7EFFF)
                      : Colors.white54,
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
          color: light ? const Color(0xFFE7EFFF) : _purple,
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
    final auth = context.watch<AuthService?>();
    final profile = context.watch<AccountProfileProvider?>()?.profile;
    final name = profile?.fullName.trim().isNotEmpty == true
        ? profile!.fullName
        : (auth?.currentUser?.displayName ?? '');
    return Container(
      height: wide ? 78 : 64,
      padding: EdgeInsets.symmetric(horizontal: wide ? 36 : 20),
      decoration: const BoxDecoration(
        border: Border(bottom: BorderSide(color: Color(0xFFE5E4DF))),
      ),
      child: Row(
        children: [
          Expanded(
            child: Align(
              alignment: Alignment.centerLeft,
              child: wide
                  ? Text(
                      [
                        'Your identity, beautifully shared.',
                        'Your people, a little closer.',
                        'A thought away.',
                      ][_tab],
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        color: Color(0xFF777780),
                        fontSize: 13,
                      ),
                    )
                  : FittedBox(
                      fit: BoxFit.scaleDown,
                      alignment: Alignment.centerLeft,
                      child: _brand(),
                    ),
            ),
          ),
          const SizedBox(width: 12),
          Row(
            key: const ValueKey('header-account-actions'),
            mainAxisSize: MainAxisSize.min,
            children: [
              IconButton(
                tooltip: 'Event',
                style: IconButton.styleFrom(
                  backgroundColor: const Color(0xFFE8EDF2),
                  foregroundColor: _ink,
                ),
                onPressed: _event,
                icon: const Icon(Icons.event_outlined, color: _ink, size: 21),
              ),
              const SizedBox(width: 4),
              IconButton(
                tooltip: 'Your account',
                onPressed: () => _open(const AccountProfileScreen()),
                icon: AccountAvatar(
                  key: ValueKey(
                    'account-avatar:${auth?.currentUser?.uid ?? 'guest'}',
                  ),
                  name: name,
                  photoUrl: auth?.accountPhotoUrl ?? '',
                ),
              ),
            ],
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
            Text(
              _walletTab == 0 ? 'A LITTLE MORE YOU' : 'BEYOND THE FIRST HELLO',
              style: const TextStyle(
                color: _purple,
                letterSpacing: 2,
                fontSize: 10,
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: 14),
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
                  Tooltip(
                    message: 'Receive a card',
                    child: TextButton.icon(
                      onPressed: () => _open(const ReceiveCardScreen()),
                      icon: const Icon(Icons.move_to_inbox_outlined, size: 19),
                      label: const Text('Receive'),
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

  Widget _identityGrid(CardsProvider provider) {
    Widget deck(List<ContactCard> cards) => WalletCardPile(
      onReorder: provider.reorderWallet,
      entries: cards
          .map(
            (card) => WalletEntry.own(
              card,
              locked: provider.isCardLocked(card.id),
              trailing: PopupMenuButton<String>(
                tooltip: 'Card options',
                icon: const Icon(Icons.more_vert, color: Color(0xFFE7EFFF)),
                color: const Color(0xFF262336),
                onSelected: (action) {
                  if (action == 'delete') {
                    confirmDeleteCard(context, provider, card);
                  } else if (provider.isCardLocked(card.id)) {
                    _lockedCard();
                  } else if (action == 'customize') {
                    showDialog<void>(
                      context: context,
                      builder: (_) => CustomizeCardDialog(card: card),
                    );
                  } else {
                    _share(card);
                  }
                },
                itemBuilder: (_) => [
                  for (final action in ['Share', 'Customize', 'Delete'])
                    PopupMenuItem(
                      value: action.toLowerCase(),
                      child: Row(
                        children: [
                          Icon(
                            action == 'Share'
                                ? Icons.ios_share_rounded
                                : action == 'Customize'
                                ? Icons.palette_outlined
                                : Icons.delete_outline_rounded,
                            color: const Color(0xFFE7EFFF),
                            size: 20,
                          ),
                          const SizedBox(width: 12),
                          Text(
                            '$action card',
                            style: const TextStyle(color: Color(0xFFE7EFFF)),
                          ),
                        ],
                      ),
                    ),
                ],
              ),
              onOpen: provider.isCardLocked(card.id)
                  ? _lockedCard
                  : () => _open(CardDetailScreen(cardId: card.id)),
            ),
          )
          .toList(),
    );
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(
          '${provider.cards.length.clamp(0, CardsProvider.freeCardLimit)}/5 active cards · Free plan${provider.cards.length > CardsProvider.freeCardLimit ? ' · ${provider.cards.length - CardsProvider.freeCardLimit} locked' : ''}',
          style: Theme.of(context).textTheme.bodySmall,
        ),
        const SizedBox(height: 12),
        if (provider.walletCards.length > 1) ...[
          Text(
            'Drag to reorder · bottom card is primary',
            style: Theme.of(context).textTheme.bodySmall,
          ),
          const SizedBox(height: 12),
        ],
        deck(provider.walletCards),
      ],
    );
  }

  Widget _peopleGrid(ConnectionsProvider provider) {
    final filters = ConnectionInsights.filters(provider.connections);
    final activeFilter = filters.contains(_filter) ? _filter : 'All';
    final people =
        (_query.trim().isEmpty
                ? provider.connections
                : provider.searchResults.map((result) => result.connection))
            .where((p) => ConnectionInsights.matches(p, activeFilter))
            .toList();
    int compareText(String a, String b) =>
        a.toLowerCase().compareTo(b.toLowerCase());
    if (_peopleSort != 'Best match') {
      people.sort((a, b) {
        final compared = switch (_peopleSort) {
          'Oldest first' => a.savedAt.compareTo(b.savedAt),
          'Name A–Z' => compareText(a.fullName, b.fullName),
          'Name Z–A' => compareText(b.fullName, a.fullName),
          'Company' => compareText(a.company, b.company),
          'Event' => compareText(
            a.eventContext.eventName,
            b.eventContext.eventName,
          ),
          _ => b.savedAt.compareTo(a.savedAt),
        };
        return compared == 0 ? compareText(a.fullName, b.fullName) : compared;
      });
    }
    return Column(
      children: [
        VoicePeopleSearchField(
          controller: _peopleQuery,
          request: _peopleRequest,
          organise: _organisePeopleQuery,
          voiceEnabled: context.watch<AuthService?>()?.isAuthenticated ?? false,
          onChanged: (value) {
            provider.setSearchQuery(value);
            setState(() => _query = value);
          },
        ),
        const SizedBox(height: 14),
        Row(
          key: const ValueKey('connections-filter-sort-row'),
          children: [
            Expanded(
              child: SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: Row(
                  children: [
                    for (final f in filters)
                      Padding(
                        padding: const EdgeInsets.only(right: 8),
                        child: ChoiceChip(
                          label: Text(ConnectionInsights.label(f)),
                          selected: activeFilter == f,
                          onSelected: (_) => setState(() => _filter = f),
                          selectedColor: const Color(0xFFE6EEFF),
                          backgroundColor: Colors.white,
                          side: BorderSide.none,
                          labelStyle: TextStyle(
                            color: activeFilter == f
                                ? _purple
                                : const Color(0xFF777780),
                            fontSize: 12,
                          ),
                        ),
                      ),
                  ],
                ),
              ),
            ),
            const SizedBox(width: 8),
            PopupMenuButton<String>(
              tooltip: 'Sort connections',
              initialValue: _peopleSort,
              onSelected: (value) => setState(() => _peopleSort = value),
              itemBuilder: (_) => [
                for (final label in [
                  'Newest first',
                  'Oldest first',
                  'Name A–Z',
                  'Name Z–A',
                  'Company',
                  'Event',
                  'Best match',
                ])
                  PopupMenuItem(value: label, child: Text(label)),
              ],
              child: const Chip(
                avatar: Icon(Icons.sort_rounded, size: 17, color: _purple),
                label: Text(
                  'Sort',
                  style: TextStyle(color: _purple, fontSize: 12),
                ),
                backgroundColor: Color(0xFFE6EEFF),
                side: BorderSide.none,
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),
        if (people.isNotEmpty)
          PeopleCardPile(
            key: ValueKey('people-$_filter-$_query-$_peopleSort'),
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
