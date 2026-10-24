import 'card_finish_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter/semantics.dart';
import 'visiting_card_deck.dart';

/// Overlapping headers sit above the open card; reading order is explicit.
class WalletCardPile extends StatefulWidget {
  final List<WalletEntry> entries;
  final bool selectOnTap;
  final bool frontAtEnd;
  final String pileKey;
  final Future<void> Function(List<String>) onReorder;
  const WalletCardPile({
    super.key,
    required this.entries,
    required this.onReorder,
    this.selectOnTap = false,
    this.frontAtEnd = false,
    this.pileKey = 'my-cards-pile',
  });
  @override
  State<WalletCardPile> createState() => _WalletCardPileState();
}

class _WalletCardPileState extends State<WalletCardPile> {
  bool _saving = false;
  String? _dragging;
  int get _frontIndex => widget.frontAtEnd ? widget.entries.length - 1 : 0;
  EdgeDraggingAutoScroller? _autoScroller;
  bool get _mouseDrag => [
    TargetPlatform.macOS,
    TargetPlatform.windows,
    TargetPlatform.linux,
  ].contains(defaultTargetPlatform);
  @override
  void dispose() {
    _autoScroller?.stopAutoScroll();
    super.dispose();
  }

  void _dragUpdate(DragUpdateDetails details) {
    final scrollable = Scrollable.maybeOf(context);
    if (scrollable == null) return;
    _autoScroller ??= EdgeDraggingAutoScroller(scrollable, velocityScalar: 24);
    _autoScroller!.startAutoScrollIfNecessary(
      Rect.fromCenter(center: details.globalPosition, width: 40, height: 64),
    );
  }

  Future<void> _move(String id, int target) async {
    if (_saving) return;
    final order = widget.entries.map((e) => e.id).toList();
    final from = order.indexOf(id);
    if (from < 0 || from == target) return;
    order.removeAt(from);
    order.insert(target, id);
    setState(() => _saving = true);
    try {
      await widget.onReorder(order);
      HapticFeedback.selectionClick();
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Could not save the card order. Please try again.'),
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _saving = false;
          _dragging = null;
        });
      }
    }
  }

  Widget _card(
    WalletEntry entry,
    int index,
    double width, {
    double? peekHeight,
  }) {
    final fullFace = CardHover(
      child: Stack(
        children: [
          VisitingCardDeck(entries: [entry]),
          Positioned.fill(
            child: IgnorePointer(
              child: DecoratedBox(
                decoration: BoxDecoration(
                  border: Border.all(
                    color: Color.lerp(entry.color, Colors.white, .28)!,
                    width: 1,
                  ),
                  borderRadius: BorderRadius.circular(18),
                ),
              ),
            ),
          ),
          if (!entry.locked)
            const Positioned(
              top: 6,
              left: 0,
              right: 0,
              child: IgnorePointer(
                child: Icon(
                  Icons.drag_handle_rounded,
                  size: 18,
                  color: Colors.white54,
                ),
              ),
            ),
        ],
      ),
    );
    final face = widget.selectOnTap && index != _frontIndex
        ? GestureDetector(
            behavior: HitTestBehavior.opaque,
            onTap: () => _move(entry.id, _frontIndex),
            child: AbsorbPointer(child: fullFace),
          )
        : fullFace;
    return DragTarget<String>(
      onWillAcceptWithDetails: (details) =>
          !_saving && !entry.locked && details.data != entry.id,
      onAcceptWithDetails: (details) => _move(details.data, index),
      builder: (context, candidates, rejected) {
        final highlighted = candidates.isNotEmpty;
        final child = AnimatedContainer(
          duration: const Duration(milliseconds: 180),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(20),
            boxShadow: highlighted
                ? [
                    BoxShadow(
                      color: Theme.of(
                        context,
                      ).colorScheme.primary.withValues(alpha: .5),
                      blurRadius: 12,
                      spreadRadius: 3,
                    ),
                  ]
                : [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: .24),
                      blurRadius: 10,
                      offset: const Offset(0, 5),
                    ),
                  ],
          ),
          child: Opacity(
            opacity: _dragging == entry.id ? .25 : 1,
            child: peekHeight == null
                ? face
                : ClipRect(
                    clipper: const _CardPeekClipper(),
                    child: SizedBox(
                      height: peekHeight,
                      child: OverflowBox(
                        alignment: Alignment.topCenter,
                        minHeight: 0,
                        maxHeight: double.infinity,
                        child: face,
                      ),
                    ),
                  ),
          ),
        );
        return Semantics(
          key: ValueKey('wallet-pile-card-${entry.id}'),
          customSemanticsActions: entry.locked || _saving
              ? null
              : {
                  if (index != _frontIndex)
                    const CustomSemanticsAction(
                      label: 'Move card to front',
                    ): () =>
                        _move(entry.id, _frontIndex),
                  if (index + 1 < widget.entries.where((e) => !e.locked).length)
                    const CustomSemanticsAction(label: 'Move card back'): () =>
                        _move(entry.id, index + 1),
                },
          child: _draggable(entry, width, fullFace, child),
        );
      },
    );
  }

  Widget _draggable(
    WalletEntry entry,
    double width,
    Widget fullFace,
    Widget child,
  ) {
    void started() {
      setState(() => _dragging = entry.id);
      HapticFeedback.selectionClick();
    }

    void ended(DraggableDetails details) {
      _autoScroller?.stopAutoScroll();
      if (mounted) setState(() => _dragging = null);
    }

    final feedback = IgnorePointer(
      child: Material(
        color: Colors.transparent,
        child: SizedBox(
          width: width,
          child: Transform.scale(scale: 1.025, child: fullFace),
        ),
      ),
    );
    if (_mouseDrag) {
      return MouseRegion(
        cursor: entry.locked
            ? SystemMouseCursors.basic
            : SystemMouseCursors.grab,
        child: Draggable<String>(
          data: entry.id,
          maxSimultaneousDrags: entry.locked || _saving ? 0 : 1,
          onDragStarted: started,
          onDragUpdate: _dragUpdate,
          onDragEnd: ended,
          feedback: feedback,
          child: child,
        ),
      );
    }
    return LongPressDraggable<String>(
      data: entry.id,
      maxSimultaneousDrags: entry.locked || _saving ? 0 : 1,
      delay: const Duration(milliseconds: 350),
      onDragStarted: started,
      onDragUpdate: _dragUpdate,
      onDragEnd: ended,
      feedback: feedback,
      child: child,
    );
  }

  @override
  Widget build(BuildContext context) {
    if (widget.entries.isEmpty) return const SizedBox.shrink();
    return Align(
      alignment: Alignment.topLeft,
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 560),
        child: LayoutBuilder(
          builder: (context, box) {
            final step = 64.0 * MediaQuery.textScalerOf(context).scale(14) / 14;
            final headers = widget.frontAtEnd
                ? List.generate(widget.entries.length - 1, (i) => i)
                : List.generate(
                    widget.entries.length - 1,
                    (i) => widget.entries.length - 1 - i,
                  );
            return Stack(
              key: ValueKey(widget.pileKey),
              clipBehavior: Clip.none,
              children: [
                for (var position = 0; position < headers.length; position++)
                  Positioned(
                    top: position * step,
                    left: 0,
                    right: 0,
                    child: _card(
                      widget.entries[headers[position]],
                      headers[position],
                      box.maxWidth,
                      peekHeight: step,
                    ),
                  ),
                Padding(
                  padding: EdgeInsets.only(top: headers.length * step),
                  child: _card(
                    widget.entries[_frontIndex],
                    _frontIndex,
                    box.maxWidth,
                  ),
                ),
              ],
            );
          },
        ),
      ),
    );
  }
}

/// Keep the previous card painted underneath the next card's rounded top corners.
/// Its layout and touch target remain limited to the exposed header.
class _CardPeekClipper extends CustomClipper<Rect> {
  const _CardPeekClipper();
  @override
  Rect getClip(Size size) => Rect.fromLTWH(0, 0, size.width, size.height + 18);
  @override
  bool shouldReclip(_CardPeekClipper oldClipper) => false;
}
