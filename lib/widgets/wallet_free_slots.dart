import 'package:flutter/material.dart';

class WalletFreeSlots extends StatelessWidget {
  final int used, remaining;
  final VoidCallback onAdd;
  const WalletFreeSlots({
    super.key,
    required this.used,
    required this.remaining,
    required this.onAdd,
  });
  @override
  Widget build(BuildContext context) {
    if (remaining <= 0) return const SizedBox.shrink();
    final scale = MediaQuery.textScalerOf(context).scale(14) / 14;
    return Align(
      alignment: Alignment.topLeft,
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 560),
        child: SizedBox(
          height: (108 + (remaining - 1) * 58) * scale,
          child: Stack(
            children: [
              for (var i = 0; i < remaining; i++)
                Positioned(
                  top: i * 58.0 * scale,
                  left: 0,
                  right: 0,
                  height: 108 * scale,
                  child: Material(
                    color: const Color(0xFFEFEAF8),
                    shape: RoundedRectangleBorder(
                      side: const BorderSide(color: Color(0xFFCAC1E2)),
                      borderRadius: BorderRadius.circular(18),
                    ),
                    child: InkWell(
                      onTap: onAdd,
                      borderRadius: BorderRadius.circular(18),
                      child: Padding(
                        padding: const EdgeInsets.all(14),
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Icon(
                              Icons.add_circle_outline,
                              color: Color(0xFF6554C0),
                            ),
                            const SizedBox(width: 10),
                            Expanded(
                              child: Text(
                                'Add card · slot ${used + i + 1} of 5',
                                style: const TextStyle(
                                  color: Color(0xFF6554C0),
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}
