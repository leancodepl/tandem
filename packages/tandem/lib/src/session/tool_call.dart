import 'dart:async';

import 'package:tandem/src/chat/chat_item.dart';
import 'package:tandem/src/protocol/ag_ui.dart';
import 'package:tandem/src/session/caller.dart';
import 'package:tandem/src/session/tool_answer.dart';

/// A call of a listed method or of the view's tool, from the moment it is
/// made until it has its answer: the in-app agent's goes out with the next
/// run.
final class ToolCall(
  final String id,
  final String tool,

  /// The method's doc comment, as the agent got it.
  final String description, {
  required final Caller caller,
}) {
  /// The JSON arguments, as streamed so far.
  String arguments = '';

  ToolAnswer? _answer;
  final _answered = Completer<ToolAnswer>();

  /// Null while the call waits to run or for the user.
  ToolAnswer? get answer => _answer;

  /// Completes with the call's first answer. Dispose cancels a call whose
  /// method still runs, and the method's answer comes after it.
  Future<ToolAnswer> get answered => _answered.future;

  ApprovalRequest? _request;

  /// Null until the call showed to the user.
  ApprovalRequest? get request => _request;

  bool get pending => request?.status == .pending;
  bool get approved => request?.status == .approved;

  // ag-ui-adk sends no `TOOL_CALL_ARGS` for a call without arguments.
  String get argumentsJson => arguments.isEmpty ? '{}' : arguments;

  /// The arguments, or null when they are not a JSON object.
  JsonObject? get objectArguments => decodeJsonObject(argumentsJson);

  void answerWith(ToolAnswer answer) {
    _answer = answer;
    if (!_answered.isCompleted) {
      _answered.complete(answer);
    }
  }

  ApprovalRequest ask() => _request = ApprovalRequest(
    toolCallId: id,
    tool: tool,
    description: description,
    argumentsJson: argumentsJson,
    caller: caller,
  );

  /// Gives the call the answer that [status] means, and its request, when it
  /// showed, that status. A call that is pending or approved has no answer
  /// yet.
  void decide(ApprovalStatus status) {
    _request = _request?.withStatus(status);
    final answer = switch (status) {
      .rejected => ToolAnswer.rejected,
      .cancelled => ToolAnswer.cancelled,
      .invalidated => ToolAnswer.invalidated,
      .pending || .approved => null,
    };
    if (answer != null) {
      answerWith(answer);
    }
  }
}
