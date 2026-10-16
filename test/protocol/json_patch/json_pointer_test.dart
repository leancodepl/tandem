// Tested at the level of this internal module on purpose, like JSON Patch
// (see json_patch_test.dart): the RFC 6901 cases need the exact tokens.

import 'package:flutter_test/flutter_test.dart';
import 'package:tandem/src/protocol/json_patch/json_pointer.dart';

void main() {
  group('parseJsonPointer', () {
    test('gives no tokens for the whole document', () {
      expect(parseJsonPointer(''), isEmpty);
    });

    test('splits a pointer into its tokens', () {
      expect(parseJsonPointer('/order/lines/0'), ['order', 'lines', '0']);
      expect(parseJsonPointer('/'), ['']);
      expect(parseJsonPointer('/a//b'), ['a', '', 'b']);
      expect(parseJsonPointer('/lines/-'), ['lines', '-']);
    });

    test('unescapes ~1 before ~0', () {
      expect(parseJsonPointer('/a~1b'), ['a/b']);
      expect(parseJsonPointer('/m~0n'), ['m~n']);
      expect(parseJsonPointer('/~01'), ['~1']);
      expect(parseJsonPointer('/~10'), ['/0']);
    });

    test('rejects a pointer that does not start with "/"', () {
      expect(() => parseJsonPointer('order'), throwsFormatException);
      expect(() => parseJsonPointer('#/order'), throwsFormatException);
    });

    test('rejects "~" that is not followed by 0 or 1', () {
      expect(() => parseJsonPointer('/a~2'), throwsFormatException);
      expect(() => parseJsonPointer('/a~'), throwsFormatException);
      expect(() => parseJsonPointer('/~/b'), throwsFormatException);
    });
  });

  group('formatJsonPointer', () {
    test('gives "" for no tokens', () {
      expect(formatJsonPointer(const []), '');
    });

    test('joins and escapes tokens', () {
      expect(formatJsonPointer(['order', 'lines', '0']), '/order/lines/0');
      expect(formatJsonPointer(['a/b', 'm~n', '']), '/a~1b/m~0n/');
      expect(formatJsonPointer(['~1']), '/~01');
    });

    test('round-trips with parseJsonPointer', () {
      for (final tokens in [
        <String>[],
        [''],
        ['a/b', '~', '~1', '/~0', 'plain'],
      ]) {
        expect(parseJsonPointer(formatJsonPointer(tokens)), tokens);
      }
    });
  });
}
