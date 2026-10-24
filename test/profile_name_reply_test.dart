import 'package:flutter_test/flutter_test.dart';
import 'package:contact_card_builder/services/profile_name_reply.dart';

void main() {
  test('local confirmation never discards volunteered work or purpose', () {
    expect(isOnlyProfileNameConfirmation('Yes, use the same name'), isTrue);
    expect(isOnlyProfileNameConfirmation('Yes please'), isTrue);
    expect(isOnlyProfileNameConfirmation('Sure, that works'), isTrue);
    expect(
      isOnlyProfileNameConfirmation(
        'Yes, use the same name. I work as an architect.',
      ),
      isFalse,
    );
    expect(
      isOnlyProfileNameConfirmation('Yes, this card is for an event.'),
      isFalse,
    );
  });
  test(
    'natural confirmations are intent while alternatives remain distinct',
    () {
      for (final reply in [
        'Yes, you can use the same name',
        'Yes please',
        'You can use the same name',
        'Keep my profile name',
        'Sure, that works',
      ]) {
        expect(acceptsProfileName(reply), isTrue, reason: reply);
      }
      for (final reply in [
        'No thanks',
        'Yes, but call me Amit Singh',
        "I don't want the same name",
        'Use another name',
        'Amit Singh',
      ]) {
        expect(acceptsProfileName(reply), isFalse, reason: reply);
      }
    },
  );
}
