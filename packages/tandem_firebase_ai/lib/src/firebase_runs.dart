import 'dart:async';

import 'package:firebase_ai/firebase_ai.dart';
import 'package:http/http.dart' as http;
import 'package:tandem_firebase_ai/src/firebase_failure.dart';
import 'package:tandem_firebase_ai/src/firebase_request.dart';
import 'package:tandem_firebase_ai/src/native_response.dart';
import 'package:tandem_firebase_ai/src/run_client.dart';
import 'package:uuid/uuid.dart';

typedef Generate = Stream<GenerateContentResponse> Function(
  FirebaseRequest request,
  http.Client client,
);

final class FirebaseRuns({
  required final Generate generate,
  required final String instructions,
  required final Duration idleTimeout,
}) {
  final _source = const Uuid().v4();
  final _active = Map<JsonObject, _Run>.identity();

  Stream<JsonObject> run(JsonObject input) => _Run(
    input: input,
    source: _source,
    generate: generate,
    instructions: instructions,
    idleTimeout: idleTimeout,
    onStart: _register,
    onDone: _remove,
  ).events;

  void _register(_Run run) {
    if (_active.containsKey(run.input)) {
      throw StateError('This run input is already active.');
    }
    _active[run.input] = run;
  }

  void _remove(_Run run) {
    if (identical(_active[run.input], run)) _active.remove(run.input);
  }

  Future<void> stop(JsonObject input) async => _active[input]?.stop();
}

final class _Run({
  required final JsonObject input,
  required final String source,
  required final Generate generate,
  required final String instructions,
  required final Duration idleTimeout,
  required final void Function(_Run) onStart,
  required final void Function(_Run) onDone,
}) {
  late final _controller = StreamController<JsonObject>(
    onListen: _start,
    onCancel: _dispose,
  );
  StreamSubscription<GenerateContentResponse>? _subscription;
  late final client = RunClient(idleTimeout, http.Client());
  final _response = NativeResponse();
  final _messageId = 'firebase-message-${const Uuid().v4()}';
  FirebaseRequest? _request;
  Timer? _tokenTimeout;
  var _ended = false;
  var _cleaned = false;
  var _messageStarted = false;

  Stream<JsonObject> get events => _controller.stream;

  void _start() {
    if (_ended) return;
    _controller.add(_event('RUN_STARTED'));
    try {
      onStart(this);
      final request = FirebaseRequest(
        input,
        source: source,
        instructions: instructions,
      );
      _request = request;
      _tokenTimeout = Timer(client.idleTimeout, () {
        _fail(TimeoutException('Timed out waiting for Firebase credentials.'));
      });
      client.onSend = () => _tokenTimeout?.cancel();
      _subscription = generate(
        request,
        client,
      ).listen(_chunk, onError: _streamFailed, onDone: _finish);
    } on Object catch (error) {
      _fail(error);
    }
  }

  void _chunk(GenerateContentResponse response) {
    if (_ended) return;
    try {
      final text = _response.add(response);
      if (text.isEmpty) return;
      _startMessage();
      _controller.add({
        'type': 'TEXT_MESSAGE_CONTENT',
        'messageId': _messageId,
        'delta': text,
      });
    } on Object catch (error) {
      _fail(error);
    }
  }

  void _finish() {
    if (_ended) return;
    try {
      final request = _request;
      if (request == null) throw StateError('The run did not start.');
      final answer = _response.finish(request);
      _startMessage();
      for (final call in answer.calls) {
        _controller
          ..add({
            'type': 'TOOL_CALL_START',
            'toolCallId': call.id,
            'toolCallName': call.name,
            'parentMessageId': _messageId,
          })
          ..add({
            'type': 'TOOL_CALL_ARGS',
            'toolCallId': call.id,
            'delta': call.arguments,
          })
          ..add({'type': 'TOOL_CALL_END', 'toolCallId': call.id});
      }
      _controller.add({
        'type': 'TEXT_MESSAGE_END',
        'messageId': _messageId,
        'metadata': answer.metadata,
      });
      _end(_event('RUN_FINISHED'));
    } on Object catch (error) {
      _fail(error);
    }
  }

  void _startMessage() {
    if (_messageStarted) return;
    _messageStarted = true;
    _controller.add({
      'type': 'TEXT_MESSAGE_START',
      'messageId': _messageId,
      'role': 'assistant',
    });
  }

  void _streamFailed(Object error) {
    if (client.readingSuccessfulResponse &&
        (error is TypeError ||
            error is FormatException ||
            error is FirebaseAISdkException)) {
      _fail(
        FirebaseFailure(
          FirebaseErrorCode.invalidResponse,
          'Firebase returned a malformed response.',
        ),
      );
      return;
    }
    _fail(error);
  }

  void _fail(Object error) {
    if (_ended) return;
    final failure = switch (error) {
      final FirebaseFailure failure => failure,
      TimeoutException(:final message) => FirebaseFailure(
        FirebaseErrorCode.timedOut,
        message ?? 'Firebase stopped responding.',
      ),
      // The SDK refuses a setting for its backend only when it builds the
      // request, such as `SafetySetting.method` with the Gemini Developer API.
      ArgumentError(:final message) => FirebaseFailure(
        FirebaseErrorCode.invalidInput,
        '$message',
      ),
      // Not every exception of the SDK prints its message.
      FirebaseAIException(:final message) => FirebaseFailure(
        FirebaseErrorCode.generationFailed,
        message,
      ),
      _ => FirebaseFailure(
        FirebaseErrorCode.generationFailed,
        error.toString(),
      ),
    };
    _end({
      ..._event('RUN_ERROR'),
      'code': failure.code,
      'message': failure.message,
    });
  }

  void stop() {
    if (_ended) return;
    _end({
      ..._event('RUN_FINISHED'),
      'outcome': {'type': 'cancelled'},
    });
  }

  void _end(JsonObject terminal) {
    _ended = true;
    _controller.add(terminal);
    _cleanup();
    unawaited(_controller.close());
  }

  void _dispose() {
    _ended = true;
    _cleanup();
  }

  void _cleanup() {
    if (_cleaned) return;
    _cleaned = true;
    _tokenTimeout?.cancel();
    client.close();
    onDone(this);
    // SDK cancellation may wait for an App Check token that cannot be cancelled.
    unawaited(
      _subscription?.cancel().then<void>(
        (_) {},
        onError: (Object _, StackTrace _) {},
      ),
    );
  }

  JsonObject _event(String type) => {
    'type': type,
    'threadId': input['threadId'],
    'runId': input['runId'],
  };
}
