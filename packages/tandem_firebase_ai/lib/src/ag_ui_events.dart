import 'package:tandem/tandem.dart' show RunErrorCode;
import 'package:tandem_firebase_ai/src/ag_ui_ids.dart';
import 'package:tandem_firebase_ai/src/json_object.dart';

/// Writes the AG-UI events of one run that answers with a single assistant
/// message. [text] and [toolCall] start the message when it has not started.
final class AgUiEvents(
  final Sink<JsonObject> _sink, {
  required final AgUiThreadId _threadId,
  required final AgUiRunId _runId,
}) {
  final _messageId = MessageId.unique();
  var _messageStarted = false;

  /// AG-UI gives `RUN_ERROR` no ids, so the event also fits a run that never
  /// started.
  static JsonObject runErrorEvent(RunErrorCode code, String message) => {
    'type': 'RUN_ERROR',
    'code': code,
    'message': message,
  };

  void runStarted() => _sink.add({'type': 'RUN_STARTED', ..._runIds});

  void runFinished() => _sink.add({'type': 'RUN_FINISHED', ..._runIds});

  /// The end of a run that was stopped.
  void runCancelled() => _sink.add({
    'type': 'RUN_FINISHED',
    ..._runIds,
    'outcome': {'type': 'cancelled'},
  });

  void runError(RunErrorCode code, String message) =>
      _sink.add(runErrorEvent(code, message));

  void text(String delta) {
    _startMessageOnce();
    _sink.add({
      'type': 'TEXT_MESSAGE_CONTENT',
      'messageId': _messageId.value,
      'delta': delta,
    });
  }

  /// A whole call of the message.
  void toolCall(
    ToolCallId id, {
    required AgUiToolName name,
    required String argumentsJson,
  }) {
    _startMessageOnce();
    _sink
      ..add({
        'type': 'TOOL_CALL_START',
        'toolCallId': id.value,
        'toolCallName': name.value,
        'parentMessageId': _messageId.value,
      })
      ..add({
        'type': 'TOOL_CALL_ARGS',
        'toolCallId': id.value,
        'delta': argumentsJson,
      })
      ..add({'type': 'TOOL_CALL_END', 'toolCallId': id.value});
  }

  /// Ends the message. [metadata] stays with it in the thread.
  void messageEnd({required JsonObject metadata}) => _sink.add({
    'type': 'TEXT_MESSAGE_END',
    'messageId': _messageId.value,
    'metadata': metadata,
  });

  JsonObject get _runIds => {
    'threadId': _threadId.value,
    'runId': _runId.value,
  };

  void _startMessageOnce() {
    if (_messageStarted) return;

    _messageStarted = true;
    _sink.add({
      'type': 'TEXT_MESSAGE_START',
      'messageId': _messageId.value,
      'role': 'assistant',
    });
  }
}
