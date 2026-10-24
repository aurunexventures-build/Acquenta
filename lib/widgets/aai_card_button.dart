import 'dart:math' as math;
import 'package:flutter/material.dart';

/// A short voice-to-card invitation; replay on hover.
class AaiCardButton extends StatefulWidget {
  final VoidCallback onPressed;
  const AaiCardButton({super.key, required this.onPressed});
  @override
  State<AaiCardButton> createState() => _AaiCardButtonState();
}

class _AaiCardButtonState extends State<AaiCardButton>
    with SingleTickerProviderStateMixin {
  late final _motion = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 4800),
  );
  bool _started = false, _hovered = false, _pressed = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (MediaQuery.disableAnimationsOf(context)) {
      _motion.stop();
      _motion.value = 1;
    } else if (!_started) {
      _started = true;
      _motion.forward();
    }
  }

  void _replay() {
    if (!MediaQuery.disableAnimationsOf(context)) _motion.forward(from: 0);
  }

  @override
  void dispose() {
    _motion.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => SizedBox(
    width: 88,
    child: Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        MouseRegion(
          onEnter: (_) {
            setState(() => _hovered = true);
            _replay();
          },
          onExit: (_) => setState(() => _hovered = false),
          child: AnimatedScale(
            scale: _pressed
                ? .94
                : _hovered
                ? 1.06
                : 1,
            duration: MediaQuery.disableAnimationsOf(context)
                ? Duration.zero
                : const Duration(milliseconds: 160),
            child: IconButton(
              tooltip: 'Talk to Acquenta · create this card',
              onPressed: widget.onPressed,
              onHover: (hovered) => setState(() => _hovered = hovered),
              highlightColor: const Color(0x222563EB),
              padding: EdgeInsets.zero,
              constraints: const BoxConstraints.tightFor(width: 64, height: 64),
              icon: Listener(
                onPointerDown: (_) => setState(() => _pressed = true),
                onPointerUp: (_) => setState(() => _pressed = false),
                onPointerCancel: (_) => setState(() => _pressed = false),
                child: RepaintBoundary(
                  child: AnimatedBuilder(
                    animation: _motion,
                    builder: (_, _) {
                      final pulse = math.sin(_motion.value * math.pi * 6);
                      return Transform.translate(
                        offset: Offset(0, -1.4 * pulse),
                        child: SizedBox.square(
                          dimension: 64,
                          child: Stack(
                            clipBehavior: Clip.none,
                            children: [
                              Positioned(
                                left: 2,
                                top: 2,
                                width: 58,
                                height: 58,
                                child: Transform.scale(
                                  scale: 1 + .025 * pulse,
                                  child: ClipRRect(
                                    borderRadius: BorderRadius.circular(14),
                                    child: Image.asset(
                                      'assets/branding/acquenta-icon-v3.png',
                                      fit: BoxFit.contain,
                                      excludeFromSemantics: true,
                                    ),
                                  ),
                                ),
                              ),
                              Positioned(
                                right: 0,
                                bottom: 0,
                                child: CustomPaint(
                                  size: const Size(28, 18),
                                  painter: _VoiceToCardPainter(_motion.value),
                                ),
                              ),
                            ],
                          ),
                        ),
                      );
                    },
                  ),
                ),
              ),
            ),
          ),
        ),
        const SizedBox(height: 3),
        Text(
          'Talk to create',
          textAlign: TextAlign.center,
          style: Theme.of(context).textTheme.labelSmall?.copyWith(
            color: const Color(0xFF2563EB),
            fontWeight: FontWeight.w600,
          ),
        ),
      ],
    ),
  );
}

class _VoiceToCardPainter extends CustomPainter {
  final double progress;
  _VoiceToCardPainter(this.progress);
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()..color = const Color(0xFF2563EB);
    canvas.drawRRect(
      RRect.fromRectAndRadius(Offset.zero & size, const Radius.circular(7)),
      paint,
    );
    paint
      ..color = const Color(0xFF6CF3DE)
      ..strokeWidth = 2
      ..strokeCap = StrokeCap.round;
    final phase = progress * math.pi * 6;
    for (var i = 0; i < 5; i++) {
      final height =
          4 + (1 - (i - 2).abs() * .25) * (5 + 3 * math.sin(phase + i * .8));
      final x = 6.0 + i * 4;
      canvas.drawLine(
        Offset(x, (size.height - height) / 2),
        Offset(x, (size.height + height) / 2),
        paint,
      );
    }
  }

  @override
  bool shouldRepaint(covariant _VoiceToCardPainter oldDelegate) =>
      oldDelegate.progress != progress;
}
