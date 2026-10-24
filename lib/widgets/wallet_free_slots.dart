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
    return Align(
      alignment: Alignment.topLeft,
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 560),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            for (var i = 0; i < remaining; i++)
              Padding(
                padding: const EdgeInsets.only(bottom: 10),
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
                      padding: const EdgeInsets.all(16),
                      child: Row(
                        children: [
                          const Icon(
                            Icons.add_circle_outline,
                            color: Color(0xFF2563EB),
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: Text(
                              'Add card · slot ${used + i + 1} of 5',
                              style: const TextStyle(color: Color(0xFF2563EB)),
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
    );
  }
}
