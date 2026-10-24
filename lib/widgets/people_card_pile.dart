import 'package:flutter/material.dart';
import 'visiting_card_deck.dart';
import 'wallet_card_pile.dart';

/// Connection order is a browsing choice; it never changes anyone's own primary card.
class PeopleCardPile extends StatefulWidget {
  final List<WalletEntry> entries;
  const PeopleCardPile({super.key, required this.entries});
  @override
  State<PeopleCardPile> createState() => _PeopleCardPileState();
}

class _PeopleCardPileState extends State<PeopleCardPile> {
  late List<String> _order;
  int _visibleLimit = 50;
  @override
  void initState() {
    super.initState();
    _order = widget.entries.map((e) => e.id).toList();
  }

  @override
  void didUpdateWidget(covariant PeopleCardPile oldWidget) {
    super.didUpdateWidget(oldWidget);
    final ids = widget.entries.map((e) => e.id).toSet();
    _order = [
      ..._order.where(ids.contains),
      ...widget.entries.map((e) => e.id).where((id) => !_order.contains(id)),
    ];
  }

  @override
  Widget build(BuildContext context) {
    if (_order.isEmpty) return const SizedBox.shrink();
    final byId = {for (final entry in widget.entries) entry.id: entry};
    final visible = _order.take(_visibleLimit).toList();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (_order.length > 1)
          Padding(
            padding: const EdgeInsets.only(bottom: 12),
            child: Text(
              'Tap a card to open · drag to reorder',
              style: Theme.of(context).textTheme.bodySmall,
            ),
          ),
        WalletCardPile(
          key: const ValueKey('people-scroll-stack'),
          pileKey: 'people-cards-pile',
          selectOnTap: false,
          frontAtEnd: true,
          entries: visible.map((id) => byId[id]!).toList(),
          onReorder: (ids) async {
            setState(() => _order.replaceRange(0, visible.length, ids));
          },
        ),
        if (_order.length > _visibleLimit)
          TextButton(
            onPressed: () => setState(() => _visibleLimit += 50),
            child: const Text('Show 50 more contacts'),
          ),
      ],
    );
  }
}
