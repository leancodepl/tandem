import 'package:meta/meta.dart';
import 'package:tandem/src/protocol/ag_ui.dart';

/// The arguments of one call, read as the types of the method's parameters.
/// The generated code passes them on with [read].
final class ToolArgs._(
  final Map<String, Object?> _values, {

  /// The arguments as JSON, as the agent's method gets them.
  required final JsonObject json,
}) {
  @internal
  factory of(Map<String, Object?> values, {required JsonObject json}) =>
      ._(values, json: json);

  /// The argument [name] as its parameter's type [T].
  T read<T>(String name) => _values[name] as T;

  /// The argument [name], or [fallback], the parameter's default, when the
  /// call has none.
  T readOr<T>(String name, T fallback) =>
      _values.containsKey(name) ? _values[name] as T : fallback;
}
