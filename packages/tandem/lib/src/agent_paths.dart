import 'dart:convert';

import 'package:tandem/src/agent_list.dart';
import 'package:tandem/src/agent_type.dart';
import 'package:tandem/src/errors.dart';

/// What a `{"path": ...}` of the agent points at: a value of the listing it
/// [seen], checked against the listing [now] before the method runs.
final class ListingPaths({
  required final AgentListing seen,
  required final AgentListing now,
}) implements AgentPaths {
  @override
  T resolve<T>(String path, AgentType<T> type, {required String at}) {
    ToolCallRefused refuse(String problem) => ToolCallRefused('$at: $problem');
    final segments = DataPath.segments(path);
    if (segments == null || segments.isEmpty) {
      throw refuse('write a path that starts with /, such as /name/0');
    }
    final then = DataPath.locate(seen.roots, segments);
    final current = DataPath.locate(now.roots, segments);
    switch (then) {
      case null:
        final roots = seen.roots.keys.map((name) => '/$name').join(', ');
        throw refuse('$path is not in the data. Paths: $roots.');
      case PathValue(type: final found) when !type.accepts(found):
        final types = {
          for (final MapEntry(:key, :value) in seen.roots.entries)
            key: value.type,
        };
        final fitting = DataPath.pathsOf(types, type).join(', ');
        throw refuse(
          '$path is a ${found.nameBeside(type)}, not a '
          '${type.nameBeside(found)}. '
          '${fitting.isEmpty ? 'The data has none.' : 'Paths of that type: $fitting.'}',
        );
      case PathValue(:final json) when json == AgentType.absent:
        throw refuse('$path has no value.');
      case PathValue(:final json) when !DataPath.sameJson(json, current?.json):
        throw refuse(
          '$path changed since the agent read it. Read ${segments.first} '
          'again.',
        );
    }
    return switch (current?.value) {
      final T value => value,
      _ => throw refuse('$path has no value.'),
    };
  }
}

/// The value at a path of the data, with its type and its JSON.
final class const PathValue(
  final AgentType<Object?> type,
  final Object? value,
  final Object? json,
);

/// The paths of the data a view and the agent read: `/order/lines/0/sku`.
abstract final class DataPath._() {
  /// The segments of an absolute [path], or null for another path.
  static List<String>? segments(String path) {
    if (!path.startsWith('/')) return null;
    return relative(path.substring(1));
  }

  /// The segments of a [path] without a leading `/`, from where it starts.
  static List<String> relative(String path) => [
    for (final segment in path.split('/'))
      if (segment.isNotEmpty) segment,
  ];

  /// The segments of [path] from the root: an absolute path, or one that
  /// starts at [base].
  static List<String> resolve(String path, {required List<String> base}) =>
      segments(path) ?? [...base, ...relative(path)];

  /// The type, the JSON and the value at [segments] below [roots], or null
  /// when the type has no such place. The JSON and the value are
  /// [AgentType.absent] when the place is empty now, such as past the end of
  /// a list.
  static PathValue? locate(
    Map<String, PathValue> roots,
    List<String> segments,
  ) {
    final root = roots[segments.first];
    if (root == null) return null;
    var PathValue(:type, :value, :json) = root;
    for (final segment in segments.skip(1)) {
      final next = type.typeAt(segment);
      if (next == null) return null;
      value = value == AgentType.absent
          ? AgentType.absent
          : type.valueAt(value, segment);
      json = _jsonAt(json, segment);
      type = next;
    }
    return PathValue(type, value, json);
  }

  /// The JSON at the absolute [path] below [roots], or [AgentType.absent]
  /// when the data has no such place or no value there now. A null there is
  /// a value.
  static Object? jsonAt(Map<String, PathValue> roots, String path) {
    if (segments(path) case [_, ...] && final names) {
      if (locate(roots, names) case PathValue(:final json)) return json;
    }
    return AgentType.absent;
  }

  /// Whether [a] and [b], JSON at a path or [AgentType.absent], are the
  /// same value.
  static bool sameJson(Object? a, Object? b) {
    if (a == AgentType.absent || b == AgentType.absent) return a == b;
    return jsonEncode(a) == jsonEncode(b);
  }

  /// The paths below [roots] whose type [type] accepts, an item of a list as
  /// `<i>`.
  static List<String> pathsOf(
    Map<String, AgentType<Object?>> roots,
    AgentType<Object?> type,
  ) {
    final paths = <String>[];
    void visit(AgentType<Object?> at, String path, int depth) {
      if (type.accepts(at)) paths.add(path);
      if (depth == 0) return;
      if (at.itemType case final item?) {
        visit(item, '$path/<i>', depth - 1);
      }
      for (final field in at.fieldNames) {
        if (at.typeAt(field) case final fieldType?) {
          visit(fieldType, '$path/$field', depth - 1);
        }
      }
    }

    for (final MapEntry(key: name, value: root) in roots.entries) {
      visit(root, '/$name', 4);
    }
    return paths;
  }

  static Object? _jsonAt(Object? json, String segment) => switch (json) {
    final Map<String, Object?> object when object.containsKey(segment) =>
      object[segment],
    final List<Object?> list => switch (int.tryParse(segment)) {
      final index? when index >= 0 && index < list.length => list[index],
      _ => AgentType.absent,
    },
    _ => AgentType.absent,
  };
}
