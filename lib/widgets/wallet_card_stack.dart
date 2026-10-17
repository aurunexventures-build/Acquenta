import 'package:flutter/material.dart';
import '../models/contact_card.dart';
import '../models/event_context.dart';
import 'interactive_card_view.dart';
import '../screens/card_editor_screen.dart';

class WalletCardStack extends StatefulWidget {
  final List<ContactCard> cards;
  final EventContext? activeEvent;
  final VoidCallback onAddNewCard;

  const WalletCardStack({
    super.key,
    required this.cards,
    this.activeEvent,
    required this.onAddNewCard,
  });

  @override
  State<WalletCardStack> createState() => _WalletCardStackState();
}

class _WalletCardStackState extends State<WalletCardStack> {
  int? _expandedIndex;

  void _expandCard(int index) {
    setState(() {
      _expandedIndex = index;
    });
  }

  void _collapseStack() {
    setState(() {
      _expandedIndex = null;
    });
  }

  @override
  Widget build(BuildContext context) {
    if (widget.cards.isEmpty) {
      return _buildEmptyState(context);
    }

    final isExpanded = _expandedIndex != null;

    return SingleChildScrollView(
      physics: const BouncingScrollPhysics(),
      padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Deck Bar & Wallet Control
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  Icon(
                    isExpanded ? Icons.credit_card_rounded : Icons.wallet_rounded,
                    size: 16,
                    color: Colors.white70,
                  ),
                  const SizedBox(width: 8),
                  Text(
                    isExpanded
                        ? 'CARD ${_expandedIndex! + 1} OF ${widget.cards.length}'
                        : '${widget.cards.length} CARDS IN WALLET',
                    style: const TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w700,
                      letterSpacing: 1.0,
                      color: Colors.white60,
                    ),
                  ),
                ],
              ),
              if (isExpanded)
                TextButton.icon(
                  onPressed: _collapseStack,
                  icon: const Icon(Icons.layers_outlined, size: 14, color: Colors.blueAccent),
                  label: const Text(
                    'View All Cards',
                    style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: Colors.blueAccent),
                  ),
                  style: TextButton.styleFrom(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                    visualDensity: VisualDensity.compact,
                  ),
                )
              else
                Text(
                  'Tap to expand',
                  style: TextStyle(fontSize: 11, color: Colors.white.withValues(alpha: 0.4)),
                ),
            ],
          ),

          const SizedBox(height: 12),

          // Cards Stack / Expanded View
          if (isExpanded)
            _buildExpandedView(context, _expandedIndex!)
          else
            _buildStackedWallet(context),
        ],
      ),
    );
  }

  Widget _buildStackedWallet(BuildContext context) {
    // Height needed for the overlapping deck: base card height (~220) + 80px per extra card
    const double cardPeekOffset = 76.0;
    final double stackHeight = 240.0 + ((widget.cards.length - 1) * cardPeekOffset);

    return SizedBox(
      height: stackHeight,
      child: Stack(
        clipBehavior: Clip.none,
        children: List.generate(widget.cards.length, (index) {
          final card = widget.cards[index];
          final topOffset = index * cardPeekOffset;

          return Positioned(
            top: topOffset,
            left: 0,
            right: 0,
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 350),
              curve: Curves.easeOutCubic,
              transform: Matrix4.identity()..scale(1.0 - (index * 0.015)),
              child: InteractiveCardView(
                card: card,
                activeEvent: widget.activeEvent,
                isExpanded: false,
                onCardTapped: () => _expandCard(index),
              ),
            ),
          );
        }),
      ),
    );
  }

  Widget _buildExpandedView(BuildContext context, int index) {
    final card = widget.cards[index];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // Main Interactive Card (Tap to flip)
        InteractiveCardView(
          card: card,
          activeEvent: widget.activeEvent,
          isExpanded: true,
          onEditTapped: () {
            Navigator.push(
              context,
              MaterialPageRoute(builder: (_) => CardEditorScreen(initialCard: card)),
            );
          },
        ),

        const SizedBox(height: 16),

        // Quick Navigation Pager between cards if multiple exist
        if (widget.cards.length > 1)
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              IconButton(
                icon: const Icon(Icons.arrow_back_ios_new_rounded, size: 16),
                color: index > 0 ? Colors.white70 : Colors.white24,
                onPressed: index > 0 ? () => _expandCard(index - 1) : null,
              ),
              const SizedBox(width: 8),
              ...List.generate(widget.cards.length, (dotIndex) {
                return GestureDetector(
                  onTap: () => _expandCard(dotIndex),
                  child: Container(
                    width: dotIndex == index ? 20 : 6,
                    height: 6,
                    margin: const EdgeInsets.symmetric(horizontal: 3),
                    decoration: BoxDecoration(
                      color: dotIndex == index ? Colors.blueAccent : Colors.white24,
                      borderRadius: BorderRadius.circular(3),
                    ),
                  ),
                );
              }),
              const SizedBox(width: 8),
              IconButton(
                icon: const Icon(Icons.arrow_forward_ios_rounded, size: 16),
                color: index < widget.cards.length - 1 ? Colors.white70 : Colors.white24,
                onPressed: index < widget.cards.length - 1 ? () => _expandCard(index + 1) : null,
              ),
            ],
          ),

        const SizedBox(height: 12),

        // Bottom Actions Card
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: Colors.white.withValues(alpha: 0.04),
            borderRadius: BorderRadius.circular(18),
            border: Border.all(color: Colors.white.withValues(alpha: 0.08)),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'BEAMING & SHARING MODES',
                style: TextStyle(
                  fontSize: 10,
                  fontWeight: FontWeight.w700,
                  letterSpacing: 0.8,
                  color: Colors.white60,
                ),
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  Expanded(
                    child: _buildActionTile(
                      icon: Icons.nfc_rounded,
                      title: 'NFC Tap',
                      subtitle: 'Hold near phone',
                      color: Colors.amberAccent,
                      onTap: () {
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(
                            content: Text('NFC Ready: Hold your phone or MetCue ring against their device.'),
                            duration: Duration(seconds: 2),
                          ),
                        );
                      },
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: _buildActionTile(
                      icon: Icons.qr_code_2_rounded,
                      title: 'QR Code',
                      subtitle: 'Tap card to flip',
                      color: Colors.blueAccent,
                      onTap: () {},
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildActionTile({
    required IconData icon,
    required String title,
    required String subtitle,
    required Color color,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(14),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.08),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: color.withValues(alpha: 0.2)),
        ),
        child: Row(
          children: [
            Icon(icon, size: 20, color: color),
            const SizedBox(width: 8),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Colors.white),
                  ),
                  Text(
                    subtitle,
                    style: TextStyle(fontSize: 10, color: Colors.white.withValues(alpha: 0.6)),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildEmptyState(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 40, horizontal: 24),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: Colors.blue.withValues(alpha: 0.1),
                shape: BoxShape.circle,
              ),
              child: const Icon(Icons.wallet_rounded, size: 48, color: Colors.blue),
            ),
            const SizedBox(height: 20),
            const Text(
              'Your Wallet is Empty',
              style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: Colors.white),
            ),
            const SizedBox(height: 8),
            Text(
              'Create your first visiting card to start networking seamlessly with NFC and QR.',
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 13, color: Colors.white.withValues(alpha: 0.7)),
            ),
            const SizedBox(height: 24),
            ElevatedButton.icon(
              onPressed: widget.onAddNewCard,
              icon: const Icon(Icons.add_rounded),
              label: const Text('Create My Card'),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.blue,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
