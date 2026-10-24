import 'package:flutter/material.dart';
import '../models/contact_card.dart';
import '../providers/cards_provider.dart';

Future<bool> confirmDeleteCard(
  BuildContext context,
  CardsProvider cards,
  ContactCard card,
) async {
  final scope = cards.storageService.scope;
  final confirmed = await showDialog<bool>(
    context: context,
    builder: (dialogContext) => AlertDialog(
      title: const Text('Delete card?'),
      content: Text(
        'Delete “${card.fullName}” from your wallet? This frees up its card slot.',
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(dialogContext, false),
          child: const Text('Cancel'),
        ),
        FilledButton(
          onPressed: () => Navigator.pop(dialogContext, true),
          style: FilledButton.styleFrom(
            backgroundColor: Theme.of(dialogContext).colorScheme.error,
          ),
          child: const Text('Delete card'),
        ),
      ],
    ),
  );
  if (confirmed != true ||
      scope != cards.storageService.scope ||
      !cards.cards.any((c) => c.id == card.id)) {
    return false;
  }
  try {
    await cards.deleteCard(card.id);
    return true;
  } catch (_) {
    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Could not delete the card. Please try again.'),
        ),
      );
    }
    return false;
  }
}
