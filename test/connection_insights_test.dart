import 'package:flutter_test/flutter_test.dart';
import 'package:contact_card_builder/models/event_context.dart';
import 'package:contact_card_builder/models/saved_connection.dart';
import 'package:contact_card_builder/services/connection_insights.dart';

SavedConnection person(
  String role, {
  List<String> skills = const [],
  String memory = '',
}) => SavedConnection(
  id: role,
  fullName: 'Sam',
  role: role,
  techStack: skills,
  rawCue: memory,
  callWhen: ['Private investment idea'],
  eventContext: EventContext(
    eventName: 'Private AI meetup',
    date: DateTime(2026),
  ),
  savedAt: DateTime(2026),
);
void main() {
  test('filters reflect received cards and ignore private memories', () {
    final doctor = person('Doctor', memory: 'Works near a software developer');
    expect(ConnectionInsights.filters([doctor]), ['All', 'Health']);
    expect(ConnectionInsights.matches(doctor, 'Tech'), isFalse);
    final creator = person('Video creator');
    expect(
      ConnectionInsights.filters([doctor, creator]),
      containsAll(['All', 'Health', 'Creators']),
    );
    expect(ConnectionInsights.filters([creator]), isNot(contains('Health')));
    expect(ConnectionInsights.filters([]), ['All']);
    expect(
      ConnectionInsights.filters([creator.copyWith(isFavorite: true)]),
      contains('Favourites'),
    );
  });
  test('conversation starters use only facts shared on the card', () {
    final c = person('Student', skills: ['Robotics', 'robotics', ' Music ']);
    expect(ConnectionInsights.topics(c), ['Robotics', 'Music']);
    expect(ConnectionInsights.topics(person('Teacher')), ['Teacher']);
    final niche = person('', skills: ['Pottery']);
    expect(ConnectionInsights.filters([niche]), ['All', 'skill:Pottery']);
    expect(ConnectionInsights.matches(niche, 'skill:Pottery'), isTrue);
  });
}
