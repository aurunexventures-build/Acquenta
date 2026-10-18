import 'recall_query.dart';
import '../models/saved_connection.dart';
import 'cognitive_semantic_engine.dart';

class SearchResult {
  final SavedConnection connection;
  final double score;
  final List<String> matchReasons;
  final String cognitiveReason;
  final String activatedDomain;

  const SearchResult({
    required this.connection,
    required this.score,
    required this.matchReasons,
    this.cognitiveReason = '',
    this.activatedDomain = '',
  });
}

class SearchService {
  static List<String> queryTerms(String query) => RecallQuery.terms(query);

  static bool supportsIntent(SavedConnection connection, String query) =>
      RecallQuery.supportsProfessionalIntent(
        query,
        [
          connection.role,
          connection.headline,
          ...connection.techStack,
          connection.rawCue,
        ].join(' '),
      );

  static int matchedTermCount(SavedConnection connection, String query) {
    final evidence = [
      connection.fullName,
      connection.role,
      connection.company,
      connection.headline,
      ...connection.techStack,
      connection.eventContext.eventName,
      connection.eventContext.notes,
      connection.rawCue,
      connection.distinctiveMemory,
      connection.microContext,
      connection.futureSelfNote,
      ...connection.callWhen,
      ...connection.interactions.map((item) => item.text),
    ].join(' ');
    return queryTerms(
      query,
    ).where((term) => RecallQuery.containsPhrase(evidence, term)).length;
  }

  /// Performs contextual memory recall search across connections
  static List<SearchResult> search({
    required List<SavedConnection> connections,
    required String query,
    String? filterEvent,
    String? filterTechStack,
    String? filterVibe,
  }) {
    final cleanedQuery = query.trim().toLowerCase();

    final searchTokens = queryTerms(query);
    // A nonempty request made only of filler words must not recall everyone.
    if (cleanedQuery.isNotEmpty && searchTokens.isEmpty) return [];

    final results = <SearchResult>[];

    for (final conn in connections) {
      if (!supportsIntent(conn, query)) continue;
      // Event filter check
      if (filterEvent != null && filterEvent.isNotEmpty) {
        if (!conn.eventContext.eventName.toLowerCase().contains(
          filterEvent.toLowerCase(),
        )) {
          continue;
        }
      }

      // Tech stack filter check
      if (filterTechStack != null && filterTechStack.isNotEmpty) {
        final hasTech =
            conn.techStack.any(
              (t) => t.toLowerCase() == filterTechStack.toLowerCase(),
            ) ||
            conn.eventContext.tags.any(
              (t) => t.toLowerCase() == filterTechStack.toLowerCase(),
            );
        if (!hasTech) {
          continue;
        }
      }

      // Vibe filter check
      if (filterVibe != null && filterVibe.isNotEmpty) {
        final hasVibe = conn.vibeTags.any(
          (v) => v.toLowerCase() == filterVibe.toLowerCase(),
        );
        if (!hasVibe) {
          continue;
        }
      }

      // If query is empty but filters are applied, return all matching connections
      if (cleanedQuery.isEmpty) {
        results.add(
          SearchResult(
            connection: conn,
            score: 1.0,
            matchReasons: [
              if (filterEvent != null) 'Event: "$filterEvent"',
              if (filterTechStack != null) 'Skill: "$filterTechStack"',
              if (filterVibe != null) 'Vibe: "$filterVibe"',
            ],
          ),
        );
        continue;
      }

      double score = 0.0;
      final matchReasons = <String>{};

      final eventNameLower = conn.eventContext.eventName.toLowerCase();
      final eventNotesLower = conn.eventContext.notes.toLowerCase();
      final eventLocLower = conn.eventContext.location.toLowerCase();
      final fullNameLower = conn.fullName.toLowerCase();
      final roleLower = conn.role.toLowerCase();
      final companyLower = conn.company.toLowerCase();
      final headlineLower = conn.headline.toLowerCase();
      final futureSelfLower = conn.futureSelfNote.toLowerCase();
      final memoryFields = {
        'Original cue': conn.rawCue,
        'Interaction history': conn.interactions.map((e) => e.text).join(' '),
        'Follow-up': conn.followUpNote,
        'Conversation': conn.cueConversation.map((e) => e['answer']).join(' '),
        'Distinctive memory': conn.distinctiveMemory,
        'Meeting scene': conn.microContext,
        'Reach out when': conn.callWhen.join(', '),
      };

      // Combine tags and tech stack
      final allTags = {
        ...conn.techStack.map((t) => t.toLowerCase()),
        ...conn.eventContext.tags.map((t) => t.toLowerCase()),
      };

      // 1. Full phrase matches
      if (eventNameLower.isNotEmpty &&
          (cleanedQuery.contains(eventNameLower) ||
              eventNameLower.contains(cleanedQuery))) {
        score += 80.0;
        matchReasons.add('Event: "${conn.eventContext.eventName}"');
      }
      if (eventNotesLower.isNotEmpty &&
          (cleanedQuery.contains(eventNotesLower) ||
              eventNotesLower.contains(cleanedQuery))) {
        score += 60.0;
        matchReasons.add(
          'Meeting Notes: "${_snippet(conn.eventContext.notes, cleanedQuery)}"',
        );
      }
      if (futureSelfLower.isNotEmpty &&
          (cleanedQuery.contains(futureSelfLower) ||
              futureSelfLower.contains(cleanedQuery))) {
        score += 75.0;
        matchReasons.add(
          'Note to Future Self: "${_snippet(conn.futureSelfNote, cleanedQuery)}"',
        );
      }

      // 2. Token based matching
      final matchedEventTokens = <String>{};
      final matchedTechTokens = <String>{};
      final matchedNotesTokens = <String>{};
      final matchedVibeTokens = <String>{};
      final matchedFutureTokens = <String>{};

      for (final token in searchTokens) {
        // Vibe Tags Match (High priority for human impression / intent)
        for (final vibe in conn.vibeTags) {
          final vibeLower = vibe.toLowerCase();
          if ((vibeLower == token ||
                  RecallQuery.containsPhrase(vibeLower, token)) &&
              !matchedVibeTokens.contains(vibeLower)) {
            matchedVibeTokens.add(vibeLower);
            score += (vibeLower == token) ? 55.0 : 40.0;
            matchReasons.add('Vibe: "$vibe"');
          }
        }

        // Note to Future Self Match (The personal touch / gut instinct)
        if (RecallQuery.containsPhrase(futureSelfLower, token) &&
            !matchedFutureTokens.contains(token)) {
          matchedFutureTokens.add(token);
          score += 45.0;
          matchReasons.add(
            'Future Self: "${_snippet(conn.futureSelfNote, token)}"',
          );
        }

        // Event Name Match
        if (RecallQuery.containsPhrase(eventNameLower, token) &&
            !matchedEventTokens.contains(token)) {
          matchedEventTokens.add(token);
          score += 20.0;
          matchReasons.add('Event: "${conn.eventContext.eventName}"');
        }

        // Tech Stack / Skills Match (Direct skill match is prioritized)
        for (final tag in allTags) {
          if ((tag == token || RecallQuery.containsPhrase(tag, token)) &&
              !matchedTechTokens.contains(tag)) {
            matchedTechTokens.add(tag);
            score += (tag == token) ? 60.0 : 35.0;
            final originalTag = conn.techStack.firstWhere(
              (t) => t.toLowerCase() == tag,
              orElse: () => conn.eventContext.tags.firstWhere(
                (t) => t.toLowerCase() == tag,
                orElse: () => tag,
              ),
            );
            matchReasons.add('Skill: "$originalTag"');
          }
        }

        // Event Notes Match (Discussion memory)
        if (RecallQuery.containsPhrase(eventNotesLower, token) &&
            !matchedNotesTokens.contains(token)) {
          matchedNotesTokens.add(token);
          score += 25.0;
          matchReasons.add(
            'Discussion: "${_snippet(conn.eventContext.notes, token)}"',
          );
        }

        // Role & Headline Match
        if (RecallQuery.containsPhrase(roleLower, token) ||
            RecallQuery.containsPhrase(headlineLower, token)) {
          score += 15.0;
          matchReasons.add(
            'Role: "${conn.role.isNotEmpty ? conn.role : conn.headline}"',
          );
        }

        // Company Match
        if (RecallQuery.containsPhrase(companyLower, token)) {
          score += 12.0;
          matchReasons.add('Company: "${conn.company}"');
        }

        // Location Match
        if (RecallQuery.containsPhrase(eventLocLower, token)) {
          score += 10.0;
          matchReasons.add('Location: "${conn.eventContext.location}"');
        }

        // Name Match
        if (RecallQuery.containsPhrase(fullNameLower, token)) {
          score += 15.0;
          matchReasons.add('Name: "${conn.fullName}"');
        }
      }

      for (final entry in memoryFields.entries) {
        final value = entry.value.toLowerCase();
        final matches = searchTokens
            .where((token) => RecallQuery.containsPhrase(value, token))
            .toSet();
        if (matches.isNotEmpty) {
          score += matches.length * 40;
          matchReasons.add(
            '${entry.key}: "${_snippet(entry.value, matches.first)}"',
          );
        }
      }
      // Each requested profession is an independent direct match. A query
      // such as "plumber and developer" includes either role, not only one.
      final roleTerms = searchTokens.where(
        (term) =>
            term.length >= 3 && RecallQuery.containsPhrase(roleLower, term),
      );
      score += roleTerms.length * 200;
      // 3. Cognitive Semantic Spreading Activation Engine
      final activation = CognitiveSemanticEngine.computeActivation(
        query: cleanedQuery,
        contactSkills: conn.techStack,
        contactRole: conn.role,
        contactHeadline: conn.headline,
        contactVibes: conn.vibeTags,
        distinctiveMemory: conn.distinctiveMemory,
        microContext: conn.microContext,
        callWhen: conn.callWhen,
        futureSelfNote: conn.futureSelfNote,
      );

      final double cognitiveScore =
          (activation['score'] as num?)?.toDouble() ?? 0.0;
      final String cognitiveReason = activation['reason'] as String? ?? '';
      final String activatedDomain = activation['concept'] as String? ?? '';

      if (cognitiveScore > 0) {
        score += cognitiveScore;
        if (cognitiveReason.isNotEmpty) {
          matchReasons.add(cognitiveReason);
        }
      }

      if (score > 0) {
        results.add(
          SearchResult(
            connection: conn,
            score: score,
            matchReasons: matchReasons.toList(),
            cognitiveReason: cognitiveReason,
            activatedDomain: activatedDomain,
          ),
        );
      }
    }

    // Sort by relevance score descending
    results.sort((a, b) {
      final direct = matchedTermCount(
        b.connection,
        query,
      ).compareTo(matchedTermCount(a.connection, query));
      if (direct != 0) return direct;
      final relevance = b.score.compareTo(a.score);
      return relevance != 0
          ? relevance
          : b.connection.savedAt.compareTo(a.connection.savedAt);
    });
    return results;
  }

  /// Extracts unique events across connections
  static List<String> extractUniqueEvents(List<SavedConnection> connections) {
    final events = connections
        .map((c) => c.eventContext.eventName.trim())
        .where((e) => e.isNotEmpty)
        .toSet()
        .toList();
    events.sort();
    return events;
  }

  /// Extracts unique tech stack tags across connections
  static List<String> extractUniqueTechStacks(
    List<SavedConnection> connections,
  ) {
    final tags = <String>{};
    for (final c in connections) {
      tags.addAll(c.techStack);
      tags.addAll(c.eventContext.tags);
    }
    final list = tags.where((t) => t.trim().isNotEmpty).toList();
    list.sort();
    return list;
  }

  /// Extracts unique vibe impressions across connections
  static List<String> extractUniqueVibes(List<SavedConnection> connections) {
    final vibes = <String>{};
    for (final c in connections) {
      vibes.addAll(c.vibeTags);
    }
    final list = vibes.where((v) => v.trim().isNotEmpty).toList();
    list.sort();
    return list;
  }

  static String _snippet(String fullText, String match) {
    if (fullText.isEmpty) return '';
    final index = fullText.toLowerCase().indexOf(match.toLowerCase());
    if (index == -1) {
      return fullText.length > 50
          ? '${fullText.substring(0, 47)}...'
          : fullText;
    }
    final start = (index - 20) > 0 ? (index - 20) : 0;
    final end = (index + match.length + 25) < fullText.length
        ? (index + match.length + 25)
        : fullText.length;
    final snippet = fullText.substring(start, end).trim();
    return '${start > 0 ? '...' : ''}$snippet${end < fullText.length ? '...' : ''}';
  }
}
