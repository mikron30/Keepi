import 'package:flutter_test/flutter_test.dart';
import 'package:keepi/features/inventory/domain/thing.dart';

void main() {
  test('Thing serializes core fields', () {
    final now = DateTime.utc(2026, 9, 23);

    final thing = Thing(
      id: 'thing-1',
      ownerId: 'user-1',
      name: 'Ladder',
      categoryId: 'tools',
      createdAt: now,
      updatedAt: now,
      enabledActions: const {
        ThingAction.rent,
        ThingAction.borrow,
      },
    );

    final map = thing.toMap();

    expect(map['name'], 'Ladder');
    expect(map['categoryId'], 'tools');
    expect(map['visibility'], 'private');
    expect(map['enabledActions'], contains('rent'));
    expect(map['enabledActions'], contains('borrow'));
  });
}
