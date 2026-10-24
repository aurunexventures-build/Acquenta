import 'package:flutter/material.dart';

class AcquentaBotIcon extends StatelessWidget {
  final double size;
  const AcquentaBotIcon({super.key, this.size = 28});
  @override
  Widget build(BuildContext context) => ClipRRect(
    borderRadius: BorderRadius.circular(size * .22),
    child: Image.asset(
      'assets/branding/acquenta-icon-v3.png',
      width: size,
      height: size,
      fit: BoxFit.cover,
      excludeFromSemantics: true,
    ),
  );
}
