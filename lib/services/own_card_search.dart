import '../models/contact_card.dart';
import '../models/event_context.dart';
import '../models/saved_connection.dart';
import 'search_service.dart';

/// Match a user's own cards without turning them into saved people.
abstract final class OwnCardSearch {
  static List<ContactCard> search(List<ContactCard> cards, String query) {
    if (query.trim().isEmpty) return [];
    final byId = {for (final card in cards) card.id: card};
    final results = SearchService.search(
      connections: cards
          .map(
            (card) => SavedConnection(
              id: card.id,
              fullName: card.fullName,
              role: card.role,
              company: card.company,
              headline: card.headline,
              techStack: card.techStack,
              eventContext: EventContext(
                eventName: 'Your card',
                date: card.createdAt,
                notes: card.bio,
              ),
              savedAt: card.updatedAt,
            ),
          )
          .toList(),
      query: query,
    );
    return results.map((result) => byId[result.connection.id]!).toList();
  }
}
