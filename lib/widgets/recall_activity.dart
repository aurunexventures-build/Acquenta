import 'package:flutter/material.dart';
import '../models/saved_connection.dart';
import '../services/search_service.dart';

/// Observable matching evidence, not a fabricated model thought process.
class RecallActivity extends StatelessWidget {
  final String query;
  final List<SavedConnection> connections;
  final List<SearchResult> results;
  final bool aiSearching;
  final bool compact;
  const RecallActivity({
    super.key,
    required this.query,
    required this.connections,
    required this.results,
    required this.aiSearching,
    this.compact = false,
  });
  Map<String, String> fields(SavedConnection c) => {
    'Role': '${c.role} ${c.headline}',
    'Skills': c.techStack.join(' '),
    'Event': '${c.eventContext.eventName} ${c.eventContext.location}',
    'Notes':
        '${c.eventContext.notes} ${c.rawCue} ${c.distinctiveMemory} ${c.microContext} ${c.futureSelfNote} ${c.callWhen.join(' ')} ${c.cueConversation.map((t) => t['answer'] ?? '').join(' ')}',
    'Name': '${c.fullName} ${c.company}',
    'Vibe': c.vibeTags.join(' '),
  };
  @override
  Widget build(BuildContext context) {
    final terms = SearchService.queryTerms(query);
    final groupIds = <String, Set<String>>{};
    final counts = <String, int>{};
    for (final term in terms) {
      var count = 0;
      for (final c in connections) {
        var found = false;
        for (final entry in fields(c).entries) {
          if (entry.value.toLowerCase().contains(term)) {
            found = true;
            (groupIds[entry.key] ??= <String>{}).add(c.id);
          }
        }
        if (found) count++;
      }
      counts[term] = count;
    }
    final groups = groupIds.map((key, ids) => MapEntry(key, ids.length));
    final conceptMatches = results
        .where((r) => r.cognitiveReason.isNotEmpty)
        .length;
    if (compact) {
      return Container(
        padding: const EdgeInsets.all(10),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(12),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                const Icon(
                  Icons.bolt_rounded,
                  size: 16,
                  color: Color(0xFF6554C0),
                ),
                const SizedBox(width: 4),
                const Expanded(
                  child: Text(
                    'Live matching',
                    style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600),
                  ),
                ),
                Text(
                  '${results.length} matches',
                  style: const TextStyle(fontSize: 11),
                ),
              ],
            ),
            if (counts.isNotEmpty)
              Padding(
                padding: const EdgeInsets.only(top: 4),
                child: Text(
                  counts.entries
                      .take(6)
                      .map((entry) => '${entry.key} · ${entry.value}')
                      .join('  /  '),
                  style: const TextStyle(fontSize: 11),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
          ],
        ),
      );
    }
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: const Color(0xFFE5DFEF)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(
                Icons.bolt_rounded,
                color: Color(0xFF6554C0),
                size: 17,
              ),
              const SizedBox(width: 6),
              const Expanded(
                child: Text(
                  'Live matching',
                  style: TextStyle(
                    color: Color(0xFF413A50),
                    fontWeight: FontWeight.w600,
                    fontSize: 13,
                  ),
                ),
              ),
              Text(
                '${connections.length} saved cards',
                style: const TextStyle(color: Color(0xFF92869F), fontSize: 10),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Wrap(
            spacing: 6,
            runSpacing: 6,
            children: counts.entries
                .take(12)
                .map(
                  (entry) => Tooltip(
                    message:
                        '${entry.value} saved contacts contain “${entry.key}”',
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 9,
                        vertical: 6,
                      ),
                      decoration: BoxDecoration(
                        color: entry.value > 0
                            ? const Color(0xFFE8E0F7)
                            : const Color(0xFFF4F2F6),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Text(
                        '${entry.key} · ${entry.value}',
                        style: TextStyle(
                          color: entry.value > 0
                              ? const Color(0xFF6554C0)
                              : const Color(0xFFA69EAD),
                          fontSize: 11,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ),
                )
                .toList(),
          ),
          const SizedBox(height: 10),
          Text(
            groups.isEmpty
                ? 'No literal word matches yet.'
                : groups.entries
                      .map((e) => '${e.key} ${e.value}')
                      .join('  ·  '),
            style: const TextStyle(
              color: Color(0xFF92869F),
              fontSize: 11,
              height: 1.5,
            ),
          ),
          if (conceptMatches > 0)
            Padding(
              padding: const EdgeInsets.only(top: 6),
              child: Text(
                '$conceptMatches related-concept matches',
                style: const TextStyle(color: Color(0xFF6554C0), fontSize: 11),
              ),
            ),
          const SizedBox(height: 8),
          Text(
            aiSearching
                ? 'AI semantic recall is checking related meanings…'
                : 'Local matches ranked from your saved details and memory cues.',
            style: const TextStyle(
              color: Color(0xFF92869F),
              fontSize: 11,
              height: 1.4,
            ),
          ),
        ],
      ),
    );
  }
}

class MatchedEvidence extends StatelessWidget {
  final String text, query;
  final int maxLines;
  const MatchedEvidence({
    super.key,
    required this.text,
    required this.query,
    this.maxLines = 6,
  });
  @override
  Widget build(BuildContext context) {
    final terms = SearchService.queryTerms(query);
    final spans = <TextSpan>[];
    var position = 0;
    if (terms.isNotEmpty) {
      final pattern = RegExp(
        terms.map(RegExp.escape).join('|'),
        caseSensitive: false,
      );
      for (final match in pattern.allMatches(text)) {
        if (match.start > position) {
          spans.add(TextSpan(text: text.substring(position, match.start)));
        }
        spans.add(
          TextSpan(
            text: match.group(0),
            style: const TextStyle(
              color: Color(0xFF6554C0),
              backgroundColor: Color(0xFFE8E0F7),
              fontWeight: FontWeight.w700,
            ),
          ),
        );
        position = match.end;
      }
    }
    if (position < text.length) {
      spans.add(TextSpan(text: text.substring(position)));
    }
    return Text.rich(
      TextSpan(children: spans),
      maxLines: maxLines,
      overflow: TextOverflow.ellipsis,
      style: const TextStyle(
        color: Color(0xFF8B8295),
        fontSize: 12,
        height: 1.6,
      ),
    );
  }
}
