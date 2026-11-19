import 'dart:async';

import 'package:firebase_ai/firebase_ai.dart';
import 'package:http/http.dart' as http;
import 'package:tandem_firebase_ai/src/ag_ui_events.dart';
import 'package:tandem_firebase_ai/src/ag_ui_input.dart';
import 'package:tandem_firebase_ai/src/firebase_answer.dart';
import 'package:tandem_firebase_ai/src/firebase_failure.dart';
import 'package:tandem_firebase_ai/src/firebase_response.dart';
import 'package:tandem_firebase_ai/src/json_object.dart';
import 'package:tandem_firebase_ai/src/response_status.dart';
import 'package:tandem_firebase_ai/src/run_client.dart';

/// Asks Firebase for the one generation of a run, over the run's client.
typedef Generate = Stream<GenerateContentResponse> Function(
  AgUiInput input,
  http.Client client,
);

/// One run of a `FirebaseConnection`: a single generation, streamed as
/// AG-UI events.
///
/// The run ends once, with the first of: Gemini's whole answer, a failure,
/// a Stop, or the session cancelling [events]. Each end aborts the request.
final class FirebaseRun(
  final AgUiInput _input, {
  required final Generate _generate,
  required final ConnectionId _connectionId,
  required final Duration _idleTimeout,
}) {
  late final _controller = StreamController<JsonObject>(
    onListen: _start,
    onCancel: _release,
  );
  late final _agUi = AgUiEvents(
    _controller,
    threadId: _input.threadId,
    runId: _input.runId,
  );
  late final _client = RunClient(_idleTimeout, onCredentialsTimeout: _fail);
  final _response = FirebaseResponse();
  StreamSubscription<GenerateContentResponse>? _chunks;

  Stream<JsonObject> get events => _controller.stream;

  /// Ends the run as cancelled. Firebase may go on generating.
  void stop() => _end(_agUi.runCancelled);

  void _start() {
    // A Stop can come before the session listens.
    if (_controller.isClosed) return;

    _agUi.runStarted();
    try {
      _client.expectRequest();
      _chunks = _generate(
        _input,
        _client,
      ).listen(_receive, onError: _streamFailed, onDone: _finish);
    } on Object catch (error) {
      // The SDK refuses a setting for its backend only when it builds the
      // request, such as `SafetySetting.method` with the Gemini Developer API.
      if (error is ArgumentError) {
        _fail(FirebaseFailure.unsupportedSettings('${error.message}'));
      } else {
        _fail(error);
      }
    }
  }

  void _receive(GenerateContentResponse streamed) {
    try {
      final chunk = ResponseChunk.read(streamed);
      _response.add(chunk);

      final text = chunk.visibleText;
      if (text.isNotEmpty) _agUi.text(text);
    } on Object catch (error) {
      _fail(error);
    }
  }

  /// Hands Gemini's whole answer to Tandem: its calls, then the end of the
  /// message with the answer for the next run.
  void _finish() {
    try {
      final answer = _response.complete(offeredTools: _input.toolNames);
      for (final ProposedCall(:id, :name, :argumentsJson) in answer.calls) {
        _agUi.toolCall(id, name: name, argumentsJson: argumentsJson);
      }
      _agUi.messageEnd(metadata: answer.toMetadata(storedBy: _connectionId));
      _end(_agUi.runFinished);
    } on Object catch (error) {
      _fail(error);
    }
  }

  void _streamFailed(Object error) =>
      _fail(error, responseStatus: _client.responseStatus);

  void _fail(Object error, {ResponseStatus? responseStatus}) {
    final failure = FirebaseFailure.of(error, responseStatus: responseStatus);
    _end(() => _agUi.runError(failure.code, failure.message));
  }

  /// Writes the last event of the run and releases the run, unless it has
  /// ended.
  void _end(void Function() writeLastEvent) {
    if (_controller.isClosed) return;

    writeLastEvent();
    _release();
  }

  /// Closes the stream and aborts the request. Safe to repeat.
  void _release() {
    unawaited(_controller.close());
    _client.close();
    // The SDK's cancel can wait for an App Check token that never comes.
    _chunks?.cancel().ignore();
  }
}
