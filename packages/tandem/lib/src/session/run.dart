import 'package:tandem/src/agent_list.dart';
import 'package:tandem/src/chat/chat_item.dart';
import 'package:tandem/src/protocol/ag_ui.dart';
import 'package:tandem/src/protocol/events.dart';
import 'package:tandem/src/protocol/run_input.dart';
import 'package:tandem/src/session/session_status.dart';
import 'package:tandem/src/session/tool_call.dart';
import 'package:tandem/src/session/view_tool.dart';

/// A view a run offers the agent, with its tool.
typedef OfferedView = ({ViewTool tool, JsonObject definition});

/// What the session keeps of its open run.
final class Run(
  final AgentListing listing, {

  /// The view the run offers the agent to draw on.
  final OfferedView? view,
}) {
  /// The agent's messages as the chat shows them, by message id.
  final texts = <String, AgentMessage>{};

  /// The calls that run in the app.
  final calls = <String, ToolCall>{};
  bool stopped = false;

  /// Whether what the agent sees differed from what this run sent, at any
  /// check since it started, even when it changed back.
  bool seesChanged = false;

  /// The listed method that runs now.
  Calling? calling;

  /// Set by `RUN_FINISHED` and `RUN_ERROR`, so the end of the stream that
  /// follows does not count as a lost connection.
  bool ended = false;

  /// The ids of the agent's messages in the order they started, each with the
  /// ids of its calls.
  final _messages = <String, List<String>>{};
  final _backendCalls = <String, _BackendCall>{};

  /// The id of the latest call of a tool that is not a listed method, until
  /// the agent's next text or call, or its result.
  String? _used;

  /// Adds the [text] to the agent's message. Returns the message as it grew
  /// and the one it replaces, null for a new message.
  ({AgentMessage? shown, AgentMessage grown}) write(TextDelta text) {
    final TextDelta(:messageId, :delta) = text;
    _used = null;
    _messages.putIfAbsent(messageId, () => []);
    final shown = texts[messageId];
    final grown = texts[messageId] = AgentMessage('${shown?.text ?? ''}$delta');
    return (shown: shown, grown: grown);
  }

  /// The tools of the run: the listed methods, then the view's tool.
  List<JsonObject> get tools => [...listing.tools, ?view?.definition];

  /// The tool of the backend that runs now, such as a search.
  String? get backendTool => _backendCalls[_used]?.tool;

  /// Whether the agent draws a view now.
  bool get drawing => calls[_used]?.tool == ViewTool.name;

  /// Whether a call of [tool] runs in the app, not on the backend.
  bool offers(String tool) =>
      listing.lists(tool) || (tool == ViewTool.name && view != null);

  /// A call starts, in the agent's message that the event names. It becomes
  /// one of [calls] when it runs in the app, as does a call the run already
  /// has. The first start of a backend call counts.
  void startTool(ToolCallStarted start) {
    final ToolCallStarted(toolCallId: id, name: tool, :parentMessageId) = start;
    final knownTool = calls[id]?.tool ?? _backendCalls[id]?.tool;
    if (knownTool != null) {
      if (knownTool != tool) {
        throw const FormatException('A tool call changed its method.');
      }
      return;
    }

    _used = listing.lists(tool) ? null : id;
    if (offers(tool)) {
      // A call of the view's tool never asks the user, so needs no
      // description.
      final description = listing.lists(tool) ? listing.description(tool) : '';
      calls[id] = ToolCall(id, tool, description, caller: .inAppAgent);
      _addToMessage(id, parentMessageId);
    } else {
      _backendCalls[id] = _BackendCall(tool);
      _addToMessage(id, parentMessageId);
    }
  }

  void addArguments(ToolCallArgs arguments) {
    final ToolCallArgs(:toolCallId, :delta) = arguments;
    if (calls[toolCallId] case final call?) {
      call.arguments += delta;
    } else if (_backendCalls[toolCallId] case final call?) {
      call.arguments += delta;
    }
  }

  /// A tool of the backend returned its [result].
  void finishTool(ToolCallResult result) {
    if (_used == result.toolCallId) {
      _used = null;
    }
    _backendCalls[result.toolCallId]?.result = result;
  }

  /// What the agent sent, in order: its messages with their text and the
  /// calls they hold.
  List<SentMessage> get sent => [
    for (final MapEntry(key: id, value: callIds) in _messages.entries)
      (
        id: id,
        text: texts[id]?.text,
        calls: [for (final callId in callIds) ?_sentCall(callId)],
      ),
  ];

  void _addToMessage(String callId, String? parentMessageId) => _messages
      .putIfAbsent(
        parentMessageId ?? AgUiMessage.idOfCallWithoutMessage(callId),
        () => [],
      )
      .add(callId);

  SentCall? _sentCall(String id) {
    final result = _backendCalls[id]?.result;
    return switch ((calls[id], _backendCalls[id])) {
      (final call?, _) => (
        id: id,
        tool: call.tool,
        arguments: call.argumentsJson,
        inApp: true,
        result: result,
      ),
      (null, final call?) => (
        id: id,
        tool: call.tool,
        arguments: call.argumentsJson,
        inApp: false,
        result: result,
      ),
      (null, null) => null,
    };
  }
}

/// A message of the agent in a run, with the calls it holds.
typedef SentMessage = ({String id, String? text, List<SentCall> calls});

/// A call in a [SentMessage]. A call of the backend has the `result` that
/// its `TOOL_CALL_RESULT` brought, once it came.
typedef SentCall = ({
  String id,
  String tool,
  String arguments,
  bool inApp,
  ToolCallResult? result,
});

final class _BackendCall(final String tool) {
  String arguments = '';
  ToolCallResult? result;

  // As for a listed method: a call without arguments has no `TOOL_CALL_ARGS`.
  String get argumentsJson => arguments.isEmpty ? '{}' : arguments;
}
