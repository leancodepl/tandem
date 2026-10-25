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

  /// Adds [delta] to the agent's message [messageId]. Returns the message as
  /// it grew and the one it replaces, null for a new message.
  ({AgentMessage? shown, AgentMessage grown}) write(
    String messageId,
    String delta,
  ) {
    _used = null;
    _messages.putIfAbsent(messageId, () => []);
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
  String? get backendTool => _backendCalls[_used]?.tool;

  /// Whether the agent draws a view now.
  bool get drawing => calls[_used]?.tool == ViewTool.name;

  /// Whether a call of [tool] runs in the app, not on the backend.
  bool offers(String tool) =>
      listing.lists(tool) || (tool == ViewTool.name && view != null);

  /// A call of [tool] starts, in the agent's message [parentMessageId]. It
  /// becomes one of [calls] when it runs in the app, as does a call the run
  /// already has. The first start of a backend call counts.
  void startTool(String id, String tool, String? parentMessageId) {
    _used = listing.lists(tool) ? null : id;
    if (calls[id] case final call?) {
      if (call.tool != tool) {
        throw const FormatException('A tool call changed its method.');
      }
    } else if (offers(tool)) {
      // A call of the view's tool never asks the user, so needs no
      // description.
      final description = listing.lists(tool) ? listing.description(tool) : '';
      calls[id] = ToolCall(id, tool, description, caller: .inAppAgent);
      _addToMessage(id, parentMessageId);
    } else if (!_backendCalls.containsKey(id)) {
      _backendCalls[id] = _BackendCall(tool);
      _addToMessage(id, parentMessageId);
    }
  }

  void addArguments(String id, String delta) {
    if (calls[id] case final call?) {
      call.arguments += delta;
    } else if (_backendCalls[id] case final call?) {
      call.arguments += delta;
    }
  }

  /// A tool of the backend returned [content] for the call [id], as the
  /// message [messageId].
  void finishTool(String messageId, String id, String content) {
    if (_used == id) {
      _used = null;
    }
    _backendCalls[id]?.result = .toolResult(messageId, id, content);
  }

  /// The run as the thread sends it back: each message of the agent with its
  /// text and calls, then the results of its calls that ran on the backend. A
  /// backend call without a result stays out.
  List<AgUiMessage> get history => [
    for (final MapEntry(key: id, value: callIds) in _messages.entries) ...[
      ?_message(id, callIds),
      for (final callId in callIds) ?_backendCalls[callId]?.result,
    ],
  ];

  /// What the agent said, without its calls.
  List<AgUiMessage> get assistantTexts => [
    for (final MapEntry(key: id, value: message) in texts.entries)
      AgUiMessage.assistant(id, text: message.text),
  ];

  // Without a parent, never the bare call id: ag-ui-adk marks every message
  // id it has seen as processed, and would swallow the answer that comes later.
  void _addToMessage(String callId, String? parentMessageId) => _messages
      .putIfAbsent(parentMessageId ?? 'asst-$callId', () => [])
      .add(callId);

  AgUiMessage? _message(String id, List<String> callIds) {
    final toolCalls = [
      for (final callId in callIds)
        if (calls[callId] case final call?)
          AgUiToolCall(callId, call.tool, call.argumentsJson)
        else if (_backendCalls[callId] case final call?
            when call.result != null)
          AgUiToolCall(callId, call.tool, call.argumentsJson),
    ];
    final text = texts[id]?.text;
    if (text == null && toolCalls.isEmpty) {
      return null;
    }
    return .assistant(id, text: text, toolCalls: toolCalls);
  }
}

final class _BackendCall(final String tool) {
  String arguments = '';
  AgUiMessage? result;

  // As for a listed method: a call without arguments has no `TOOL_CALL_ARGS`.
  String get argumentsJson => arguments.isEmpty ? '{}' : arguments;
}
