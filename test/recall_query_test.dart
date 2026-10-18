import 'package:flutter_test/flutter_test.dart';
import 'package:contact_card_builder/services/demo_connections.dart';
import 'package:contact_card_builder/services/search_service.dart';
import 'package:contact_card_builder/services/cognitive_semantic_engine.dart';

void main() {
  test(
    'multiple professions include both plumber and developer, without handyman',
    () {
      final contacts = demoConnections();
      for (final query in [
        'plumber and developer',
        'developer and plumber',
        'plumber or developer',
      ]) {
        final results = SearchService.search(
          connections: contacts,
          query: query,
        );
        expect(results.map((r) => r.connection.fullName).toSet(), {
          'Owen Demo',
          'Arjun Demo',
          'Mei Demo',
          'Noah Demo',
        });
        expect(
          results.every(
            (r) => r.matchReasons.any((reason) => reason.startsWith('Role:')),
          ),
          isTrue,
        );
        expect(
          results
              .expand((r) => r.matchReasons)
              .any(
                (r) =>
                    r.contains('activates skill') ||
                    r.contains('Skill token match'),
              ),
          isFalse,
        );
      }
      final base = SearchService.search(
        connections: contacts,
        query: 'plumber developer',
      );
      final filler = SearchService.search(
        connections: contacts,
        query: 'please find me a plumber and a developer',
      );
      expect(
        filler.map((r) => r.connection.id),
        base.map((r) => r.connection.id),
      );
      expect(filler.map((r) => r.score), base.map((r) => r.score));
    },
  );

  test(
    'filler-only queries return nothing in literal and concept matching',
    () {
      final contacts = demoConnections();
      for (final query in [
        'and',
        'or',
        'the',
        'please find me someone',
        'and or the with',
      ]) {
        expect(SearchService.queryTerms(query), isEmpty);
        expect(
          SearchService.search(connections: contacts, query: query),
          isEmpty,
        );
        expect(CognitiveSemanticEngine.analyzeQuery(query), isEmpty);
        for (final c in contacts) {
          final activation = CognitiveSemanticEngine.computeActivation(
            query: query,
            contactSkills: c.techStack,
            contactRole: c.role,
            contactHeadline: c.headline,
            contactVibes: c.vibeTags,
            distinctiveMemory: c.distinctiveMemory,
            microContext: c.microContext,
            callWhen: c.callWhen,
            futureSelfNote: c.futureSelfNote,
          );
          expect(activation['score'], 0);
        }
      }
      expect(SearchService.queryTerms('plumber and developer'), [
        'plumber',
        'developer',
      ]);
    },
  );
  test(
    'explicit tech developer intent never returns a plumber from shared context',
    () {
      final results = SearchService.search(
        connections: demoConnections(),
        query: 'I met a tech developer',
      );
      expect(results, isNotEmpty);
      expect(results.any((r) => r.connection.fullName == 'Owen Demo'), isFalse);
      expect(
        results.every(
          (r) => SearchService.supportsIntent(r.connection, 'tech developer'),
        ),
        isTrue,
      );
    },
  );
}
