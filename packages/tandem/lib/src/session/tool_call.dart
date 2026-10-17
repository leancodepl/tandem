import 'dart:convert';

import 'package:tandem/src/chat/chat_item.dart';
import 'package:tandem/src/session/tool_answer.dart';

/// The agent's call of a listed method, from its run until its answer goes
/// out with the next run.
final class ToolCall(final String id, final String tool) {
  /// The JSON arguments, as streamed so far.
  String arguments = '';

  /// Null while the call waits to run or for the user.
  ToolAnswer? answer;
  ApprovalRequest? request;

  bool get pending => request?.status == .pending;
  bool get approved => request?.status == .approved;

  // ag-ui-adk sends no `TOOL_CALL_ARGS` for a call without arguments.
  String get argumentsJson => arguments.isEmpty ? '{}' : arguments;

  bool get hasObjectArguments {
    try {
      return jsonDecode(argumentsJson) is Map<String, Object?>;
    } on FormatException {
      return false;
    }
  }

  /// Gives the call a pending card that shows [description].
  ApprovalRequest ask(String description) => request = ApprovalRequest(
    toolCallId: id,
    tool: tool,
    description: description,
    argumentsJson: argumentsJson,
  );
}
