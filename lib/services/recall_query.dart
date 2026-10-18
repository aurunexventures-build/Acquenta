/// Shared query words for literal matching, concept matching and live evidence.
abstract final class RecallQuery {
  static const Set<String> _stopWords = {
    'i',
    'me',
    'my',
    'we',
    'our',
    'you',
    'he',
    'him',
    'his',
    'she',
    'her',
    'they',
    'them',
    'the',
    'a',
    'an',
    'is',
    'was',
    'are',
    'were',
    'been',
    'met',
    'meet',
    'meeting',
    'person',
    'someone',
    'guy',
    'who',
    'what',
    'which',
    'that',
    'this',
    'there',
    'at',
    'on',
    'in',
    'with',
    'about',
    'told',
    'doing',
    'does',
    'did',
    'and',
    'or',
    'to',
    'for',
    'from',
    'of',
    'by',
    'hosted',
    'talked',
    'please',
    'find',
    'show',
    'get',
    'need',
    'want',
    'looking',
    'can',
    'could',
    'would',
    'should',
    'have',
    'has',
    'had',
    'be',
    'being',
    'it',
    'its',
    'their',
    'those',
    'these',
    'just',
    'some',
    'any',
    'all',
    'also',
    'as',
    'am',
    'do',
    'so',
    'then',
  };

  static List<String> terms(String query) => query
      .toLowerCase()
      .replaceAll(RegExp(r'[^\w\s\+#]'), ' ')
      .split(RegExp(r'\s+'))
      .where((t) => t.length > 1 && !_stopWords.contains(t))
      .toSet()
      .toList();

  /// Explicit professional intent must have evidence in the person's profile,
  /// rather than merely a shared event or a loose vector similarity.
  static bool supportsProfessionalIntent(String query, String evidence) {
    const groups = [
      [
        'developer',
        'programmer',
        'software',
        'coding',
        'android',
        'flutter',
        'kotlin',
        'ios',
        'swift',
        'react',
        'javascript',
        'python',
        'web development',
        'mobile architect',
        'full-stack',
        'full stack',
        'tech',
      ],
      ['plumber', 'plumbing', 'pipework', 'leaking', 'boiler'],
      ['gardener', 'gardening', 'horticulture', 'landscaping'],
      ['designer', 'design', 'branding', 'graphic', 'ux', 'ui'],
      ['photographer', 'photography', 'videographer'],
      ['accountant', 'accounting', 'bookkeeping'],
    ];
    final requested = groups
        .where((group) => group.any((term) => containsPhrase(query, term)))
        .toList();
    return requested.isEmpty ||
        requested.any(
          (group) => group.any((term) => containsPhrase(evidence, term)),
        );
  }

  /// Match complete words, never fragments such as "and" in "handyman".
  static bool containsPhrase(String text, String phrase) {
    if (phrase.trim().isEmpty) return false;
    return RegExp(
      r'(?<![\w+#])' + RegExp.escape(phrase.trim()) + r'(?![\w+#])',
      caseSensitive: false,
    ).hasMatch(text);
  }
}
