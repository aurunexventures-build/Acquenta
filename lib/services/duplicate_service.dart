import 'dart:convert';
import 'package:uuid/uuid.dart';
import '../models/saved_connection.dart';
import '../models/interaction.dart';

class DuplicateService {
  static String _email(String s) => s.trim().toLowerCase();
  static String _phone(String s) =>
      s.replaceAll(RegExp(r'[^0-9]'), '').replaceFirst(RegExp(r'^00'), '');
  static String _name(String s) =>
      s.trim().toLowerCase().replaceAll(RegExp(r'\s+'), ' ');
  static String? reason(SavedConnection a, SavedConnection b) {
    if (a.id == b.id) return 'Same contact ID';
    if (_email(a.email).isNotEmpty && _email(a.email) == _email(b.email)) {
      return 'Same email address';
    }
    final phone = _phone(a.phone);
    if (phone.length >= 7 && phone == _phone(b.phone)) {
      return 'Same phone number';
    }
    if (_name(a.fullName).isNotEmpty &&
        _name(a.company).isNotEmpty &&
        _name(a.fullName) == _name(b.fullName) &&
        _name(a.company) == _name(b.company)) {
      return 'Same name and company';
    }
    return null;
  }

  static List<SavedConnection> matches(
    SavedConnection incoming,
    List<SavedConnection> existing,
  ) => existing.where((c) => reason(c, incoming) != null).toList();

  static SavedConnection merge(SavedConnection keep, SavedConnection incoming) {
    String fill(String a, String b) => a.trim().isEmpty ? b : a;
    final archive = Map<String, dynamic>.from(incoming.toJson())
      ..remove('avatarUrl')
      ..remove('interactions');
    // Keep a complete source record (apart from its photo bytes) as private history.
    final text =
        'Merged contact details (source photo excluded):\n${jsonEncode(archive)}';
    if (text.length > 26000) {
      throw StateError('Source is too large to merge. Keep both contacts.');
    }
    final archiveId = const Uuid().v5(
      Namespace.url.value,
      'merge:${keep.id}:${incoming.id}:${incoming.updatedAt.toIso8601String()}',
    );
    final history = {
      for (final item in [...keep.interactions, ...incoming.interactions])
        item.id: item,
      archiveId: Interaction(
        id: archiveId,
        at: DateTime.now(),
        text: text,
        kind: 'cue',
      ),
    };
    final links = {
      for (final link in [...keep.links, ...incoming.links]) link.url: link,
    }.values.toList();
    final skills = {...keep.techStack, ...incoming.techStack}.toList();
    final vibes = {...keep.vibeTags, ...incoming.vibeTags}.toList();
    final triggers = {...keep.callWhen, ...incoming.callWhen}.toList();
    if (links.length > 20 ||
        skills.length > 30 ||
        vibes.length > 30 ||
        triggers.length > 30 ||
        history.length > 100 ||
        utf8
                .encode(
                  jsonEncode(history.values.map((e) => e.toJson()).toList()),
                )
                .length >
            200000) {
      throw StateError(
        'Combined contact exceeds the sync limits. Keep both contacts.',
      );
    }
    final takeReminder =
        keep.followUpAt == null ||
        keep.followUpCompleted &&
            incoming.followUpAt != null &&
            !incoming.followUpCompleted;
    return keep.copyWith(
      role: fill(keep.role, incoming.role),
      company: fill(keep.company, incoming.company),
      headline: fill(keep.headline, incoming.headline),
      email: fill(keep.email, incoming.email),
      phone: fill(keep.phone, incoming.phone),
      avatarUrl: fill(keep.avatarUrl, incoming.avatarUrl),
      links: links,
      techStack: skills,
      vibeTags: vibes,
      callWhen: triggers,
      interactions: history.values.toList(),
      isFavorite: keep.isFavorite || incoming.isFavorite,
      followUpAt: takeReminder ? incoming.followUpAt : keep.followUpAt,
      followUpNote: takeReminder ? incoming.followUpNote : keep.followUpNote,
      followUpCompleted: takeReminder
          ? incoming.followUpCompleted
          : keep.followUpCompleted,
    );
  }
}
