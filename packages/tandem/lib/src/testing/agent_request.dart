import 'dart:convert';

import 'package:tandem/src/protocol/ag_ui.dart';
import 'package:tandem/src/session/tool_answer.dart';
import 'package:tandem/src/session/view_tool.dart';

/// Reads the context, offered tools and latest answers of a scripted run.
/// [raw] stays available for assertions about the wire format.
final class AgentRequest(final Map<String, Object?> raw) {
  /// Whether the last message came from the user, including an app wake.
  bool get isUserMessage =>
      _messages.lastOrNull?[AgUiFields.role] == AgUiMessageRoles.user;

  /// The first named context entry, decoded from JSON, or null when absent.
  /// Throws a [FormatException] when its value is not valid JSON.
  Object? context(String name) {
    for (final entry in _objects(raw[AgUiFields.context])) {
      if (entry
          case {
            AgUiFields.description: final String description,
            AgUiFields.value: final String value,
          }
          when description.startsWith('$name:')) {
        return jsonDecode(value);
      }
    }
    return null;
  }

  /// The text of the user's latest message, including an app wake, or null
  /// when the run has none or its content is not text.
  String? get userText => switch (_messages
      .where((message) => message[AgUiFields.role] == AgUiMessageRoles.user)
      .lastOrNull) {
    {AgUiFields.content: final String text} => text,
    _ => null,
  };

  bool offersTool(String name) =>
      _objects(raw[AgUiFields.tools])
          .any((tool) => tool[AgUiFields.name] == name);

  /// Whether the run offers `tandem_show_view`, which `AgentStep.showView`
  /// calls.
  bool get offersView => offersTool(ViewTool.name);

  /// New app notes, oldest first, or an empty list when none are offered.
  List<Object?> get newNotes => switch (context('app_notes')) {
    {'new': final List<Object?> notes} => notes,
    _ => const [],
  };

  /// The actions of views the agent drew that the user pressed, from the new
  /// app notes, oldest first.
  List<PressedAction> get newPressedActions => [
    for (final note in newNotes)
      if (note
          case {'pressed': final String tool, 'status': final Object? status} &&
              final Map<String, Object?> json)
        if (ToolStatus.named(status) case final status?)
          PressedAction._(
            tool,
            arguments: json['arguments'],
            status: status,
            answer: {...json}
              ..remove('pressed')
              ..remove('arguments'),
          ),
  ];

  /// The consecutive tool answers at the end of the request, oldest first.
  /// A trailing user or assistant message leaves this empty.
  List<AgentToolResult> get latestToolResults {
    final messages = _messages;
    final names = {
      for (final message in messages)
        if (message[AgUiFields.toolCalls] case final List<Object?> calls)
          for (final call in calls)
            if (call case {
              AgUiFields.id: final String id,
              AgUiFields.function: {AgUiFields.name: final String name},
            })
              id: name,
    };
    final answers = messages.reversed.takeWhile(
      (message) => message[AgUiFields.role] == AgUiMessageRoles.tool,
    );
    return [
      for (final answer in answers)
        if (answer case {
          AgUiFields.toolCallId: final String id,
          AgUiFields.content: final String content,
        })
          AgentToolResult._(id, toolName: names[id], content: content),
    ].reversed.toList();
  }

  List<Map<String, Object?>> get _messages =>
      _objects(raw[AgUiFields.messages]).toList();
}

/// An action of a view the agent drew that the user pressed, which called
/// [tool] with [arguments].
final class PressedAction._(
  final String tool, {
  required final Object? arguments,
  required final ToolStatus status,

  /// The answer of the call as a coding agent gets it: its `status`, and its
  /// `result`, `reason` or `error`.
  required final Map<String, Object?> answer,
});

/// A tool answer joined to its call. No status is inferred from its content:
/// a returned application value can itself contain a `status` key.
final class AgentToolResult._(
  final String toolCallId, {

  /// Null when the request has no matching named call.
  required final String? toolName,

  /// The original content, including when it is not JSON.
  required final String content,
}) {
  /// The JSON-decoded [content]. Throws [FormatException] for non-JSON content.
  late final Object? value = jsonDecode(content);
}

Iterable<Map<String, Object?>> _objects(Object? value) => switch (value) {
  final List<Object?> entries => entries.whereType<Map<String, Object?>>(),
  _ => const [],
};
