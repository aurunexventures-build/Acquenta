import 'dart:math' as math;
import 'package:flutter/material.dart';

/// Procedural finishes stay small, offline and independent of image downloads.
class CardFinishPainter extends CustomPainter {
  final String finish, name;
  CardFinishPainter(this.finish, this.name);
  @override
  void paint(Canvas canvas, Size size) {
    canvas.save();
    canvas.clipRRect(
      RRect.fromRectAndRadius(Offset.zero & size, const Radius.circular(16)),
    );
    final paint = Paint()
      ..color = Colors.white.withValues(alpha: .055)
      ..strokeWidth = .6;
    if (finish == 'linen') {
      for (double x = 0; x < size.width; x += 5) {
        canvas.drawLine(Offset(x, 0), Offset(x, size.height), paint);
      }
      paint.color = Colors.black.withValues(alpha: .045);
      for (double y = 0; y < size.height; y += 4) {
        canvas.drawLine(Offset(0, y), Offset(size.width, y), paint);
      }
    } else if (finish == 'contour') {
      paint
        ..style = PaintingStyle.stroke
        ..strokeWidth = 13
        ..color = Colors.white.withValues(alpha: .045);
      for (double r = 48; r < size.width * .8; r += 26) {
        canvas.drawOval(
          Rect.fromCenter(
            center: Offset(size.width * 1.12, size.height * .17),
            width: r * 2,
            height: r * 2.7,
          ),
          paint,
        );
      }
    } else if (finish == 'monogram') {
      final initials = name
          .trim()
          .split(RegExp(r'\s+'))
          .where((p) => p.isNotEmpty)
          .take(2)
          .map((p) => String.fromCharCode(p.runes.first))
          .join()
          .toUpperCase();
      final text = TextPainter(
        text: TextSpan(
          text: initials,
          style: TextStyle(
            fontSize: math.min(size.height * .85, 135),
            fontWeight: FontWeight.w800,
            color: Colors.white.withValues(alpha: .055),
            letterSpacing: -8,
          ),
        ),
        textDirection: TextDirection.ltr,
      )..layout(maxWidth: size.width);
      text.paint(
        canvas,
        Offset(size.width - text.width - 4, size.height - text.height + 12),
      );
    }
    canvas.restore();
  }

  @override
  bool shouldRepaint(CardFinishPainter old) =>
      old.finish != finish || old.name != name;
}

class CardFinishPicker extends StatelessWidget {
  final String value, colour, name;
  final ValueChanged<String> onChanged;
  const CardFinishPicker({
    super.key,
    required this.value,
    required this.colour,
    required this.name,
    required this.onChanged,
  });
  @override
  Widget build(BuildContext context) {
    final base = Color(
      int.tryParse(colour.replaceFirst('#', 'FF'), radix: 16) ?? 0xFF234B42,
    );
    final background = base.computeLuminance() > .22
        ? Color.lerp(base, Colors.black, .65)!
        : base;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Card finish',
            style: TextStyle(fontWeight: FontWeight.w600),
          ),
          const SizedBox(height: 10),
          ClipRRect(
            borderRadius: BorderRadius.circular(16),
            child: ColoredBox(
              color: background,
              child: SizedBox(
                width: double.infinity,
                height: 112,
                child: CustomPaint(
                  painter: CardFinishPainter(value, name),
                  child: Padding(
                    padding: const EdgeInsets.all(20),
                    child: Align(
                      alignment: Alignment.centerLeft,
                      child: Text(
                        name.trim().isEmpty ? 'Your card' : name,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 22,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
          const SizedBox(height: 10),
          Wrap(
            spacing: 8,
            runSpacing: 6,
            children: const ['plain', 'linen', 'contour', 'monogram']
                .map(
                  (finish) => ChoiceChip(
                    label: Text(
                      '${finish[0].toUpperCase()}${finish.substring(1)}',
                    ),
                    selected: value == finish,
                    onSelected: (_) => onChanged(finish),
                  ),
                )
                .toList(),
          ),
        ],
      ),
    );
  }
}

class CardHover extends StatefulWidget {
  final Widget child;
  const CardHover({super.key, required this.child});
  @override
  State<CardHover> createState() => _CardHoverState();
}

class _CardHoverState extends State<CardHover> {
  bool hovering = false;
  @override
  Widget build(BuildContext context) => MouseRegion(
    onEnter: (_) => setState(() => hovering = true),
    onExit: (_) => setState(() => hovering = false),
    child: AnimatedContainer(
      duration: MediaQuery.disableAnimationsOf(context)
          ? Duration.zero
          : const Duration(milliseconds: 180),
      curve: Curves.easeOut,
      transform: Matrix4.translationValues(0, hovering ? -3 : 0, 0),
      child: widget.child,
    ),
  );
}
