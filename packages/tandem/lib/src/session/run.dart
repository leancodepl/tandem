import 'package:tandem/src/agent_list.dart';
import 'package:tandem/src/chat/chat_item.dart';
import 'package:tandem/src/protocol/ag_ui.dart';
import 'package:tandem/src/protocol/ag_ui_ids.dart';
import 'package:tandem/src/protocol/agent_connection.dart';
import 'package:tandem/src/protocol/events.dart';
import 'package:tandem/src/protocol/run_input.dart';
import 'package:tandem/src/report.dart';
import 'package:tandem/src/session/session_status.dart';
import 'package:tandem/src/session/tool_call.dart';
import 'package:tandem/src/session/view_tool.dart';

/// What the session keeps of its open run.
final class Run(
  final AgentListing listing, {

  /// The view the run offers the agent to draw on.
  final OfferedView? view,
}) {
  /// The agent's messages as the chat shows them, by message id.
  final texts = <MessageId, AgentMessage>{};

  /// The body the connection got, which a Stop sends back to it.
  late final JsonObject input;

  bool stopped = false;

  /// Whether the connection was told to stop the run on its server and did
  /// not fail, so a `RUN_ERROR` may be the server's answer.
  bool get toldToStop => _toldToStop;
  var _toldToStop = false;

  /// Whether what the agent sees differed from what this run sent, at any
  /// check since it started, even when it changed back.
  bool seesChanged = false;

  /// The listed method that runs now.
  Calling? calling;

  /// Set by `RUN_FINISHED` and `RUN_ERROR`, so the end of the stream that
  /// follows does not count as a lost connection.
  bool ended = false;

  /// The agent's messages in the order they started, with their calls.
  final _messages = <MessageId, List<_StreamedCall>>{};
  final _calls = <ToolCallId, _StreamedCall>{};

  /// The latest call of a tool that is not a listed method, until
  /// the agent's next text or call, or its result.
  _StreamedCall? _used;

  /// Tells the server of [connection] to stop this run, if the connection
  /// can and the server has not ended the run yet. Reports the error of a
  /// connection that fails to.
  Future<void> stopOnServer(AgentConnection connection) async {
    if (ended || connection is! StoppableAgentConnection) {
      return;
    }
    _toldToStop = true;
    try {
      await connection.stop(input);
    } catch (err, st) {
      _toldToStop = false;
      report(err, st);
    }
  }

  /// Adds the [text] to the agent's message. Returns the message as it grew
  /// and the one it replaces, null for a new message.
  ({AgentMessage? shown, AgentMessage grown}) write(TextDelta text) {
    final TextDelta(:delta) = text;
    final messageId = MessageId.wire(text.messageId);
    _used = null;
    _messages.putIfAbsent(messageId, () => []);
    final shown = texts[messageId];
    final grown = texts[messageId] = AgentMessage('${shown?.text ?? ''}$delta');
    return (shown: shown, grown: grown);
  }

  /// The tools of the run: the listed methods, then the view's tool.
  List<JsonObject> get tools => [...listing.tools, ?view?.definition];

  /// The tool of the backend that runs now, such as a search.
  String? get backendTool => switch (_used) {
    _StreamedCall(inApp: false, :final tool) => tool,
    _ => null,
  };

  /// Whether the agent draws a view now.
  bool get drawing => _used?.inApp == true && _used?.tool == ViewTool.name;

  /// Records the first start of a call with its parent message. A repeated
  /// start must name the same tool.
  void startTool(ToolCallStarted start) {
    final ToolCallStarted(name: tool, :parentMessageId) = start;
    final id = ToolCallId.wire(start.toolCallId);
    final knownTool = _calls[id]?.tool;
    if (knownTool != null) {
      if (knownTool != tool) {
        throw const FormatException('A tool call changed its method.');
      }
      return;
    }

    final listed = listing.lists(tool);
    final call = _StreamedCall(
      id,
      tool,
      inApp: listed || (tool == ViewTool.name && view != null),
    );
    _calls[id] = call;
    _used = listed ? null : call;
    final messageId = switch (parentMessageId) {
      final id? => MessageId.wire(id),
      // Never reuse a message id: ag-ui-adk would swallow its answer.
      null => MessageId.local(),
    };
    _messages.putIfAbsent(messageId, () => []).add(call);
  }

  void addArguments(ToolCallArgs arguments) {
    final ToolCallArgs(:delta) = arguments;
    final toolCallId = ToolCallId.wire(arguments.toolCallId);
    if (_calls[toolCallId] case final call?) {
      call.arguments += delta;
    }
  }

  /// A tool of the backend returned its [result].
  void finishTool(ToolCallResult result) {
    final call = _calls[ToolCallId.wire(result.toolCallId)];
    if (identical(_used, call)) {
      _used = null;
    }
    if (call case _StreamedCall(inApp: false)) call.result = result;
  }

  /// The calls that run in the app, once the run finished streaming.
  List<ToolCall> collectAppCalls() => [
    for (final call in _calls.values)
      if (call.inApp)
        ToolCall(
          id: call.id,
          tool: call.tool,
          description: listing.toolNamed(call.tool)?.description ?? '',
          caller: .inAppAgent,
          argumentsJson: call.argumentsJson,
        ),
  ];

  /// The messages of the run, each followed by its backend results. A
  /// backend call without a result stays out. An app-id thread also keeps
  /// the messages with app calls until their answers go out.
  ({List<AgUiMessage> all, List<AgUiMessage> withAppCalls}) get history {
    final all = <AgUiMessage>[];
    final withAppCalls = <AgUiMessage>[];
    for (final MapEntry(key: id, value: proposed) in _messages.entries) {
      final calls = [
        for (final call in proposed)
          if (call.inApp || call.result != null) call,
      ];
      final text = texts[id]?.text;
      if (text == null && calls.isEmpty) continue;
      final messages = <AgUiMessage>[
        .assistant(
          id,
          text: text,
          toolCalls: [for (final call in calls) call.wire],
        ),
        for (final call in calls)
          if (call.result case final result?)
            .toolResult(
              id: .wire(result.messageId),
              toolCallId: call.id,
              content: result.content,
            ),
      ];
      all.addAll(messages);
      if (calls.any((call) => call.inApp)) {
        withAppCalls.addAll(messages);
      }
    }
    return (all: all, withAppCalls: withAppCalls);
  }
}

final class _StreamedCall(
  final ToolCallId id,
  final String tool, {
  required final bool inApp,
}) {
  String arguments = '';
  ToolCallResult? result;

  // A call without arguments has no `TOOL_CALL_ARGS`.
  String get argumentsJson => arguments.isEmpty ? '{}' : arguments;

  AgUiToolCall get wire => .new(id: id, name: tool, arguments: argumentsJson);
}
