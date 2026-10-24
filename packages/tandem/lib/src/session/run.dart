import 'package:tandem/src/agent_list.dart';
import 'package:tandem/src/chat/chat_item.dart';
import 'package:tandem/src/protocol/ag_ui.dart';
import 'package:tandem/src/protocol/run_input.dart';
import 'package:tandem/src/session/attached_view.dart';
import 'package:tandem/src/session/tool_call.dart';

/// What the session keeps of its open run.
final class Run(
  final AgentListing listing, {

  /// The view attached when the run started, whose tool the run offers.
  final AttachedView? view,
}) {
  /// The agent's messages as the chat shows them, by message id.
  final texts = <String, AgentMessage>{};
  final calls = <String, ToolCall>{};
  bool stopped = false;

  /// Whether what the agent sees differed from what this run sent, at any
  /// check since it started, even when it changed back.
  bool seesChanged = false;

  /// Set by `RUN_FINISHED` and `RUN_ERROR`, so the end of the stream that
  /// follows does not count as a lost connection.
  bool ended = false;

  /// Adds [delta] to the agent's message [messageId]. Returns the message as
  /// it grew and the one it replaces, null for a new message.
  ({AgentMessage? shown, AgentMessage grown}) write(
    String messageId,
    String delta,
  ) {
    final shown = texts[messageId];
    final grown = texts[messageId] = AgentMessage('${shown?.text ?? ''}$delta');
    return (shown: shown, grown: grown);
  }

  /// The `tools` of AG-UI's `RunAgentInput`: the listed methods, then the
  /// view's tool.
  List<JsonObject> get tools => [...listing.tools, ?view?.tool];

  /// Whether a call of [tool] goes to the app: a listed method, or the
  /// view's tool.
  bool offers(String tool) => listing.lists(tool) || viewOf(tool) != null;

  /// The view that answers a call of [tool], null for a listed method.
  AttachedView? viewOf(String tool) =>
      tool == AttachedView.toolName ? view : null;

  void startCall(String id, String tool) {
    if (calls[id] case final call?) {
      if (call.tool != tool) {
        throw const FormatException('A tool call changed its method.');
      }
    } else {
      // Only a call that needs approval shows its description.
      final description = viewOf(tool) == null ? listing.description(tool) : '';
      calls[id] = ToolCall(id, tool, description);
    }
  }

  List<AgUiMessage> get assistantTexts => [
    for (final MapEntry(key: id, value: message) in texts.entries)
      AgUiMessage.assistantText(id, message.text),
  ];
}
