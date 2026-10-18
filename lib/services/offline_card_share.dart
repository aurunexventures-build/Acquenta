import 'dart:convert';
import '../models/contact_card.dart';
import '../models/event_context.dart';
import 'vcard_service.dart';

abstract final class OfflineCardShare {
  static String qr(ContactCard card, {EventContext? event}) {
    String encode(ContactCard value, EventContext? context) =>
        VCardService.generateVCard(card: value, eventContext: context);
    final full = encode(card, event);
    if (utf8.encode(full).length <= 2000) return full;
    final basic = card.copyWith(
      avatarUrl: '',
      bio: '',
      headline: '',
      techStack: [],
      links: [],
    );
    final compact = encode(basic, null);
    if (utf8.encode(compact).length <= 2000) return compact;
    return encode(basic.copyWith(role: '', company: ''), null);
  }
}
