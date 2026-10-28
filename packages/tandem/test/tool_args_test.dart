import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:tandem/tandem.dart';

void main() {
  test('an int refuses a whole double past 2^53 - 1, not an exact int', () {
    T read<T>(String json) => ToolArgs({'n': jsonDecode(json)}).read<T>('n');

    expect(read<int>('9007199254740991.0'), 9007199254740991);
    expect('${read<int>('9007199254740993')}', '9007199254740993');
    expect(read<double>('1e30'), 1e30);
    expect(read<num?>('1e30'), 1e30);
    for (final readInt in [read<int>, read<int?>]) {
      expect(
        () => readInt('9007199254740993.0'),
        throwsA(
          isA<ToolCallRefused>().having(
            (error) => error.message,
            'message',
            'n: expected int, got 9007199254740992.0',
          ),
        ),
      );
    }
  });
}
