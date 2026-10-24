abstract final class TextSafety {
  static final _profanity = RegExp(
    r'(^|[^\p{L}\p{N}])(?:(?:mother[\s._*\-]*)?f[\s._*\-]*[u*@][\s._*\-]*c[\s._*\-]*k(?:s|ed|ing|er|ers)?|f\*{1,3}k|bullshit|sh[i1]t(?:s|ty|ting)?|b[i1]tch(?:es)?|c[u*]nt(?:s)?|a(?:ss|rse)hole(?:s)?|bastard(?:s)?)(?![\p{L}\p{N}])',
    unicode: true,
    caseSensitive: false,
  );
  static bool hasProfanity(String value) {
    final folded = String.fromCharCodes(
      value.runes.map(
        (code) => code >= 0xff01 && code <= 0xff5e ? code - 0xfee0 : code,
      ),
    );
    return _profanity.hasMatch(
      folded.replaceAll(RegExp(r'[\u200B-\u200D\uFEFF]'), ''),
    );
  }

  static void validate(Iterable<String> values) {
    if (values.any(hasProfanity)) {
      throw const FormatException(
        'Please remove profanity or abusive language before saving.',
      );
    }
  }

  static void validateFields(Map<String, dynamic> value) {
    final fields = <String>[];
    for (final key in [
      'fullName',
      'firstName',
      'lastName',
      'role',
      'company',
      'headline',
      'bio',
      'location',
      'intro',
    ]) {
      if (value[key] is String) fields.add(value[key] as String);
    }
    fields.addAll((value['techStack'] as List? ?? []).whereType<String>());
    for (final link in value['links'] as List? ?? []) {
      if (link is Map && link['title'] is String) {
        fields.add(link['title'] as String);
      }
    }
    validate(fields);
  }
}
