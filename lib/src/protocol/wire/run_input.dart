import 'package:tandem/src/protocol/wire/messages.dart';

/// The request body of one run, as the session builds it.
///
/// An adapter sends [toJson] as it is. By the time an adapter sees an input,
/// Tandem has applied the protocol rules: the session's one thread id, a new
/// run id, the whole history with every earlier tool call answered, [tools]
/// always present (possibly empty) and [state] holding only the app's own
/// top-level keys.
final class RunInput {
  /// Creates a run input.
  const RunInput({
    required this.threadId,
    required this.runId,
    required this.messages,
    required this.tools,
    required this.state,
    this.context = const [],
    this.forwardedProps = const {},
  });

  /// The session's id. AG-UI calls a session a thread.
  final String threadId;

  /// The id of this run, new for every run.
  final String runId;

  /// The whole history of the session, oldest first.
  final List<WireMessage> messages;

  /// The tools the app offers to the agent.
  final List<WireTool> tools;

  /// The shared state: only the top-level keys the app owns.
  final Map<String, Object?> state;

  /// Extra facts for the agent, such as the locale or the fields the user
  /// changed by hand.
  final List<WireContext> context;

  /// Data passed through to the agent backend unchanged.
  final Map<String, Object?> forwardedProps;

  /// The AG-UI request body, with camelCase keys. Always contains every key,
  /// because some backends fail when `tools` is missing.
  Map<String, Object?> toJson() => {
    'threadId': threadId,
    'runId': runId,
    'state': state,
    'messages': [for (final message in messages) message.toJson()],
    'tools': [for (final tool in tools) tool.toJson()],
    'context': [for (final entry in context) entry.toJson()],
    'forwardedProps': forwardedProps,
  };
}

/// A tool the app offers to the agent, as AG-UI declares it.
final class WireTool {
  /// Creates a tool declaration.
  const WireTool({
    required this.name,
    required this.description,
    required this.parameters,
  });

  /// The name the agent calls.
  final String name;

  /// What the tool does, for the model.
  final String description;

  /// The JSON Schema of the arguments.
  final Map<String, Object?> parameters;

  /// The AG-UI JSON of this declaration.
  Map<String, Object?> toJson() => {
    'name': name,
    'description': description,
    'parameters': parameters,
  };
}

/// One entry of extra context for the agent.
final class WireContext {
  /// Creates a context entry.
  const WireContext({required this.description, required this.value});

  /// What the value is, in words the model understands.
  final String description;

  /// The value.
  final String value;

  /// The AG-UI JSON of this entry.
  Map<String, Object?> toJson() => {'description': description, 'value': value};
}
