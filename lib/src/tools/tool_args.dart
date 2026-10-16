import 'package:tandem/src/tools/tool.dart';

/// Typed reads of a tool call's JSON arguments.
///
/// The type is inferred from where the value goes, so
/// `catalog.search(call.read('query'))` reads a `String`. A value of the
/// wrong type throws a [ToolArgumentError]; inside [Tool.run] that error
/// goes back to the agent, which usually corrects the call.
base class ToolArgs {
  /// Wraps the arguments [json].
  const ToolArgs(this.json) : _path = '';

  const ToolArgs._nested(this.json, this._path);

  /// The arguments exactly as the agent sent them; `{}` when it sent none.
  final Map<String, Object?> json;

  /// Where these arguments sit inside the call's arguments, such as
  /// `lines[1].`; empty at the top level. Used in error messages.
  final String _path;

  /// The argument [name] as [T].
  ///
  /// [T] is one of `String`, `int` (which accepts integral numbers such as
  /// `40.0`), `double` (which accepts `15`), `num`, `bool`, `List<Object?>`
  /// and `Map<String, Object?>`, or a nullable version of one of them.
  /// Throws a [ToolArgumentError] when the argument is missing, `null` for a
  /// non-nullable [T], or of another type.
  T read<T>(String name) {
    final value = json[name];
    if (value == null) {
      if (null is T) {
        return null as T;
      }
      throw ToolArgumentError(
        '$_path$name',
        json.containsKey(name) ? 'must not be null' : 'is missing',
      );
    }
    return _convert<T>('$_path$name', value);
  }

  /// Like [read], but `null` when the argument is missing or `null`.
  T? readOrNull<T>(String name) {
    final value = json[name];
    return value == null ? null : _convert<T>('$_path$name', value);
  }

  /// The list argument [name], with every item read as [T] like [read] does.
  List<T> readList<T>(String name) {
    final list = read<List<Object?>>(name);
    return [
      for (final (index, item) in list.indexed)
        _convert<T>('$_path$name[$index]', item),
    ];
  }

  /// The object argument [name], for reading its fields.
  ToolArgs object(String name) =>
      ToolArgs._nested(read<Map<String, Object?>>(name), '$_path$name.');

  /// The list-of-objects argument [name], for reading the fields of each.
  List<ToolArgs> objects(String name) => [
    for (final (index, item) in readList<Map<String, Object?>>(name).indexed)
      ToolArgs._nested(item, '$_path$name[$index].'),
  ];

  static T _convert<T>(String argument, Object? value) {
    if (value is T) {
      return value;
    }
    // JSON does not tell 40 from 40.0, and models write either.
    if (value is double && value == value.truncateToDouble() && 0 is T) {
      return value.toInt() as T;
    }
    if (value is int && 0.5 is T) {
      return value.toDouble() as T;
    }
    throw ToolArgumentError(
      argument,
      'must be ${_describe<T>()}, not ${_describeValue(value)}',
    );
  }

  static String _describe<T>() {
    if ('' is T) {
      return 'a string';
    }
    if (0 is T && 0.5 is! T) {
      return 'a whole number';
    }
    if (0.5 is T) {
      return 'a number';
    }
    if (true is T) {
      return 'true or false';
    }
    if (const <Never>[] is T) {
      return 'a list';
    }
    if (const <Never, Never>{} is T) {
      return 'an object';
    }
    return 'of another type';
  }

  static String _describeValue(Object? value) => switch (value) {
    null => 'null',
    String() => 'a string',
    int() => 'a whole number',
    double() => 'a number',
    bool() => 'a boolean',
    List<Object?>() => 'a list',
    Map<Object?, Object?>() => 'an object',
    _ => 'another value',
  };
}

/// One call of a [Tool], passed to [Tool.run].
final class ToolCall<S> extends ToolArgs {
  /// Creates a call. The session creates them; public so a tool can be
  /// unit-tested on its own.
  const ToolCall({
    required this.id,
    required this.toolName,
    required this.state,
    Map<String, Object?> args = const {},
  }) : super(args);

  /// The tool call id, chosen by the agent.
  final String id;

  /// The name of the tool called.
  final String toolName;

  /// The shared state when [Tool.run] starts. For a tool with
  /// [Tool.needsApproval] it is the state the user approved, because an
  /// approval is only possible while the state is unchanged since the
  /// proposal.
  final S state;
}

/// An argument did not match what the tool expects. Thrown by the reads of
/// [ToolArgs] and sent back to the agent, which usually corrects the call.
final class ToolArgumentError extends Error {
  /// Creates the error.
  ToolArgumentError(this.argument, this.message);

  /// The argument, such as `quantity` or `lines[1].sku`.
  final String argument;

  /// What is wrong, in words the model understands, such as
  /// `must be a whole number, not a string`.
  final String message;

  @override
  String toString() => 'Invalid argument "$argument": $message';
}
