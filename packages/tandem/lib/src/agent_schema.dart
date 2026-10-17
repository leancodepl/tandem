import 'dart:async';
import 'dart:convert';

import 'package:tandem/src/agent_list.dart';
import 'package:tandem/src/errors.dart';

/// A class with an agent list. The `_$ClassName` mixin that
/// `tandem_generator` writes implements it; the class itself only overrides
/// [agent].
// The experimental lint asks for a primary constructor on an interface too.
// ignore: use_primary_constructors
abstract interface class AgentSurface {
  /// What the agent may see and call now. Tandem reads it again before every
  /// turn, so it can depend on the state.
  List<AgentCapability> get agent;

  /// What the generator read from the source of [agent]: names, doc
  /// comments, parameter schemas, and a typed call of every method.
  AgentSchema get agentSchema;
}

/// What `tandem_generator` read from a class's agent list.
final class const AgentSchema({
  /// One item for every `.sees` of the list, in the same order.
  required final List<AgentView> sees,

  /// One item for every method the list mentions in `.calls` or
  /// `.callsWithApproval`, listed now or not.
  required final List<AgentTool> calls,
}) {
  /// Called by the generated code.
  this;
}

/// A getter the agent sees.
final class AgentView._(
  /// The getter's name in snake_case.
  final String name,

  /// The getter's doc comment.
  final String description,
  final Object? Function(Object? value) _write,
) {
  /// Called by the generated code with a closure that returns the getter,
  /// which only gives Dart the getter's type [T], so the generated code does
  /// not have to name it. The closure is never called: the values come from
  /// the agent list.
  static AgentView of<T>(
    T Function() _,
    String name,
    String description,
    Object? Function(T value) write,
  ) => ._(
    name,
    description,
    (value) => value is T
        ? write(value)
        : throw StateError(
            'The agent list sees a ${value.runtimeType} as $name, the '
            'generated code a $T. Run build_runner again.',
          ),
  );

  /// [value], read from the agent list, as JSON.
  ///
  /// Throws a [StateError] when its type is not the getter's, which means the
  /// code was not generated again after the list changed.
  Object? write(Object? value) => _write(value);
}

/// A method the agent may call.
final class const AgentTool(
  /// The method itself, to recognize it in the agent list: two tear-offs of
  /// one method of one object are equal.
  final Function method, {

  /// The method's name in snake_case.
  required final String name,

  /// The method's doc comment.
  required final String description,

  /// The JSON Schema of the arguments, built from the parameter types.
  required final Map<String, Object?> parameters,

  /// Calls [method] with the agent's JSON arguments and returns its result
  /// as JSON, `null` for `void`.
  required final FutureOr<Object?> Function(ToolArgs args) invoke,
}) {
  /// Called by the generated code.
  this;
}

/// The JSON arguments of one call, or of one object inside them, read as the
/// types the method takes. A value of the wrong type throws a
/// [ToolCallRefused] whose message is meant for the agent.
final class ToolArgs(
  /// The arguments as the agent sent them.
  final Map<String, Object?> json, {

  /// Where [json] is inside the call, as in `lines[0]`; empty for the call
  /// itself.
  final String path = '',
}) {
  /// The arguments in [json].
  this;

  /// The argument [name] as [T]: a `String`, `int`, `double`, `num`, `bool`
  /// or `DateTime`, one of [oneOf] for an enum, or a nullable one of these.
  T read<T>(String name, {List<T> oneOf = const []}) => switch (json[name]) {
    null => _missing(name),
    final value => _convert(_at(name), value, oneOf),
  };

  /// The object argument [name], built by [build] from its own arguments.
  T readObject<T>(String name, T Function(ToolArgs object) build) =>
      switch (json[name]) {
        null => _missing(name),
        final value => build(_object(_at(name), value)),
      };

  /// The list argument [name], with every item read as [read] does.
  List<T> readList<T>(String name, {List<T> oneOf = const []}) => [
    for (final (index, item) in _list(name).indexed)
      _convert('${_at(name)}[$index]', item, oneOf),
  ];

  /// The list argument [name], with every item built by [build].
  List<T> readObjects<T>(String name, T Function(ToolArgs object) build) => [
    for (final (index, item) in _list(name).indexed)
      build(_object('${_at(name)}[$index]', item)),
  ];

  String _at(String name) => path.isEmpty ? name : '$path.$name';

  T _missing<T>(String name) => null is T
      ? null as T
      : throw ToolCallRefused('${_at(name)}: missing, expected ${_type<T>()}');

  List<Object?> _list(String name) => switch (json[name]) {
    final List<Object?> list => list,
    null => throw ToolCallRefused('${_at(name)}: missing, expected a list'),
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
    // JSON does not tell 15 from 15.0, and models send either.
    return switch (value) {
      T() => value,
      double()
          when value == value.truncateToDouble() &&
              value.abs() <= _maxExactInteger &&
              0 is T =>
        value.toInt() as T,
      int() when 0.5 is T => value.toDouble() as T,
      String() when DateTime(0) is T => switch (_date(value)) {
        final date? => date as T,
        null => throw ToolCallRefused(
          '$path: expected an ISO 8601 date, got ${jsonEncode(value)}',
        ),
      },
      _ => throw ToolCallRefused(
        '$path: expected ${_type<T>()}, got ${jsonEncode(value)}',
      ),
    };
  }

  /// 2^53 - 1. Up to it a double holds every integer exactly. Beyond it a
  /// whole double may already differ from the number the agent wrote, and
  /// `toInt` clamps one that does not fit an `int`.
  static const _maxExactInteger = 9007199254740991;

  static final _isoDate = RegExp(
    r'^(\d{4})-(\d{2})-(\d{2})(?:[T ](\d{2}):(\d{2})(?::(\d{2}))?)?',
  );

  /// [text] as a date, or null when it is not ISO 8601 or names a day or
  /// time that does not exist, such as 2026-02-30, which `DateTime.parse`
  /// would roll over into March.
  static DateTime? _date(String text) {
    final match = _isoDate.firstMatch(text);
    final date = DateTime.tryParse(text);
    if (match == null || date == null) {
      return null;
    }
    final [year, month, day, hour, minute, second] = [
      for (var group = 1; group <= match.groupCount; group++)
        int.parse(match[group] ?? '0'),
    ];
    final real = DateTime.utc(year, month, day, hour, minute, second);
    return real.month == month &&
            real.day == day &&
            real.hour == hour &&
            real.minute == minute &&
            real.second == second
        ? date
        : null;
  }

  /// The name of [T] without `?`, as the agent should read it.
  static String _type<T>() => '$T'.replaceAll('?', '');
}
