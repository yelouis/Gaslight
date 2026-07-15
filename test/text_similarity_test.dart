import 'package:flutter_test/flutter_test.dart';
import 'package:gaslight/utils/text_similarity.dart';

void main() {
  group('Text Similarity Heuristic Tests (Dart)', () {
    test('Normalization and stemming', () {
      expect(TextSimilarity.normalize("Sleeping!"), "sleeping");
      expect(TextSimilarity.normalize("hello   world!!"), "hello world");

      expect(TextSimilarity.stem("sleeping"), "sleep");
      expect(TextSimilarity.stem("played"), "play");
      expect(TextSimilarity.stem("places"), "plac");
      expect(TextSimilarity.stem("dogs"), "dog");
      expect(TextSimilarity.stem("class"), "class"); // ends in ss
      expect(TextSimilarity.stem("quickly"), "quick");
    });

    group('Worked cases matrix', () {
      final testCases = [
        {'candidate': 'Sleeping!', 'existing': 'sleeping', 'expected': true},
        {'candidate': 'sleeping in my bed all day', 'existing': 'sleep all day in bed', 'expected': true},
        {'candidate': 'the dog ate the homework', 'existing': 'my dog ate my homework', 'expected': true},
        {'candidate': 'pizza', 'existing': 'pizza with pineapple', 'expected': false},
        {'candidate': 'a quick nap', 'existing': 'sleeping', 'expected': false},
        {'candidate': 'went to the club', 'existing': 'clubbing downtown', 'expected': false},
        {'candidate': 'hello world', 'existing': '', 'expected': false}
      ];

      for (var tc in testCases) {
        final candidate = tc['candidate'] as String;
        final existing = tc['existing'] as String;
        final expected = tc['expected'] as bool;

        test('candidate: "$candidate" vs existing: "$existing"', () {
          expect(TextSimilarity.isTooSimilar(candidate, [existing]), expected);
        });
      }
    });

    test('Edge cases', () {
      expect(TextSimilarity.isTooSimilar("hello", []), false);
      expect(TextSimilarity.isTooSimilar("abc", ["abc"]), true);
    });
  });
}
