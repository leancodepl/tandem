import 'dart:async';

import 'package:tandem/src/agent_list.dart';
import 'package:tandem/src/agent_type.dart';
import 'package:tandem/src/errors.dart';
import 'package:tandem/src/protocol/ag_ui.dart';
import 'package:tandem/src/tool_args.dart';

/// A class with an agent list. The `_$ClassName` mixin that
/// `tandem_generator` writes for a class with `@TandemAgent()` implements it;
/// the class itself overrides [agentCapabilities] and [changes].
// The experimental lint asks for a primary constructor on an interface too.
// ignore: use_primary_constructors
abstract interface class AgentSurface {
  /// What the agent may see and call now. Tandem reads it again before every
  /// turn, so it can depend on the state.
  List<AgentCapability> get agentCapabilities;

  /// Reports every change of this object, such as a Cubit's `stream`. On each
  /// event the session checks the values listed with `.sees`, so a pending
  /// approval request is invalidated while the user looks at it. An event
  /// that comes late or changes nothing the agent sees does no harm. Every
  /// new session listens to it again, so it is a broadcast stream.
  Stream<Object?> get changes;

  AgentSchema get agentSchema;
}

/// What `tandem_generator` read from a class's agent list.
final class const AgentSchema({
  /// One item for every getter the list mentions in `.sees`. Without
  /// [capabilities], one for every `.sees` of the list, in the same order.
  required final List<AgentView<Object?>> sees,

  /// One item for every method the list mentions in `.calls` or
  /// `.callsWithApproval`, listed now or not.
  required final List<AgentTool> calls,

  /// The agent list as the generated code copies it, with each `.sees`
  /// written as `.seesAs` with its getter's name. Tandem reads the list
  /// through it, once, so the values, their getters and the methods come
  /// from one read. Null for a schema written by hand.
  final List<AgentCapability> Function()? capabilities,
});

/// One `.sees` of the agent list, as the generated code describes it.
final class const AgentView<T>._(
  /// The getter's name in snake_case.
  final String name,

  /// The getter's doc comment, sent to the agent with the value.
  final String description,

  /// The getter's type.
  final AgentType<T> type,
) {
  /// Called by the generated code: `AgentView.of(() => surface.order)` gives
  /// Dart the getter's type, and `.as(...)` its name and description. The
  /// closure is never called.
  static AgentViewOf<T> of<T>(T Function() _) => AgentViewOf<T>._();

  /// [value], read from the agent list, as JSON.
  ///
  /// Throws a [StateError] when its type is not the getter's, which means the
  /// code was not generated again after the list changed.
  Object? write(Object? value) => type.write(_checked(value));

  /// [value], read from the agent list, as the getter's type.
  T checked(Object? value) => _checked(value);

  T _checked(Object? value) => switch (value) {
    final T value => value,
    _ => throw StateError(
      'The agent list sees a ${value.runtimeType} as $name, the generated '
      'code a $T. Run build_runner again.',
    ),
  };
}

/// An [AgentView] that waits for its name, description and type.
final class AgentViewOf<T>._() {
  AgentView<T> as(String name, String description, AgentType<T> type) =>
      ._(name, description, type);
}

/// One parameter of a method of the agent list.
final class const AgentParameter<T>(
  final String name,
  final AgentType<T> type, {

  /// The parameter's doc comment.
  final String? description,

  /// Whether the agent must send it: it is neither nullable nor has a
  /// default value.
  final bool required = true,

  /// Whether the agent writes an object of a class here, field by field or
  /// in its converter's form, as `@TandemInput()` marks it. Otherwise it
  /// points at one of the values it sees with `{"path": ...}`.
  final bool input = false,
});

/// One method of the agent list, as the generated code describes it.
final class const AgentTool(
  /// The method itself, to recognize it in the agent list: two tear-offs of
  /// one method of one object are equal.
  final Function method, {

  /// The method's name in snake_case.
  required final String name,

  /// The method's doc comment, sent to the agent as the tool's description.
  required final String description,

  /// The method's parameters, in order.
  required final List<AgentParameter<Object?>> parameters,

  /// Calls [method] with the arguments read as its parameter types and
  /// returns its result as JSON, `null` for `void`.
  required final FutureOr<Object?> Function(ToolArgs args) invoke,
}) {
  /// The JSON Schema of the arguments.
  JsonObject get schema => {
    'type': 'object',
    'properties': {
      for (final parameter in parameters)
        parameter.name: {
          ...parameter.type.schema(parameter.input ? .fields : .paths),
          'description': ?parameter.description,
        },
    },
    'required': [
      for (final parameter in parameters)
        if (parameter.required) parameter.name,
    ],
  };

  /// The agent's JSON [arguments] read as the method's parameter types, a
  /// `{"path": ...}` as what [paths] gives for it. Without [paths], every
  /// object is read field by field. Throws a [ToolCallRefused] for a
  /// missing, unknown or wrong argument.
  ToolArgs read(JsonObject arguments, {AgentPaths? paths}) {
    final byName = {for (final parameter in parameters) parameter.name: null};
    for (final key in arguments.keys) {
      if (!byName.containsKey(key)) {
        throw ToolCallRefused(
          '$key: unknown, expected one of ${byName.keys.join(', ')}',
        );
      }
    }
    final values = <String, Object?>{};
    final json = <String, Object?>{};
    for (final AgentParameter(:name, :type, :required, :input) in parameters) {
      final reading = input || paths == null
          ? AgentReading(name, objects: .fields)
          : AgentReading(name, objects: .paths, paths: paths);
      if (arguments.containsKey(name)) {
        final value = values[name] = type.read(arguments[name], reading);
        json[name] = type.write(value);
      } else if (required) {
        throw reading.refuse('missing, expected ${type.expected}');
      }
    }
    return ToolArgs.of(values, json: json);
  }
}

/// A method's result, which the generated code writes as JSON with
/// `AgentResult(result).as(type)`.
final class const AgentResult<T>(final T _value) {
  Object? as(AgentType<T> type) => type.write(_value);
}
