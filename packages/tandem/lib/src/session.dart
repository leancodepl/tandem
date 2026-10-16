import 'dart:async';
import 'dart:collection';
import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:tandem/src/agent_list.dart';
import 'package:tandem/src/agent_schema.dart';
import 'package:tandem/src/chat/chat_item.dart';
import 'package:tandem/src/errors.dart';
import 'package:tandem/src/ids.dart';
import 'package:tandem/src/protocol/agent_connection.dart';
import 'package:tandem/src/protocol/events.dart';
import 'package:tandem/src/protocol/run_input.dart';

// Tool answers. The status goes in `content`: ag-ui-adk ignores a tool
// message's `error`, and the model reads an empty content as success.
const _cancelled = '{"status":"cancelled"}';
String _refused(String reason) =>
    jsonEncode({'status': 'refused', 'reason': reason});
String _failed(Object err) => jsonEncode({'status': 'failed', 'error': '$err'});

// The arguments of a call that has no `TOOL_CALL_ARGS`.
const _noArguments = '{}';

// The library named in the errors the session reports.
const _library = 'tandem';

/// Reports an error the session caught, so that it reaches the logs.
void _report(Object err, StackTrace st) => FlutterError.reportError(
  FlutterErrorDetails(exception: err, stack: st, library: _library),
);

/// Called after the agent called a listed method and it returned: [tool] is
/// the method's snake_case name and [result] its result as JSON. Not called
/// for a call that was refused or threw.
typedef AgentCallListener = void Function(
  String tool,
  Map<String, Object?> arguments,
  Object? result,
);

/// The chat of the user and the agent about one screen.
///
/// Every run reads the screen's agent list again. When a run finishes, the
/// calls of listed methods run, and the next run, which starts at once,
/// takes their answers to the agent. One run is open at a time: a message
/// sent meanwhile shows at once and waits. A run that breaks off moves the
/// chat to a new AG-UI thread.
final class TandemSession({
  required final AgentSurface _surface,
  required Stream<Object?> changes,
  required final AgentConnection _connection,
  final AgentCallListener? _onAgentCall,
}) extends ChangeNotifier {
  /// A chat about `surface`, whose state changes `changes` reports, over
  /// `connection`. `onAgentCall` hears every call of a listed method that
  /// ran.
  this {
    _changes = changes.listen(null);
  }

  late final StreamSubscription<Object?> _changes;
  StreamSubscription<Map<String, Object?>>? _subscription;
  final _items = <ChatItem>[];
  final _waiting = <String>[];
  final _history = <Map<String, Object?>>[];
  var _threadId = newId();
  _Run? _run;
  var _stopping = false;

  /// The calls of the last finished run, answered first in the next run.
  var _calls = <_Call>[];

  /// The chat, oldest first.
  List<ChatItem> get items => UnmodifiableListView(_items);

  /// Whether a run is open or the calls of its turn are running.
  bool get isRunning => _run != null;

  /// Whether the user stopped the open run, which is read to its end.
  bool get isStopping => _stopping;

  /// Sends [text], trimmed; does nothing when it is empty. The message shows
  /// at once, and its run starts when no other run is open.
  void send(String text) {
    final message = text.trim();
    if (message.isEmpty) {
      return;
    }
    _items.add(UserMessage(message));
    _waiting.add(message);
    if (!isRunning) {
      _sendNext();
    }
    notifyListeners();
  }

  /// Stops the open run. It is still read to its end, because ADK goes on
  /// anyway and the thread stays consistent only that way, but its later
  /// text is hidden, none of its calls runs, and no run follows it. Does
  /// nothing when no run is open.
  void stop() {
    final run = _run;
    if (run == null || _stopping) {
      return;
    }
    _stopping = true;
    if (run.texts.keys.lastOrNull case final last?) {
      _items[run.items[last]!] = AgentMessage(run.texts[last]!, stopped: true);
    } else {
      _items.add(const ChatNotice(.stopped));
    }
    notifyListeners();
  }

  /// Closes the connection of the open run. The thread is not used again.
  @override
  void dispose() {
    _run = null;
    unawaited(_subscription?.cancel());
    unawaited(_changes.cancel());
    super.dispose();
  }

  void _sendNext() {
    if (_waiting.isNotEmpty) {
      _start(_waiting.removeAt(0));
    }
  }

  /// Opens a run that answers the calls of the last run and then says
  /// [text], if any.
  void _start([String? text]) {
    final listing = AgentListing.of(_surface);
    _history.addAll([
      for (final call in _calls) toolAnswer(call.id, call.answer ?? _cancelled),
      if (text != null) userMessage(newId(), text),
    ]);
    _calls = [];
    final run = _run = _Run(listing);
    final input = runInput(
      threadId: _threadId,
      runId: newId(),
      messages: [..._history],
      listing: listing,
    );
    _subscription = _connection
        .run(input)
        .listen(
          (json) => _read(run, .fromJson(json)),
          onError: (Object err, StackTrace st) {
            _report(err, st);
            _break(run);
          },
          onDone: () => _break(run),
          cancelOnError: true,
        );
  }

  void _read(_Run run, AgentEvent event) {
    switch (event) {
      case RunFinished():
        run.ended = true;
        unawaited(_finish(run));
      case RunFailed():
        run.ended = true;
        // ADK never saw the calls of this run answered: they are dropped.
        _history.addAll(run.said);
        _items.add(const ChatNotice(.runFailed));
        _end();
      case _:
        if (run.read(event, showText: !_stopping) case final messageId?) {
          final message = AgentMessage(run.texts[messageId]!);
          if (run.items[messageId] case final index?) {
            _items[index] = message;
          } else {
            run.items[messageId] = _items.length;
            _items.add(message);
          }
          notifyListeners();
        }
    }
  }

  /// Keeps what [run] said and called, runs its calls in order, and starts
  /// the next run.
  Future<void> _finish(_Run run) async {
    _calls = [...run.calls.values];
    _history.addAll([
      ...run.said,
      for (final call in _calls)
        assistantToolCall(call.id, call.tool, call.json),
    ]);
    for (final call in _calls) {
      // Stop can come while an earlier call runs.
      if (_stopping) {
        break;
      }
      call.answer = await _execute(run.listing, call);
      if (_run != run) {
        return; // Disposed meanwhile.
      }
    }
    _end(
      followUp:
          _calls.isNotEmpty &&
          !_stopping &&
          _calls.every((call) => call.answer != null),
    );
  }

  /// Calls the method behind [call] and returns the answer for the agent.
  Future<String> _execute(AgentListing listing, _Call call) async {
    final Map<String, Object?> arguments;
    final Object? result;
    try {
      arguments = jsonDecode(call.json) as Map<String, Object?>;
      result = await listing.call(call.tool, arguments);
    } on ToolCallRefused catch (err) {
      return _refused(err.message);
    } catch (err, st) {
      _report(err, st);
      return _failed(err);
    }
    _onAgentCall?.call(call.tool, arguments, result);
    return jsonEncode(result);
  }

  /// [run] broke off without `RUN_FINISHED` or `RUN_ERROR`. What ADK kept of
  /// it is unknown, so the chat goes on in a new thread with no history.
  void _break(_Run run) {
    if (run.ended) {
      return;
    }
    _items.add(const ChatNotice(.connectionLost));
    _threadId = newId();
    _history.clear();
    _end();
  }

  /// Closes the open run and starts the follow-up run that answers its calls,
  /// or the run of the next waiting message.
  void _end({bool followUp = false}) {
    _run = null;
    _stopping = false;
    if (followUp) {
      _start();
    } else {
      _sendNext();
    }
    notifyListeners();
  }
}

/// One run, assembled from its events: the text the user saw, and the calls
/// of the tools [listing] lists. Calls of other tools run on the server.
final class _Run(final AgentListing listing) {
  /// The text shown, per `messageId`.
  final texts = <String, String>{};

  /// Where each message of [texts] is in the chat.
  final items = <String, int>{};

  /// The calls of listed tools, per `toolCallId`.
  final calls = <String, _Call>{};

  /// Whether `RUN_FINISHED` or `RUN_ERROR` came.
  bool ended = false;

  /// [texts] as assistant messages of the history.
  List<Map<String, Object?>> get said => [
    for (final MapEntry(:key, :value) in texts.entries)
      assistantText(key, value),
  ];

  /// Reads [event], with its text only while [showText]. Returns the id of
  /// the message whose text grew.
  String? read(AgentEvent event, {required bool showText}) {
    switch (event) {
      case TextDelta(:final messageId, :final delta) when showText:
        texts[messageId] = (texts[messageId] ?? '') + delta;
        return messageId;
      case ToolCallStarted(:final toolCallId, :final name)
          when listing.tools.any((tool) => tool['name'] == name):
        calls[toolCallId] = _Call(toolCallId, name);
      case ToolCallArgs(:final toolCallId, :final delta):
        calls[toolCallId]?.arguments += delta;
      case _:
    }
    return null;
  }
}

/// A call of a listed tool.
final class _Call(final String id, final String tool) {
  /// The JSON arguments, joined from `TOOL_CALL_ARGS`.
  String arguments = '';

  /// The answer for the agent, once there is one.
  String? answer;

  /// [arguments], or an empty object when the agent sent none.
  String get json => arguments.isEmpty ? _noArguments : arguments;
}
