import 'dart:async';

import 'package:tandem/src/agent_list.dart';
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
  /// One item for every `.sees` of the list, in the same order.
  required final List<AgentView> sees,

  /// One item for every method the list mentions in `.calls` or
  /// `.callsWithApproval`, listed now or not.
  required final List<AgentTool> calls,
});

final class AgentView._(
  /// The getter's name in snake_case.
  final String name,

  /// The getter's doc comment, sent to the agent with the value.
  final String description,
  final Object? Function(Object? value) _write,
) {
  /// Called by the generated code. The closure only gives Dart the getter's
  /// type [T], so the generated code does not have to name it; it is never
  /// called.
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

final class const AgentTool(
  /// The method itself, to recognize it in the agent list: two tear-offs of
  /// one method of one object are equal.
  final Function method, {

  /// The method's name in snake_case.
  required final String name,

  /// The method's doc comment, sent to the agent as the tool's description.
  required final String description,

  /// The JSON Schema of the arguments, built from the parameter types.
  required final Map<String, Object?> parameters,

  /// Calls [method] with the agent's JSON arguments and returns its result
  /// as JSON, `null` for `void`.
  required final FutureOr<Object?> Function(ToolArgs args) invoke,
});
