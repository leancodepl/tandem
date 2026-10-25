import 'package:tandem/src/agent_list.dart';
import 'package:tandem/src/chat/chat_item.dart';
import 'package:tandem/src/protocol/ag_ui.dart';
import 'package:tandem/src/protocol/run_input.dart';
import 'package:tandem/src/session/session_status.dart';
import 'package:tandem/src/session/tool_call.dart';
import 'package:tandem/src/session/view_tool.dart';

/// What the session keeps of its open run.
final class Run(
  final AgentListing listing, {

  /// The view the run offers the agent to draw on.
  final ViewTool? view,
}) {
  /// The agent's messages as the chat shows them, by message id.
  final texts = <String, AgentMessage>{};
  final calls = <String, ToolCall>{};
  bool stopped = false;

  /// Whether what the agent sees differed from what this run sent, at any
  /// check since it started, even when it changed back.
  bool seesChanged = false;

  /// The listed method that runs now.
  Calling? calling;

  /// The latest call of a tool that is not a listed method, until the
  /// agent's next text or call, or its result.
  ({String id, String tool})? _used;

  /// Set by `RUN_FINISHED` and `RUN_ERROR`, so the end of the stream that
  /// follows does not count as a lost connection.
  bool ended = false;

  /// Adds [delta] to the agent's message [messageId]. Returns the message as
  /// it grew and the one it replaces, null for a new message.
  ({AgentMessage? shown, AgentMessage grown}) write(
    String messageId,
    String delta,
  ) {
    _used = null;
    final shown = texts[messageId];
    final grown = texts[messageId] = AgentMessage('${shown?.text ?? ''}$delta');
    return (shown: shown, grown: grown);
  }

  /// The tools of the run: the listed methods, then the view's tool.
  List<JsonObject> get tools => [
    ...listing.tools,
    if (view case final view?) view.definition,
  ];

  /// The tool of the backend that runs now, such as a search.
  String? get backendTool => drawing ? null : _used?.tool;

  /// Whether the agent draws a view now.
  bool get drawing => _used?.tool == ViewTool.name && view != null;

  /// Whether a call of [tool] runs in the app, not on the backend.
  bool offers(String tool) =>
      listing.lists(tool) || (tool == ViewTool.name && view != null);

  /// A call of [tool] starts. It becomes one of [calls] when it runs in the
  /// app, as does a call the run already has.
  void startTool(String id, String tool) {
    _used = listing.lists(tool) ? null : (id: id, tool: tool);
    if (calls[id] case final call?) {
      if (call.tool != tool) {
        throw const FormatException('A tool call changed its method.');
      }
    } else if (offers(tool)) {
      // A call of the view's tool never asks the user, so needs no
      // description.
      final description = listing.lists(tool) ? listing.description(tool) : '';
      calls[id] = ToolCall(id, tool, description, caller: .inAppAgent);
    }
  }

  /// A tool of the backend returned [id]'s result.
  void finishTool(String id) {
    if (_used?.id == id) {
      _used = null;
    }
  }

  List<AgUiMessage> get assistantTexts => [
    for (final MapEntry(key: id, value: message) in texts.entries)
      AgUiMessage.assistantText(id, message.text),
  ];
}
