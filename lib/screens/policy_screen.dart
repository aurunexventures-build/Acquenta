import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

enum PolicyKind { privacy, terms }

class PolicyScreen extends StatelessWidget {
  final PolicyKind kind;
  const PolicyScreen({super.key, required this.kind});
  static const _privacy = <(String, String)>[
    (
      'Who operates Acquenta',
      'Acquenta is provided by AuruNex Ventures. For privacy questions or requests, email aurunex.ventures@gmail.com or use the contact options at aurunex.com. This notice describes the current Acquenta app.',
    ),
    (
      'Information you choose to save',
      'Your wallet can contain names, email addresses, phone numbers, links, skills, meeting context, private notes, photos and follow-up reminders. Account sign-in is handled by Firebase Authentication. Use care when saving information about other people; avoid unnecessary sensitive details.',
    ),
    (
      'Device storage and cloud sync',
      'Local wallets and drafts are stored on your device. When signed in, your wallet can automatically sync to your account through Cloudflare services. Firebase handles account authentication; Cloudflare D1 stores wallet records, R2 stores uploaded photos, and Vectorize supports semantic recall. These providers may process information outside your country under their own service arrangements. Your device backups and exported files may create additional copies.',
    ),
    (
      'AI, voice and photos',
      'AI features send relevant saved text and your requests to Groq or Cloudflare Workers AI. Cloud voice sends recorded replies to Groq for transcription and generates spoken replies through Groq; some device speech features may use device providers. Acquenta does not continuously record conversations. Paper-card text recognition runs on-device. Photos you upload, including private wallet photos, are sent to Google Cloud Vision for safety screening and text detection. Text detected in a photo may be sent to OpenAI for moderation. Rejected uploads are not stored; existing server photos are also checked before being served. Local-only photos are checked when uploaded. Card and account text you save while signed in is also screened by Google Cloud Natural Language for profanity and abusive content before saving to the cloud or sharing. Private connection notes are excluded from this text check. Local profanity rules also apply before saving on your device. These checks can make mistakes.',
    ),
    (
      'Sharing is your choice',
      'Publishing a card creates a link that others can open. QR codes, vCards and calendar exports share the information included in them with their recipients. Private memory history is excluded from shared vCards. Revoking a link cannot recall a copy someone already saved. Links to other websites are governed by those websites’ policies.',
    ),
    (
      'Permissions and notifications',
      'Camera, photo, microphone, speech and notification permissions are requested for relevant features. You can change permissions in device settings. Optional device alerts show generic reminder text. Acquenta has no advertising feed; we do not use your wallet to display targeted ads.',
    ),
    (
      'Retention and deletion',
      'Wallet information remains until you delete it or request removal. Deleting a connection creates a sync deletion record so old devices do not restore it. Signing out does not erase the account’s local cache. Deleting the app does not delete a synced account or recipient copies. You can delete your account from Account & privacy. Limited deletion markers and moderation audit records support security and prevent restoration of deleted data. Account deletion removes image-safety decisions; anonymised usage totals remain to enforce service limits. Contact us for information about provider backups and retention.',
    ),
    (
      'Your choices and rights',
      'You can edit contacts, delete connections, revoke published links and control permissions. To delete your account, open Account & privacy → Delete account and confirm your sign-in. This removes your login and active cloud wallet, photos and search entries, and clears account data from the requesting device. An opaque account ID is retained solely to block old tokens and devices from restoring deleted data. Exported/shared copies, offline devices and provider backups may retain copies; backup expiry follows provider retention arrangements. You may request access, correction, deletion, restriction, objection or a copy of your personal information, depending on applicable law. Contact AuruNex Ventures using the website below. UK users may also raise concerns with the Information Commissioner’s Office at ico.org.uk.',
    ),
    (
      'Why information is processed',
      'Account and wallet information is used to provide the features you request. Optional permissions and features are controlled by your choices. Basic security and operational processing supports a reliable service. Acquenta’s AI suggestions are editable and may be inaccurate.',
    ),
  ];
  static const _terms = <(String, String)>[
    (
      'Using Acquenta',
      'Acquenta helps you exchange contact details, keep private meeting cues and reconnect. Use the app lawfully, protect your account, and only save or share information you are entitled to use. Do not use it to harass people, impersonate others or collect information unlawfully.',
    ),
    (
      'Your content and sharing',
      'You remain responsible for the accuracy and appropriateness of your cards, notes, photos and shared links. Choose carefully what you publish or export. Other people may retain copies you give them. Respect the privacy and rights of people in your wallet.',
    ),
    (
      'AI and reminders',
      'AI suggestions and text recognition can be wrong. Review extracted details and generated text before saving or sending. Notifications depend on device permissions, battery settings and scheduling limits; do not rely on Acquenta for urgent or critical reminders.',
    ),
    (
      'Availability and device copies',
      'Features vary by platform and may need internet access or third-party services. Keep copies of information you need. Local-only data may be lost if app data is removed. Cloud sync, service availability and recovery are not guaranteed to be uninterrupted.',
    ),
    (
      'Your legal rights',
      'Nothing in these terms removes rights or remedies that cannot lawfully be excluded. These terms do not transfer ownership of your personal content to Acquenta. The Privacy Policy explains current data handling and the available contact route.',
    ),
    (
      'Contact and updates',
      'Acquenta is provided by AuruNex Ventures. Contact us through aurunex.com about the app or these terms. Policy updates will be made available in the app; review them when using new features.',
    ),
  ];
  @override
  Widget build(BuildContext context) {
    final title = kind == PolicyKind.privacy
        ? 'Privacy Policy'
        : 'Terms of Use';
    return Scaffold(
      appBar: AppBar(title: Text(title)),
      body: SafeArea(
        child: SelectionArea(
          child: ListView(
            padding: const EdgeInsets.all(20),
            children: [
              Center(
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 680),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Acquenta • Updated 18 October 2026',
                        style: Theme.of(context).textTheme.bodySmall,
                      ),
                      const SizedBox(height: 16),
                      for (final section
                          in kind == PolicyKind.privacy
                              ? _privacy
                              : _terms) ...[
                        Text(
                          section.$1,
                          style: Theme.of(context).textTheme.titleMedium,
                        ),
                        const SizedBox(height: 6),
                        Text(section.$2),
                        const SizedBox(height: 20),
                      ],
                      OutlinedButton.icon(
                        onPressed: () async {
                          final uri = Uri.parse('https://aurunex.com');
                          if (!await launchUrl(
                                uri,
                                mode: LaunchMode.externalApplication,
                              ) &&
                              context.mounted) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(
                                content: Text(
                                  'Visit aurunex.com to contact AuruNex Ventures.',
                                ),
                              ),
                            );
                          }
                        },
                        icon: const Icon(Icons.open_in_new),
                        label: const Text('Contact AuruNex Ventures'),
                      ),
                    ],
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
