import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:json_annotation/json_annotation.dart';
import 'package:tandem/src/agent_paths.dart';
import 'package:tandem/src/agent_type.dart';
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

  test('a list or a set of nullable items takes its own type and non-null '
      'items, and one of non-null items takes no nullable ones', () {
    final AgentType<String?> nullable = .nullable(.string);
    for (final (AgentType<Object?> type, AgentType<Object?> value, accepts) in [
      (.list(nullable), .list(nullable), true),
      (.list(nullable), .nullable(.list(AgentType.string)), true),
      (.list(.string), .list(nullable), false),
      (.list(.list(nullable)), .list(.list(AgentType.string)), true),
      (.set(nullable), .set(nullable), true),
      (.set(nullable), .set(AgentType.string), true),
      (.set(.string), .set(nullable), false),
    ]) {
      expect(type.accepts(value), accepts, reason: '${type.id} ${value.id}');
    }
  });

  test('a value passed by path passes every object in it by its own path', () {
    final AgentType<_Node> node = .object(
      id: 'test#Node',
      fields: (field) => [field('name', (node) => node.name).as(.string)],
      build: (values) => _Node(values('name')),
    );
    final a = _Node('a');
    final b = _Node('b');
    Object? passed<T>(AgentType<T> type, T value) {
      final json = jsonDecode(jsonEncode(type.write(value)));
      return type.read(
        type.pathArgument('/m', json),
        AgentReading('m', objects: .paths, paths: _Data(type, value)),
      );
    }

    expect(passed(node, a), a);
    expect(passed<_Node?>(.nullable(node), null), isNull);
    expect(passed<_Node?>(.nullable(node), b), b);
    expect(passed(.list(node), [a, b]), [a, b]);
    expect(passed(.set(node), {b, a}), {b, a});
    expect(
      passed<List<List<_Node?>>>(.list(.list(.nullable(node))), [
        [a, null],
        [b],
      ]),
      [
        [a, null],
        [b],
      ],
    );
    expect(passed(.list(AgentType.string), ['a']), ['a']);
    final AgentType<_Node> converted = .converted(
      const _NodeConverter(),
      AgentType.string,
      id: 'test#Grower',
      converterId: 'test#NodeConverter()',
      object: true,
    );
    expect(passed(.list(converted), [a, b]), [a, b]);
  });
}

final class _Node(final String name);

final class const _NodeConverter() implements JsonConverter<_Node, String> {
  @override
  _Node fromJson(String json) => _Node(json);

  @override
  String toJson(_Node object) => object.name;
}

/// Resolves a path below `/m`, which holds [value] of [type].
final class _Data(final AgentType<Object?> type, final Object? value)
    implements AgentPaths {
  @override
  T resolve<T>(String path, AgentType<T> type, {required String at}) {
    final root = PathValue(this.type, value, null);
    final segments = DataPath.segments(path) ?? const [];
    return DataPath.locate({'m': root}, segments)?.value as T;
  }
}
