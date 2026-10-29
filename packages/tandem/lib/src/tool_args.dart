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

  /// Whether the call has the argument [name], so a parameter's default
  /// stays otherwise.
  bool has(String name) => _values.containsKey(name);
}
