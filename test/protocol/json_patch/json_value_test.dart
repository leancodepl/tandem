// Tested at the level of this internal module on purpose, like JSON Patch
// (see json_patch_test.dart): echo detection and per-leaf merges rest on
// these exact semantics.

import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:tandem/src/protocol/json_patch/json_value.dart';

void main() {
  group('jsonEquals', () {
    test('compares scalars by value', () {
      expect(jsonEquals(null, null), isTrue);
      expect(jsonEquals('a', 'a'), isTrue);
      expect(jsonEquals(true, true), isTrue);
      expect(jsonEquals(40, 40.0), isTrue);
      expect(jsonEquals(15.0, 15), isTrue);
      expect(jsonEquals(1, '1'), isFalse);
      expect(jsonEquals(0, false), isFalse);
      expect(jsonEquals(null, false), isFalse);
      expect(jsonEquals(1.5, 1), isFalse);
    });

    test('compares objects regardless of member order', () {
      expect(jsonEquals({'a': 1, 'b': 2}, {'b': 2, 'a': 1}), isTrue);
      expect(jsonEquals({'a': 1}, {'a': 1, 'b': 2}), isFalse);
      expect(jsonEquals({'a': null}, {'b': null}), isFalse);
      expect(jsonEquals({'a': null}, <String, Object?>{}), isFalse);
    });

    test('compares lists in order', () {
      expect(jsonEquals([1, 2], [1, 2.0]), isTrue);
      expect(jsonEquals([1, 2], [2, 1]), isFalse);
      expect(jsonEquals([1], [1, 1]), isFalse);
    });

    test('compares nested values deeply', () {
      final decoded = jsonDecode('{"order":{"lines":[{"qty":40}],"x":null}}');

      expect(
        jsonEquals(decoded, {
          'order': {
            'x': null,
            'lines': [
              {'qty': 40.0},
            ],
          },
        }),
        isTrue,
      );
      expect(
        jsonEquals(decoded, {
          'order': {
            'x': null,
            'lines': [
              {'qty': 41},
            ],
          },
        }),
        isFalse,
      );
    });

    test('never treats an object, a list and a scalar as equal', () {
      expect(jsonEquals(<String, Object?>{}, <Object?>[]), isFalse);
      expect(jsonEquals(<Object?>[], null), isFalse);
      expect(jsonEquals('[]', <Object?>[]), isFalse);
      expect(jsonEquals(<String, Object?>{}, '{}'), isFalse);
    });
  });

  group('copyJson', () {
    test('copies deeply', () {
      final original = <String, Object?>{
        'lines': [
          {'sku': 'A'},
        ],
      };

      final copy = copyJson(original)! as Map<String, Object?>;
      final lines = copy['lines']! as List<Object?>;
      (lines.single! as Map<String, Object?>)['sku'] = 'B';
      lines.add('more');

      expect(original, {
        'lines': [
          {'sku': 'A'},
        ],
      });
      expect(copy, {
        'lines': [
          {'sku': 'B'},
          'more',
        ],
      });
    });

    test('makes constant and typed collections modifiable', () {
      const original = {
        'lines': [1, 2],
        'meta': {'tag': 'x'},
      };

      final copy = copyJsonObject(original);
      (copy['lines']! as List<Object?>).add('three');
      (copy['meta']! as Map<String, Object?>)['count'] = 2;
      copy['new'] = true;

      expect(copy, {
        'lines': [1, 2, 'three'],
        'meta': {'tag': 'x', 'count': 2},
        'new': true,
      });
    });

    test('returns scalars as they are', () {
      expect(copyJson(null), isNull);
      expect(copyJson(1.5), 1.5);
      expect(copyJson('a'), 'a');
      expect(copyJson(false), isFalse);
    });
  });
}
