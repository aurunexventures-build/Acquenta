import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:share_plus/share_plus.dart';
import 'package:url_launcher/url_launcher.dart';
import '../models/contact_card.dart';
import '../providers/cards_provider.dart';
import '../services/vcard_service.dart';
import '../widgets/contact_card_widget.dart';
import '../widgets/qr_share_dialog.dart';
import 'card_editor_screen.dart';

class CardDetailScreen extends StatelessWidget {
  final String cardId;

  const CardDetailScreen({super.key, required this.cardId});

  Color _parseColor(String hex) {
    try {
      final clean = hex.replaceAll('#', '');
      return Color(int.parse('FF$clean', radix: 16));
    } catch (_) {
      return const Color(0xFF2563EB);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cardsProvider = Provider.of<CardsProvider>(context);
    final card = cardsProvider.cards.firstWhere(
      (c) => c.id == cardId,
      orElse: () => cardsProvider.cards.isNotEmpty
          ? cardsProvider.cards.first
          : ContactCard(
              id: '',
              title: '',
              fullName: 'Not Found',
              createdAt: DateTime.now(),
              updatedAt: DateTime.now(),
            ),
    );

    final accentColor = _parseColor(card.themeColorHex);

    return Scaffold(
      appBar: AppBar(
        title: Text(card.title.isNotEmpty ? card.title : 'Visiting Card'),
        actions: [
          IconButton(
            icon: const Icon(Icons.edit_outlined),
            tooltip: 'Edit Card',
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => CardEditorScreen(initialCard: card),
                ),
              );
            },
          ),
          IconButton(
            icon: const Icon(Icons.qr_code_2_rounded),
            tooltip: 'Share QR',
            onPressed: () {
              showDialog(
                context: context,
                builder: (_) => QrShareDialog(
                  card: card,
                  defaultEventContext: cardsProvider.activeEventMode,
                ),
              );
            },
          ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Active Event Alert if currently networking at an event
            if (cardsProvider.activeEventMode != null) ...[
              Container(
                margin: const EdgeInsets.only(bottom: 16),
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                decoration: BoxDecoration(
                  color: Colors.amber.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: Colors.amber.withValues(alpha: 0.4)),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.location_on_rounded, color: Colors.amber, size: 20),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            'Active Event Mode On',
                            style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
                          ),
                          Text(
                            'Sharing will stamp: "${cardsProvider.activeEventMode!.eventName}"',
                            style: const TextStyle(fontSize: 12),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ],

            // Main Visiting Card Display
            ContactCardWidget(
              card: card,
              onShare: () {
                showDialog(
                  context: context,
                  builder: (_) => QrShareDialog(
                    card: card,
                    defaultEventContext: cardsProvider.activeEventMode,
                  ),
                );
              },
            ),

            const SizedBox(height: 24),

            // Quick Sharing Actions Grid
            Row(
              children: [
                Expanded(
                  child: ElevatedButton.icon(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: accentColor,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                    ),
                    icon: const Icon(Icons.qr_code_rounded, size: 20),
                    label: const Text('Show QR Code', style: TextStyle(fontWeight: FontWeight.bold)),
                    onPressed: () {
                      showDialog(
                        context: context,
                        builder: (_) => QrShareDialog(
                          card: card,
                          defaultEventContext: cardsProvider.activeEventMode,
                        ),
                      );
                    },
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: OutlinedButton.icon(
                    style: OutlinedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                    ),
                    icon: const Icon(Icons.contact_page_outlined, size: 20),
                    label: const Text('Export vCard', style: TextStyle(fontWeight: FontWeight.bold)),
                    onPressed: () {
                      final vcard = VCardService.generateVCard(
                        card: card,
                        eventContext: cardsProvider.activeEventMode,
                      );
                      Clipboard.setData(ClipboardData(text: vcard));
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                          content: Text('vCard with full event context copied! Can be pasted into contacts or sent.'),
                        ),
                      );
                    },
                  ),
                ),
              ],
            ),

            const SizedBox(height: 20),

            // Contact Direct Actions
            Card(
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Direct Actions', style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold)),
                    const SizedBox(height: 12),
                    if (card.phone.isNotEmpty)
                      ListTile(
                        contentPadding: EdgeInsets.zero,
                        leading: const CircleAvatar(
                          radius: 18,
                          child: Icon(Icons.phone, size: 18),
                        ),
                        title: const Text('Call / SMS'),
                        subtitle: Text(card.phone),
                        trailing: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            IconButton(
                              icon: const Icon(Icons.call, color: Colors.green),
                              onPressed: () => launchUrl(Uri.parse('tel:${card.phone}')),
                            ),
                            IconButton(
                              icon: const Icon(Icons.sms, color: Colors.blue),
                              onPressed: () => launchUrl(Uri.parse('sms:${card.phone}')),
                            ),
                          ],
                        ),
                      ),
                    if (card.email.isNotEmpty)
                      ListTile(
                        contentPadding: EdgeInsets.zero,
                        leading: const CircleAvatar(
                          radius: 18,
                          child: Icon(Icons.email, size: 18),
                        ),
                        title: const Text('Send Email'),
                        subtitle: Text(card.email),
                        trailing: IconButton(
                          icon: const Icon(Icons.send_rounded, color: Colors.blue),
                          onPressed: () => launchUrl(Uri.parse('mailto:${card.email}')),
                        ),
                      ),
                  ],
                ),
              ),
            ),

            const SizedBox(height: 20),

            // Share Summary String Button
            OutlinedButton.icon(
              icon: const Icon(Icons.share_outlined),
              label: const Text('Share Summary Text via Any App'),
              onPressed: () {
                Share.share(
                  '${card.fullName}\n'
                  '${card.role} @ ${card.company}\n'
                  '${card.headline}\n'
                  'Email: ${card.email} | Phone: ${card.phone}\n'
                  'Tech Stack: ${card.techStack.join(", ")}',
                  subject: '${card.fullName} - Visiting Card',
                );
              },
            ),

            const SizedBox(height: 40),
          ],
        ),
      ),
    );
  }
}
