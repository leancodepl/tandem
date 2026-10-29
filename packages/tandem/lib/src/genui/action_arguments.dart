import 'package:tandem/src/agent_list.dart';
import 'package:tandem/src/agent_paths.dart';
import 'package:tandem/src/agent_schema.dart';
import 'package:tandem/src/agent_type.dart';
import 'package:tandem/src/genui/view_check.dart';
import 'package:tandem/src/protocol/ag_ui.dart';

/// What the user entered in a field of a view, a value of the field's
/// [type].
final class const FieldEntry(
  final AgentType<Object?> type,
  final Object? value,
);

/// The [_arguments] of an action of a view that calls [_tool], each path
/// absolute and pointing at a value of [_seen], the data the view was drawn
/// with.
final class ActionArguments(
  final Map<String, ViewArgument> _arguments,
  final AgentTool _tool,
  final AgentListing _seen,
) {
  /// The arguments as the method's call takes them: a value of the data as
  /// it was drawn, with a path to each object in it, and the [entry] of a
  /// field. Null when a value is not the same in [now], or is gone.
  JsonObject? resolve({required AgentListing now, FieldEntry? entry}) {
    final resolved = <String, Object?>{};
    for (final MapEntry(key: name, value: argument) in _arguments.entries) {
      final json = switch (argument) {
        ValueArgument(:final json) => json,
        InputArgument() => _entered(entry),
        PathArgument(:final path) => _bound(name, path, now),
      };
      if (json == AgentType.absent) return null;
      resolved[name] = json;
    }
    return resolved;
  }

  /// The JSON of [entry], or [AgentType.absent] in a press, which the check
  /// refuses.
  static Object? _entered(FieldEntry? entry) => switch (entry) {
    FieldEntry(:final type, :final value) => type.write(value),
    null => AgentType.absent,
  };

  /// The value at [path] for the parameter [name], or [AgentType.absent]
  /// when it is gone or another in [now], or the method has no such
  /// parameter, which the check refuses.
  Object? _bound(String name, String path, AgentListing now) {
    final parameter = _tool.parameters.where((p) => p.name == name).firstOrNull;
    final drawn = DataPath.jsonAt(_seen.roots, path);
    final current = DataPath.jsonAt(now.roots, path);
    if (parameter == null ||
        drawn == AgentType.absent ||
        !DataPath.sameJson(drawn, current)) {
      return AgentType.absent;
    }
    return parameter.input ? drawn : parameter.type.pathArgument(path, drawn);
  }
}
