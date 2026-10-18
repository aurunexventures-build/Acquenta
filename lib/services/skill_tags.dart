abstract final class SkillTags {
  static List<String> parse(String text) {
    final tags = <String>[];
    for (final value in text.split(RegExp(r'[,;\n]'))) {
      final tag = value.trim();
      if (tag.isEmpty) continue;
      if (tag.length > 50) {
        throw const FormatException(
          'Each tag must be 50 characters or fewer. Put sentences in the experience box above.',
        );
      }
      if (!tags.any((s) => s.toLowerCase() == tag.toLowerCase())) tags.add(tag);
    }
    if (tags.length > 12) {
      throw const FormatException('Use up to 12 skills or tags.');
    }
    return tags;
  }

  static List<String> merge(List<String> existing, List<String> additions) {
    final merged = parse([...existing, ...additions].join(','));
    return merged;
  }
}
