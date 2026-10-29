import 'dart:convert';

import 'package:tandem/src/agent_schema.dart';
import 'package:tandem/src/errors.dart';
import 'package:tandem/src/protocol/ag_ui.dart';

/// One item of the agent list: a value the agent sees or a method it may
/// call. Write it as `.sees`, `.calls` or `.callsWithApproval`.
sealed class const AgentCapability() {
  /// The agent sees [value] on every turn. Pass a getter of the surface, as
  /// in `.sees(draft)`: its name and doc comment tell the agent what it is.
  factory sees(Object? value) => _Sees(value);

  /// [value] of the getter that the agent knows as [name]. The generated
  /// code writes it for each `.sees`, so that Tandem tells two values apart
  /// by their getters.
  factory seesAs(String name, Object? value) => _Sees(value, name: name);

  /// The agent may call [method], a method of the surface, as in
  /// `.calls(setQuantity)`. Its name, doc comment and parameters tell the
  /// agent what it does and what to send.
  factory calls(Function method) => _Calls(method, needsApproval: false);

  /// Like [AgentCapability.calls], but each call runs only after the user
  /// approves it. The approval covers the values listed with `.sees` as they
  /// were when the agent asked, and a change to one invalidates the request.
  /// So list everything [method] depends on with `.sees`.
  factory callsWithApproval(Function method) =>
      _Calls(method, needsApproval: true);
}

final class const _Sees(final Object? value, {final String? name})
    extends AgentCapability;

final class const _Calls(
  final Function method, {
  required final bool needsApproval,
}) extends AgentCapability;

/// A class's agent list read once, for one run of the agent, in the shape
/// AG-UI sends it. A new run reads the list again.
final class AgentListing._(
  final AgentSurface _surface,
  final List<_Seen> _seen,
  final Map<String, AgentTool> _tools,
) {
  /// Reads [surface]'s [AgentSurface.agentCapabilities] and names its items
  /// with the generated [AgentSurface.agentSchema].
  ///
  /// Throws a [StateError] when the list and the generated code disagree,
  /// which means the code was not generated again after the list changed.
  factory of(AgentSurface surface) {
    final schema = surface.agentSchema;
    final capabilities = _read(surface, schema);
    final seen = _pairViews(capabilities, schema);
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
    return ._(surface, seen, tools);
  }

  /// The agent list through the generated copy that names each `.sees`, or
  /// the list itself for a schema written by hand.
  static List<AgentCapability> _read(AgentSurface surface, AgentSchema schema) {
    final capabilities = schema.capabilities;
    if (capabilities == null) {
      return surface.agentCapabilities;
    }
    final named = capabilities();
    assert(
      _sameShape(named, surface.agentCapabilities),
      'The agent list and its generated copy differ. Run build_runner again.',
    );
    return named;
  }

  // The values can differ: a getter may build a new object on every read.
  static bool _sameShape(
    List<AgentCapability> copy,
    List<AgentCapability> list,
  ) =>
      copy.length == list.length &&
      [
        for (final (index, item) in copy.indexed)
          switch ((item, list[index])) {
            (_Sees(), _Sees()) => true,
            (_Calls(:final method, :final needsApproval), final _Calls other) =>
              method == other.method && needsApproval == other.needsApproval,
            _ => false,
          },
      ].every((same) => same);

  /// Each `.sees` with its view: by its getter's name when the generated code
  /// names it, else by place.
  static List<_Seen> _pairViews(
    List<AgentCapability> capabilities,
    AgentSchema schema,
  ) {
    final sees = [
      for (final item in capabilities)
        if (item case final _Sees sees) sees,
    ];
    final byName = {for (final view in schema.sees) view.name: view};
    if (schema.capabilities == null && sees.length != schema.sees.length) {
      throw StateError(
        'The agent list has ${sees.length} .sees, the generated code '
        '${schema.sees.length}. Run build_runner again.',
      );
    }
    final seen = <_Seen>[];
    for (final (index, _Sees(:value, :name)) in sees.indexed) {
      final view = switch (name) {
        final name? =>
          byName[name] ??
              (throw StateError(
                'The generated code does not know the .sees $name. Run '
                'build_runner again.',
              )),
        null => schema.sees[index],
      };
      if (seen.any((item) => item.view.name == view.name)) {
        throw StateError('The agent list sees ${view.name} twice.');
      }
      seen.add((view: view, value: value, json: jsonEncode(view.write(value))));
    }
    return seen;
  }

  /// The `context` of AG-UI's `RunAgentInput`: one entry for every `.sees`.
  List<Map<String, Object?>> get context => [
    for (final (:view, value: _, :json) in _seen)
      {
        AgUiFields.description: '${view.name}: ${view.description}',
        AgUiFields.value: json,
      },
  ];

  /// The value of every `.sees` by its name, as JSON.
  late final Map<String, Object?> seen = {
    for (final (:view, value: _, :json) in _seen) view.name: jsonDecode(json),
  };

  /// The `tools` of AG-UI's `RunAgentInput`: the methods listed when this
  /// listing was read.
  List<Map<String, Object?>> get tools => [
    for (final tool in _tools.values)
      {
        AgUiFields.name: tool.name,
        AgUiFields.description: tool.description,
        AgUiFields.parameters: tool.schema,
      },
  ];

  bool lists(String tool) => _tools.containsKey(tool);

  /// The names of the tools this listing lists.
  Iterable<String> get toolNames => _tools.keys;

  /// The JSON Schema of the arguments of [tool], or null for a tool this
  /// listing does not list.
  Map<String, Object?>? parameters(String tool) => _tools[tool]?.schema;

  /// The doc comment of [tool], as the agent got it. Throws a [StateError] for
  /// a tool this listing does not list.
  String description(String tool) => switch (_tools[tool]) {
    final listed? => listed.description,
    null => throw StateError('This listing does not list $tool.'),
  };

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
    final (target, capability) = switch ((
      _tools[tool],
      _currentCapabilityFor(tool),
    )) {
      (final target?, final capability?) => (target, capability),
      _ => throw ToolCallRefused('The agent cannot call $tool now.'),
    };
    if (capability.needsApproval && !approved) {
      throw ToolCallRefused('$tool runs only after the user approves it.');
    }
    return await target.invoke(target.read(arguments));
  }

  _Calls? _currentCapabilityFor(String tool) {
    final method = _tools[tool]?.method;
    for (final item in _read(_surface, _surface.agentSchema)) {
      if (item case final _Calls capability when capability.method == method) {
        return capability;
      }
    }
    return null;
  }
}

typedef _Seen = ({AgentView<Object?> view, Object? value, String json});
