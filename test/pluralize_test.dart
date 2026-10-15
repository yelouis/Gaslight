import 'package:flutter_test/flutter_test.dart';
import 'package:gaslight/utils/pluralize.dart';

void main() {
  group('pluralize (AL1, Issue 196)', () {
    test('picks the plural at 0', () {
      expect(pluralize(0, 'vote', 'votes'), 'votes');
    });

    test('picks the singular at exactly 1', () {
      expect(pluralize(1, 'vote', 'votes'), 'vote');
    });

    test('picks the plural at 2', () {
      expect(pluralize(2, 'vote', 'votes'), 'votes');
    });

    test('picks the plural at 10', () {
      expect(pluralize(10, 'vote', 'votes'), 'votes');
    });
  });
}
