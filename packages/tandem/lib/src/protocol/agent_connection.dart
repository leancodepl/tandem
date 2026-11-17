import 'dart:async';
import 'dart:convert';

import 'package:http/http.dart' as http;
import 'package:tandem/src/errors.dart';
import 'package:tandem/src/protocol/ag_ui.dart';
import 'package:tandem/src/protocol/ag_ui_run.dart';
import 'package:tandem/src/protocol/sse.dart';

/// One AG-UI run per call, over a transport or a fake agent.
// The experimental lint asks for a primary constructor on an interface too.
// ignore: use_primary_constructors
abstract interface class AgentConnection {
  /// Starts a run with [input] and streams its events as decoded JSON. The
  /// stream closes after `RUN_FINISHED` or `RUN_ERROR`. An earlier end or
  /// stream error means the run broke.
  ///
  /// A connection to an AG-UI server passes [agUiRun] with [input] only the
  /// decoded frames of this run's request. Cancelling the stream ends the
  /// request, even before the response arrives, and waits for its cleanup.
  /// The session does not cancel a stopped run: it reads it to the end, to
  /// keep the agent's thread consistent.
  Stream<JsonObject> run(JsonObject input);
}

/// An [AgentConnection] whose transport can tell the server to stop a run,
/// such as with the cancel message of a WebSocket protocol.
///
/// When the user stops a run that still streams, the session calls [stop]
/// once and goes on reading the run. The server must still end the run on
/// that stream, with `RUN_FINISHED` and the outcome `cancelled` or with
/// `RUN_ERROR`. Both end a stopped run quietly, and the session still reports
/// the code and message of a `RUN_ERROR`. If [stop] throws, a `RUN_ERROR`
/// fails the run. A stream that ends without either counts as a lost
/// connection, so a transport that can only close should not implement this.
/// Dispose does not call [stop]: it cancels the run's stream.
// ignore: use_primary_constructors
abstract interface class StoppableAgentConnection implements AgentConnection {
  /// Tells the server to stop the run that [run] started with [input], the
  /// same object. The cancel message names that run. Return without an error
  /// also when the server ended the run already or has not seen it yet. The
  /// session does not wait for it, and reports its error.
  Future<void> stop(JsonObject input);
}

/// Talks to an AG-UI endpoint over HTTP and reads the run's events as
/// server-sent events. Give it a [client] that adds headers, such as the
/// user's token.
final class HttpAgentConnection(
  final Uri endpoint, {

  /// Every run uses it and none closes it. Without one, each run opens its
  /// own and closes it at the end.
  final http.Client? client,

  /// How long a run waits for the response headers or the next bytes, SSE
  /// comments included, before it counts as broken.
  final Duration idleTimeout = const Duration(seconds: 60),
}) implements AgentConnection {
  @override
  Stream<JsonObject> run(JsonObject input) {
    final abortTrigger = Completer<void>();
    late final StreamSubscription<JsonObject> subscription;
    late final StreamController<JsonObject> controller;
    // A controller can abort pending headers before async* reaches a yield.
    controller = StreamController(
      onListen: () {
        subscription = _events(input, abortTrigger.future).listen(
          controller.add,
          onError: controller.addError,
          onDone: controller.close,
        );
      },
      onCancel: () {
        abortTrigger.complete();
        return subscription.cancel();
      },
    );
    return controller.stream;
  }

  Stream<JsonObject> _events(
    JsonObject input,
    Future<void> abortTrigger,
  ) async* {
    final httpClient = client ?? http.Client();
    try {
      final request = _request(input, abortTrigger: abortTrigger);
      final response = await httpClient.send(request).timeout(idleTimeout);
      if (response.statusCode != 200) {
        final body = await response.stream.bytesToString().timeout(idleTimeout);
        throw AgentHttpException(response.statusCode, body);
      }

      // Count raw bytes so ADK's ping comments reset the timeout.
      final bytes = response.stream.timeout(
        idleTimeout,
        onTimeout: _endWithTimeout,
      );
      // Delegation keeps cancellation responsive while waiting for events.
      yield* parseSse(bytes).map(_decodeEvent).transform(agUiRun(input));
    } on http.RequestAbortedException {
      // The caller cancelled the run: nobody is left to hear of it.
    } finally {
      if (client == null) {
        httpClient.close();
      }
    }
  }

  http.AbortableRequest _request(
    JsonObject input, {
    required Future<void> abortTrigger,
  }) => http.AbortableRequest('POST', endpoint, abortTrigger: abortTrigger)
    ..headers.addAll({
      'Accept': 'text/event-stream',
      'Content-Type': 'application/json',
    })
    // Bytes, not `body`, which would add a charset to the content type.
    ..bodyBytes = utf8.encode(jsonEncode(input));

  static JsonObject _decodeEvent(String data) =>
      decodeJsonObject(data) ??
      (throw FormatException('An AG-UI event is a JSON object', data));

  // Closing the sink cancels the silent connection; an error alone does not.
  void _endWithTimeout(EventSink<List<int>> sink) {
    sink
      ..addError(TimeoutException('No bytes from the agent', idleTimeout))
      ..close();
  }
}
