import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../models/contact_card.dart';
import '../providers/cards_provider.dart';
import 'card_colour_picker.dart';
import 'card_finish_picker.dart';

/// Appearance edits are drafts until Save; identity and private settings are retained.
class CustomizeCardDialog extends StatefulWidget {
  final ContactCard card;
  const CustomizeCardDialog({super.key, required this.card});
  @override
  State<CustomizeCardDialog> createState() => _CustomizeCardDialogState();
}

class _CustomizeCardDialogState extends State<CustomizeCardDialog> {
  late String finish = widget.card.cardFinish;
  late String colour = widget.card.themeColorHex;
  bool saving = false;
  String? error;
  Future<void> save() async {
    final provider = context.read<CardsProvider>();
    final current = provider.cards
        .where((c) => c.id == widget.card.id)
        .firstOrNull;
    if (current == null) {
      setState(() => error = 'This card is no longer available.');
      return;
    }
    setState(() => saving = true);
    try {
      await provider.updateCard(
        current.copyWith(cardFinish: finish, themeColorHex: colour),
      );
      if (mounted) {
        Navigator.pop(context);
      }
    } catch (_) {
      if (mounted) {
        setState(() {
          saving = false;
          error = 'Could not save. Please try again.';
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) => PopScope(
    canPop: !saving,
    child: AlertDialog(
      title: const Text('Customize your card'),
      content: SizedBox(
        width: 420,
        child: SingleChildScrollView(
          child: AbsorbPointer(
            absorbing: saving,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                CardFinishPicker(
                  value: finish,
                  colour: colour,
                  name: widget.card.fullName,
                  onChanged: (value) => setState(() => finish = value),
                ),
                const SizedBox(height: 8),
                const Text(
                  'Card colour',
                  style: TextStyle(fontWeight: FontWeight.w600),
                ),
                const SizedBox(height: 10),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children:
                      const {
                            'Blue': '#244F83',
                            'Evergreen': '#234B42',
                            'Ink': '#343B49',
                            'Clay': '#895E4B',
                            'Aubergine': '#55445E',
                          }.entries
                          .map(
                            (entry) => ChoiceChip(
                              label: Text(entry.key),
                              avatar: CircleAvatar(
                                radius: 6,
                                backgroundColor: Color(
                                  int.parse(
                                        entry.value.substring(1),
                                        radix: 16,
                                      ) |
                                      0xFF000000,
                                ),
                              ),
                              selected: colour.toUpperCase() == entry.value,
                              onSelected: (_) =>
                                  setState(() => colour = entry.value),
                            ),
                          )
                          .toList(),
                ),
                CardColourPicker(
                  value: colour,
                  onChanged: (value) => setState(() => colour = value),
                ),
                if (error != null)
                  Text(
                    error!,
                    style: TextStyle(
                      color: Theme.of(context).colorScheme.error,
                    ),
                  ),
              ],
            ),
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: saving ? null : () => Navigator.pop(context),
          child: const Text('Cancel'),
        ),
        FilledButton(
          onPressed: saving ? null : save,
          child: Text(saving ? 'Saving…' : 'Save appearance'),
        ),
      ],
    ),
  );
}
