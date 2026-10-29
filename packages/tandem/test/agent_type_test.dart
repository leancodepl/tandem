import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:tandem/tandem.dart';

void main() {
  test('a generic class is named with the names of its type arguments', () {
    final AgentType<Object?> page = .object(
      id: 'package:app/page.dart#Pair<dart:core#String,package:app/c.dart#C?>',
      fields: (field) => const [],
      build: (values) => null,
    );

    expect(page.name, 'Pair<String, C?>');
    expect(AgentType.list(page).name, 'Pair<String, C?>[]');
  });

  test('an int refuses a whole double past 2^53 - 1, not an exact int', () {
    T read<T>(AgentType<T> type, String json) =>
        type.read(jsonDecode(json), const AgentReading('n', objects: .fields));

    expect(read(.integer, '9007199254740991.0'), 9007199254740991);
    expect('${read(.integer, '9007199254740993')}', '9007199254740993');
    expect(read(.number, '1e30'), 1e30);
    expect(read(.nullable(AgentType.numeric), '1e30'), 1e30);
    for (final type in <AgentType<int?>>[.integer, .nullable(.integer)]) {
      expect(
        () => read(type, '9007199254740993.0'),
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
