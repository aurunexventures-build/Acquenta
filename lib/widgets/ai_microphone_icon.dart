import 'package:flutter/material.dart';

class AiMicrophoneIcon extends StatelessWidget {
  const AiMicrophoneIcon({super.key});
  @override
  Widget build(BuildContext context) => const SizedBox(
    width: 30,
    height: 30,
    child: Stack(
      children: [
        Positioned(
          left: 0,
          bottom: 0,
          child: Icon(Icons.mic_rounded, size: 25),
        ),
        Positioned(right: 0, top: 0, child: Icon(Icons.auto_awesome, size: 13)),
      ],
    ),
  );
}
