import 'dart:convert';

import 'package:tandem/src/errors.dart';

/// The JSON arguments of one call, or of one object inside them, read as the
/// types the method takes. A value of the wrong type throws a
/// [ToolCallRefused] whose message is meant for the agent.
final class ToolArgs(
  final Map<String, Object?> json, {

  /// Where [json] is inside the call, as in `lines[0]`; empty for the call
  /// itself.
  final String path = '',
}) {
  /// The argument [name] as [T]: a `String`, `int`, `double`, `num`, `bool`
  /// or `DateTime`, one of [oneOf] for an enum, or a nullable one of these.
  T read<T>(String name, {List<T> oneOf = const []}) => switch (json[name]) {
    null => _nullOrRefuse(name),
    final value => _convert(_at(name), value, oneOf),
  };

  T readObject<T>(String name, T Function(ToolArgs object) build) =>
      switch (json[name]) {
        null => _nullOrRefuse(name),
        final value => build(_object(_at(name), value)),
      };

  List<T> readList<T>(String name, {List<T> oneOf = const []}) => [
    for (final (index, item) in _list(name).indexed)
      _convert('${_at(name)}[$index]', item, oneOf),
  ];

  List<T> readObjects<T>(String name, T Function(ToolArgs object) build) => [
    for (final (index, item) in _list(name).indexed)
      build(_object('${_at(name)}[$index]', item)),
  ];

  String _at(String name) => path.isEmpty ? name : '$path.$name';

  T _nullOrRefuse<T>(String name) =>
      null is T ? null as T : throw _absent(name, _type<T>());

  ToolCallRefused _absent(String name, String expected) => ToolCallRefused(
    json.containsKey(name)
        ? '${_at(name)}: expected $expected, got null'
        : '${_at(name)}: missing, expected $expected',
  );

  List<Object?> _list(String name) => switch (json[name]) {
    final List<Object?> list => list,
    null => throw _absent(name, 'a list'),
    final value => throw ToolCallRefused(
      '${_at(name)}: expected a list, got ${jsonEncode(value)}',
    ),
  };

  static ToolArgs _object(String path, Object? value) => switch (value) {
    final Map<String, Object?> json => ToolArgs(json, path: path),
    _ => throw ToolCallRefused(
      '$path: expected an object, got ${jsonEncode(value)}',
    ),
  };

  static T _convert<T>(String path, Object? value, List<T> oneOf) {
    if (oneOf.isNotEmpty) {
      for (final option in oneOf) {
        if (option case Enum(:final name) when name == value) {
          return option;
        }
      }
      final names = [for (final option in oneOf) (option as Enum).name];
      throw ToolCallRefused(
        '$path: expected one of ${names.join(', ')}, got ${jsonEncode(value)}',
      );
    }
    ToolCallRefused wrongType() => ToolCallRefused(
      '$path: expected ${_type<T>()}, got ${jsonEncode(value)}',
    );

    // JSON does not tell 15 from 15.0. Past 2^53 - 1 a whole double may not be
    // the number the agent wrote, and on the web `T()` would take it as an int.
    return switch (value) {
      double() when 0 is T && 0.5 is! T && value.abs() > _maxExactInteger =>
        throw wrongType(),
      T() => value,
      double() when value == value.truncateToDouble() && 0 is T =>
        value.toInt() as T,
      int() when 0.5 is T => value.toDouble() as T,
      String() when DateTime(0) is T => switch (DateTime.tryParse(value)) {
        final date? => date as T,
        null => throw ToolCallRefused(
          '$path: expected an ISO 8601 date, got ${jsonEncode(value)}',
        ),
      },
      _ => throw wrongType(),
    };
  }

  static const _maxExactInteger = 9007199254740991;

  static String _type<T>() => '$T'.replaceAll('?', '');
}
