import 'dart:math' as math;
import 'package:flutter/material.dart';

/// Shared card-organising agent artwork used by the launcher and AI views.
class RecallWireframe extends StatefulWidget {
  final bool thinking;
  const RecallWireframe({super.key, required this.thinking});
  @override
  State<RecallWireframe> createState() => _RecallWireframeState();
}

class _RecallWireframeState extends State<RecallWireframe>
    with SingleTickerProviderStateMixin {
  late final AnimationController _pulse = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 3600),
  );
  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _update();
  }

  @override
  void didUpdateWidget(covariant RecallWireframe old) {
    super.didUpdateWidget(old);
    if (old.thinking != widget.thinking) _update();
  }

  void _update() {
    if (widget.thinking &&
        !MediaQuery.disableAnimationsOf(context) &&
        TickerMode.of(context)) {
      _pulse.repeat();
    } else {
      _pulse.stop();
      _pulse.value = 0;
    }
  }

  @override
  void dispose() {
    _pulse.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => Semantics(
    image: true,
    label: 'AI assistant organising connection cards',
    child: RepaintBoundary(
      child: AnimatedBuilder(
        animation: _pulse,
        builder: (_, _) => Transform.scale(
          scale: widget.thinking
              ? 1 + .025 * math.sin(_pulse.value * math.pi * 2)
              : 1,
          child: Center(
            child: AspectRatio(
              aspectRatio: 1,
              child: ClipRRect(
                borderRadius: BorderRadius.circular(18),
                child: Image.asset(
                  'assets/branding/acquenta-icon-v3.png',
                  fit: BoxFit.contain,
                  excludeFromSemantics: true,
                ),
              ),
            ),
          ),
        ),
      ),
    ),
  );
}
