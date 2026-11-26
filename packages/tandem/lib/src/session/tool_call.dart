import 'dart:async';
import 'dart:convert';

import 'package:tandem/src/agent_list.dart';
import 'package:tandem/src/chat/chat_item.dart';
import 'package:tandem/src/errors.dart';
import 'package:tandem/src/protocol/ag_ui.dart';
import 'package:tandem/src/protocol/ag_ui_ids.dart';
import 'package:tandem/src/report.dart';
import 'package:tandem/src/session/caller.dart';
import 'package:tandem/src/session/tool_answer.dart';
import 'package:tandem/src/tool_name.dart';

/// A call of a listed method or of the view's tool, from the moment it is
/// made until it has its answer: the in-app agent's goes out with the next
/// run.
final class ToolCall({
  required final ToolCallId id,
  required final String tool,

  /// The method's doc comment, as the agent got it.
  required final String description,
  required final Caller caller,
  required final String argumentsJson,
}) {
  /// The id of the tool message that answers the call. A backend may repeat
  /// [id] in a later run of the thread, so the answer has an id of its own.
  final answerId = MessageId.local();

  /// The listed method and the arguments of a call that waits for the user,
  /// frozen when it asked.
  ({ToolName tool, FrozenArguments arguments})? _frozen;

  ToolAnswer? _answer;
  final _answered = Completer<ToolAnswer>();

  /// Null while the call waits to run or for the user.
  ToolAnswer? get answer => _answer;

  /// Completes with the call's first answer. Dispose cancels a call whose
  /// method still runs, and the method's answer comes after it.
  Future<ToolAnswer> get answered => _answered.future;

  ChatEntry<ApprovalRequest>? _card;

  /// Null until the call showed to the user.
  ApprovalRequest? get request => _card?.value;

  bool get pending => request?.status == .pending;
  bool get approved => request?.status == .approved;

  /// The arguments, or null when they are not a JSON object.
  JsonObject? get objectArguments => decodeJsonObject(argumentsJson);

  CallArguments get argumentsToRun =>
      _frozen?.arguments ?? WrittenArguments(objectArguments ?? const {});

  /// Freezes each path at its value in [seen], while it still holds, so the
  /// user approves what the method gets. Returns the answer when it cannot.
  ToolAnswer? freeze(AgentListing seen) {
    try {
      final (:args, :target) = seen.prepare(
        tool,
        WrittenArguments(objectArguments ?? const {}),
        approved: true,
      );
      _frozen = (tool: target.name, arguments: FrozenArguments(args.json));
      return null;
    } on ToolCallRefused catch (refusal) {
      return .refused(refusal.message);
    } catch (err, st) {
      report(err, st);
      return ToolAnswer.failed;
    }
  }

  void answerWith(ToolAnswer answer) {
    _answer = answer;
    if (!_answered.isCompleted) {
      _answered.complete(answer);
    }
  }

  /// Whether [other] calls the same tool with the same frozen arguments,
  /// whatever the order of the keys its caller wrote.
  bool isSameCall(ToolCall other) =>
      tool == other.tool &&
      jsonEncode(_frozen?.arguments.json) ==
          jsonEncode(other._frozen?.arguments.json);

  ApprovalRequest ask(List<ChatItem> chat) {
    final frozen = _frozen;
    if (frozen == null) {
      throw StateError('Freeze $tool before asking for approval.');
    }

    final request = ApprovalRequest.issued(
      toolCallId: id,
      tool: frozen.tool,
      description: description,
      argumentsJson: jsonEncode(frozen.arguments.json),
      caller: caller,
    );
    _card = ChatEntry(chat, request);
    return request;
  }

  /// Gives the call the answer that [status] means, and its request, when it
  /// showed, that status. A call that is pending or approved has no answer
  /// yet.
  void decide(ApprovalStatus status) {
    if (_card case final card?) card.value = card.value.withStatus(status);
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
