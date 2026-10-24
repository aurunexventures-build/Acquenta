import '../models/saved_connection.dart';

/// Factual grouping from shared profile fields. Never mines private memory notes.
abstract final class ConnectionInsights {
  static const _groups = {
    'Tech':
        r'\b(software|developer|engineer|architect|programmer|flutter|android|ios|ai|it|cloud|python|data|robotics)\b',
    'Creators':
        r'\b(creator|influencer|artist|photographer|youtube|instagram|video|writer|writing|content)\b',
    'Design': r'\b(design|designer|ux|ui|branding|illustration|creative)\b',
    'Students': r'\b(student|undergraduate|postgraduate|university|college)\b',
    'Business':
        r'\b(founder|entrepreneur|consultant|marketing|sales|business|manager)\b',
    'Health': r'\b(doctor|nurse|health|medical|therapist|fitness)\b',
    'Finance': r'\b(finance|accountant|accounting|banking|investment)\b',
    'Education': r'\b(teacher|lecturer|professor|education|tutor)\b',
  };
  static bool matches(SavedConnection card, String filter) {
    if (filter == 'All') return true;
    if (filter == 'Favourites') return card.isFavorite;
    if (filter.startsWith('skill:')) {
      return card.techStack.any(
        (s) => s.trim().toLowerCase() == filter.substring(6).toLowerCase(),
      );
    }
    final pattern = _groups[filter];
    return pattern != null &&
        RegExp(
          pattern,
          caseSensitive: false,
        ).hasMatch('${card.role} ${card.headline} ${card.techStack.join(' ')}');
  }

  static List<String> filters(List<SavedConnection> cards) {
    final counts = {
      for (final group in _groups.keys)
        group: cards.where((card) => matches(card, group)).length,
    };
    final groups = counts.keys.where((key) => counts[key]! > 0).toList()
      ..sort((a, b) {
        final count = counts[b]!.compareTo(counts[a]!);
        return count == 0 ? a.compareTo(b) : count;
      });
    final result = [
      'All',
      if (cards.any((card) => card.isFavorite)) 'Favourites',
      ...groups.take(4),
    ];
    // Include a useful shared skill when occupations don't fit the broad groups.
    if (groups.isEmpty) {
      final skills = <String, String>{};
      for (final card in cards) {
        for (final skill in card.techStack) {
          final value = skill.trim();
          if (value.isNotEmpty && value.length <= 24) {
            skills.putIfAbsent(value.toLowerCase(), () => value);
          }
        }
      }
      result.addAll(skills.values.take(3).map((s) => 'skill:$s'));
    }
    return result;
  }

  static String label(String filter) =>
      filter.startsWith('skill:') ? filter.substring(6) : filter;
  static List<String> topics(SavedConnection card) {
    final values = <String, String>{};
    for (final skill in card.techStack) {
      final value = skill.trim();
      if (value.isNotEmpty) {
        values.putIfAbsent(value.toLowerCase(), () => value);
      }
    }
    if (values.isEmpty && card.role.trim().isNotEmpty) {
      values[card.role.toLowerCase()] = card.role.trim();
    }
    return values.values.toList();
  }
}
