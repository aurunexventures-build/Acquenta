import 'dart:math' as math;
import 'dart:async';
import 'package:flutter/material.dart';

/// A transparent robot face, distinct from the square app badge.
class ThinkingRecallIcon extends StatefulWidget {
  final double size;
  const ThinkingRecallIcon({super.key, this.size = 30});
  @override
  State<ThinkingRecallIcon> createState() => _ThinkingRecallIconState();
}

class _ThinkingRecallIconState extends State<ThinkingRecallIcon>
    with SingleTickerProviderStateMixin {
  late final AnimationController _thinking = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 2200),
  );
  Timer? _cycle;
  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (MediaQuery.disableAnimationsOf(context)) {
      _cycle?.cancel();
      _cycle = null;
      _thinking.stop();
      _thinking.value = .3;
    } else if (_cycle == null) {
      _thinking.forward(from: 0);
      _cycle = Timer.periodic(const Duration(seconds: 5), (_) {
        if (mounted && TickerMode.of(context)) _thinking.forward(from: 0);
      });
    }
  }

  @override
  void dispose() {
    _cycle?.cancel();
    _thinking.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => ExcludeSemantics(
    child: SizedBox(
      width: widget.size,
      height: widget.size,
      child: CustomPaint(painter: _ThinkingBotPainter(_thinking)),
    ),
  );
}

class _ThinkingBotPainter extends CustomPainter {
  final Animation<double> thinking;
  _ThinkingBotPainter(this.thinking) : super(repaint: thinking);
  @override
  void paint(Canvas canvas, Size size) {
    canvas.save();
    canvas.scale(size.width / 32, size.height / 32);
    final phase = thinking.value * math.pi * 2;
    canvas.translate(0, math.sin(phase) * .4);
    final stroke = Paint()
      ..color = const Color(0xFF6554C0)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.2;
    final metal = Paint()
      ..shader = const LinearGradient(
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
        colors: [Color(0xFFF3F4FC), Color(0xFFB8BED5)],
      ).createShader(const Rect.fromLTWH(5, 10, 22, 17));
    canvas.drawLine(const Offset(15, 10), const Offset(15, 6), stroke);
    canvas.drawCircle(
      const Offset(15, 5),
      1.7,
      Paint()..color = const Color(0xFF8A78D5),
    );
    for (final x in [2.5, 26.5]) {
      canvas.drawRRect(
        RRect.fromRectAndRadius(
          Rect.fromLTWH(x, 16, 3, 7),
          const Radius.circular(1.5),
        ),
        Paint()..color = const Color(0xFF8F96B1),
      );
    }
    final head = RRect.fromRectAndRadius(
      const Rect.fromLTWH(5, 10, 22, 18),
      const Radius.circular(5),
    );
    canvas.drawRRect(head, metal);
    canvas.drawRRect(head, stroke);
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        const Rect.fromLTWH(8, 14, 16, 9),
        const Radius.circular(3),
      ),
      Paint()..color = const Color(0xFF252343),
    );
    final glance = .5 + math.sin(phase) * .35;
    for (final x in [11.0, 18.0]) {
      canvas.drawRRect(
        RRect.fromRectAndRadius(
          Rect.fromLTWH(x + glance, 16, 2.8, 4.2),
          const Radius.circular(1.4),
        ),
        Paint()..color = const Color(0xFFE1DCFF),
      );
    }
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        const Rect.fromLTWH(13, 25, 6, 1),
        const Radius.circular(.5),
      ),
      Paint()..color = const Color(0xFF747E9E),
    );
    final dots = [
      const Offset(24, 3),
      const Offset(28, 6),
      const Offset(30, 10),
    ];
    for (var i = 0; i < dots.length; i++) {
      final strength = (math.sin(phase - i * 1.1) + 1) / 2;
      canvas.drawCircle(
        dots[i],
        1.1 + strength * .35,
        Paint()
          ..color = const Color(
            0xFF6554C0,
          ).withValues(alpha: .3 + strength * .7),
      );
    }
    canvas.restore();
  }

  @override
  bool shouldRepaint(_ThinkingBotPainter oldDelegate) =>
      oldDelegate.thinking != thinking;
}
