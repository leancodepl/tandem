import 'dart:convert';

import 'package:tandem/src/agent_schema.dart';
import 'package:tandem/src/errors.dart';

/// One item of a surface's `agentCapabilities`: a value the agent sees, or a
/// method it may call.
sealed class const AgentCapability() {
  /// For the two kinds of items below.
  this;

  /// The agent sees [value] on every turn. Pass a getter of the surface, as
  /// in `.sees(draft)`: its name and doc comment tell the agent what it is.
  factory sees(Object? value) => _Sees(value);

  /// The agent may call [method], a method of the surface, as in
  /// `.calls(setQuantity)`. Its name, doc comment and parameters tell the
  /// agent what it does and what to send.
  factory calls(Function method) => _Calls(method, needsApproval: false);

  /// Like [AgentCapability.calls], but each call runs only after the user
  /// approves it.
  factory callsWithApproval(Function method) =>
      _Calls(method, needsApproval: true);
}

final class const _Sees(final Object? value) extends AgentCapability;

final class const _Calls(
  final Function method, {
  required final bool needsApproval,
}) extends AgentCapability;

/// A class's agent list read once, for one run of the agent, in the shape
/// AG-UI sends it. A new run reads the list again.
final class AgentListing._(
  final AgentSurface _surface,

  /// The `context` of AG-UI's `RunAgentInput`: one entry for every `.sees`.
  final List<Map<String, Object?>> context,
  final Map<String, AgentTool> _tools,
) {
  /// Reads [surface]'s [AgentSurface.agentCapabilities] and names its items
  /// with the generated [AgentSurface.agentSchema].
  ///
  /// Throws a [StateError] when the list and the generated code disagree,
  /// which means the code was not generated again after the list changed.
  factory of(AgentSurface surface) {
    final schema = surface.agentSchema;
    final capabilities = surface.agentCapabilities;
    final visibleValues = [
      for (final item in capabilities)
        if (item case _Sees(:final value)) value,
    ];
    if (visibleValues.length != schema.sees.length) {
      throw StateError(
        'The agent list has ${visibleValues.length} .sees, the generated code '
        '${schema.sees.length}. Run build_runner again.',
      );
    }
    final tools = <String, AgentTool>{};
    for (final item in capabilities) {
      if (item case _Calls(:final method)) {
        final tool = schema.calls.firstWhere(
          (tool) => tool.method == method,
          orElse: () => throw StateError(
            'The generated code does not know a method of the agent list. '
            'Run build_runner again.',
          ),
        );
        if (tools.containsKey(tool.name)) {
          throw StateError('The agent list has ${tool.name} twice.');
        }
        tools[tool.name] = tool;
      }
    }
    return ._(surface, [
      for (final (index, view) in schema.sees.indexed)
        {
          'description': '${view.name}: ${view.description}',
          'value': jsonEncode(view.write(visibleValues[index])),
        },
    ], tools);
  }

  /// The `tools` of AG-UI's `RunAgentInput`: the methods listed when this
  /// listing was read.
  List<Map<String, Object?>> get tools => [
    for (final tool in _tools.values)
      {
        'name': tool.name,
        'description': tool.description,
        'parameters': tool.parameters,
      },
  ];

  /// Whether [tool] was listed when this listing was read.
  bool lists(String tool) => _tools.containsKey(tool);

  /// The doc comment of [tool], empty for a tool this listing does not list.
  String description(String tool) => _tools[tool]?.description ?? '';

  /// Whether a call of [tool] waits for the user's approval, by the agent
  /// list as it is now.
  bool needsApproval(String tool) =>
      _currentCapabilityFor(tool)?.needsApproval ?? false;

  /// Calls the method behind [tool] with the agent's JSON [arguments] and
  /// returns its result as JSON.
  ///
  /// The agent list is read again first, because an earlier call of the same
  /// run may have changed it. Throws a [ToolCallRefused] for a tool that is
  /// not listed now, that needs approval when [approved] is false, and for
  /// arguments of the wrong type or with a key the schema does not have. The
  /// method runs in none of these cases.
  Future<Object?> call(
    String tool,
    Map<String, Object?> arguments, {
    bool approved = false,
  }) async {
    final target = _tools[tool];
    final capability = _currentCapabilityFor(tool);
    if (target == null || capability == null) {
      throw ToolCallRefused('The agent cannot call $tool now.');
    }
    if (capability.needsApproval && !approved) {
      throw ToolCallRefused('$tool runs only after the user approves it.');
    }
    _rejectUnknown(arguments, target.parameters, '');
    return await target.invoke(ToolArgs(arguments));
  }

  /// The item of the agent list as it is now that lists [tool], or null.
  _Calls? _currentCapabilityFor(String tool) {
    final method = _tools[tool]?.method;
    for (final item in _surface.agentCapabilities) {
      if (item case final _Calls capability when capability.method == method) {
        return capability;
      }
    }
    return null;
  }

  /// Throws a [ToolCallRefused] for a key in [json], at any depth, that its
  /// JSON Schema [schema] does not have.
  static void _rejectUnknown(Object? json, Object? schema, String path) {
    switch ((json, schema)) {
      case (
        final Map<String, Object?> object,
        {'properties': final Map<Object?, Object?> properties},
      ):
        for (final MapEntry(:key, :value) in object.entries) {
          final at = path.isEmpty ? key : '$path.$key';
          if (!properties.containsKey(key)) {
            throw ToolCallRefused(
              '$at: unknown, expected one of ${properties.keys.join(', ')}',
            );
          }
          _rejectUnknown(value, properties[key], at);
        }
      case (final List<Object?> list, {'items': final items}):
        for (final (index, item) in list.indexed) {
          _rejectUnknown(item, items, '$path[$index]');
        }
      case _:
    }
  }
}
