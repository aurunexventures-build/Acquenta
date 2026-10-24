import 'package:flutter_test/flutter_test.dart';
import 'package:contact_card_builder/services/demo_connections.dart';
import 'package:contact_card_builder/services/search_service.dart';

void main() {
  for (final query in ['techie', 'software engineer']) {
    test(
      '$query includes developers without requiring identical job titles',
      () {
        final matches = SearchService.search(
          connections: demoConnections(),
          query: query,
        ).map((r) => r.connection.fullName).toList();
        expect(matches, containsAll(['Arjun Demo', 'Mei Demo', 'Noah Demo']));
        expect(matches, isNot(contains('Owen Demo')));
      },
    );
  }
}
