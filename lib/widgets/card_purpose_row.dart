import 'package:flutter/material.dart';

class CardPurposeRow extends StatelessWidget {
  final Widget purpose;
  final bool primary;
  final ValueChanged<bool> onPrimaryChanged;
  const CardPurposeRow({
    super.key,
    required this.purpose,
    required this.primary,
    required this.onPrimaryChanged,
  });

  Widget _switch(BuildContext context) => Row(
    mainAxisSize: MainAxisSize.min,
    children: [
      Switch(
        value: primary,
        onChanged: onPrimaryChanged,
        activeTrackColor: const Color(0xFF2563EB),
        inactiveTrackColor: const Color(0xFFE0DCE8),
        activeThumbColor: Colors.white,
        inactiveThumbColor: const Color(0xFF6E687A),
        thumbIcon: WidgetStateProperty.resolveWith(
          (states) => Icon(
            states.contains(WidgetState.selected)
                ? Icons.check_rounded
                : Icons.remove_rounded,
            color: states.contains(WidgetState.selected)
                ? const Color(0xFF2563EB)
                : Colors.white,
            size: 16,
          ),
        ),
      ),
      Text(
        primary ? 'On' : 'Off',
        style: Theme.of(context).textTheme.labelMedium?.copyWith(
          color: primary ? const Color(0xFF2563EB) : const Color(0xFF6E687A),
        ),
      ),
    ],
  );

  @override
  Widget build(BuildContext context) => LayoutBuilder(
    builder: (context, box) {
      final inline =
          box.maxWidth >= 280 &&
          MediaQuery.textScalerOf(context).scale(14) <= 18;
      final label = Text(
        'Primary card',
        style: Theme.of(context).textTheme.labelMedium,
      );
      final toggle = Tooltip(
        message: 'Show this card first in your wallet',
        child: MergeSemantics(
          child: inline
              ? Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [label, _switch(context)],
                )
              : Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [label, _switch(context)],
                ),
        ),
      );
      return inline
          ? Row(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                Expanded(child: purpose),
                const SizedBox(width: 12),
                SizedBox(width: 108, child: toggle),
              ],
            )
          : Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [purpose, const SizedBox(height: 4), toggle],
            );
    },
  );
}
