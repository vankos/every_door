// Copyright 2022-2025 Ilya Zverev
// This file is a part of Every Door, distributed under GPL v3 or later version.
// Refer to LICENSE file and https://www.gnu.org/licenses/gpl-3.0.html for details.
import 'package:every_door/providers/ai_tags.dart';
import 'package:test/test.dart';

void main() {
  group('parseAiTags', () {
    test('parses a plain JSON object', () {
      expect(parseAiTags('{"amenity": "cafe"}'), {'amenity': 'cafe'});
    });

    test('parses JSON in a markdown fence', () {
      expect(
        parseAiTags(
            'Here are the tags:\n```json\n{"shop": "bakery", "name": "Хлеб"}\n```'),
        {'shop': 'bakery', 'name': 'Хлеб'},
      );
    });

    test('skips empty and invalid entries', () {
      expect(
        parseAiTags(
            '{"amenity": "", "shop": null, "leisure": "park", "bad key": "x", "a=b": "c"}'),
        {'leisure': 'park'},
      );
    });

    test('converts numbers and booleans to strings', () {
      expect(parseAiTags('{"building:levels": 3, "wheelchair": true}'),
          {'building:levels': '3', 'wheelchair': 'true'});
    });

    test('returns an empty map when there is no JSON', () {
      expect(parseAiTags('I cannot recognize this photo'), isEmpty);
      expect(parseAiTags('{broken json'), isEmpty);
    });
  });
}
