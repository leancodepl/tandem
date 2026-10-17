import 'dart:async';
import 'dart:convert';

import 'package:http/http.dart' as http;
import 'package:tandem/src/errors.dart';
import 'package:tandem/src/protocol/chunk_events.dart';
import 'package:tandem/src/protocol/sse.dart';

const _headers = {
  'Accept': 'text/event-stream',
  'Content-Type': 'application/json',
};
const _statusOk = 200;

// ADK sends a `: ping` comment every 15 s. parseSse drops it, so the timeout
// watches the raw bytes: 60 s without any, or without the response headers,
// means the connection is dead.
const _idleTimeout = Duration(seconds: 60);

// Without `onTimeout`, `timeout` only adds the error and keeps the dead
// connection open: this one ends the stream, which cancels the connection.
void _endWithTimeout(EventSink<List<int>> sink) {
  sink
    ..addError(TimeoutException('No bytes from the agent', _idleTimeout))
    ..close();
}

// Unlike `takeWhile`, delivers the event that ends the run. Closing the sink
// cancels the response, which closes the connection if the server keeps it.
void _endAfterRun(
  Map<String, Object?> event,
  EventSink<Map<String, Object?>> sink,
) {
  sink.add(event);
  if (event['type'] case 'RUN_FINISHED' || 'RUN_ERROR') {
    sink.close();
  }
}

/// The link to the agent: one AG-UI run per call.
abstract interface class AgentConnection() {
  /// For the classes that implement a connection.
  this;

  /// Posts [input], the body of one AG-UI run, and streams the events of the
  /// run as decoded JSON. A chunk event, `TEXT_MESSAGE_CHUNK` or
  /// `TOOL_CALL_CHUNK`, comes as the content, start and args events it
  /// abbreviates.
  ///
  /// The stream ends right after `RUN_FINISHED` or `RUN_ERROR`, and the
  /// connection closes with it. A stream that ends earlier, or fails, means
  /// the run broke. Cancelling the subscription aborts the request, even when
  /// it still waits for the response headers: do it only when the screen goes
  /// away.
  /// Stopping a run must not cancel it, because ADK keeps running and the
  /// thread stays consistent only if its events are read to the end.
  Stream<Map<String, Object?>> run(Map<String, Object?> input);
}

/// An [AgentConnection] to an AG-UI endpoint over `package:http`.
final class HttpAgentConnection(final Uri endpoint, {final http.Client? client})
    implements AgentConnection {
  /// Posts the runs to [endpoint]. With a [client], the runs use it and never
  /// close it. Without one, each run opens its own and closes it at the end.
  this;

  @override
  Stream<Map<String, Object?>> run(Map<String, Object?> input) {
    final abortTrigger = Completer<void>();
    late final StreamSubscription<Map<String, Object?>> subscription;
    late final StreamController<Map<String, Object?>> controller;
    // A cancelled `async*` stream ends only at its next `yield`, so it cannot
    // abort a request that waits for its headers: the controller can.
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
        unawaited(subscription.cancel());
      },
    );
    return controller.stream;
  }

  Stream<Map<String, Object?>> _events(
    Map<String, Object?> input,
    Future<void> abortTrigger,
  ) async* {
    final httpClient = client ?? http.Client();
    try {
      final request =
          http.AbortableRequest('POST', endpoint, abortTrigger: abortTrigger)
            ..headers.addAll(_headers)
            // Bytes, not `body`, which would add a charset to the content type.
            ..bodyBytes = utf8.encode(jsonEncode(input));
      final response = await httpClient.send(request).timeout(_idleTimeout);
      if (response.statusCode != _statusOk) {
        throw AgentHttpException(
          response.statusCode,
          await response.stream.bytesToString().timeout(_idleTimeout),
        );
      }
      // `yield*` and transformers, not `await for` and `yield`: the latter
      // delays a cancel until the next event arrives.
      yield* parseSse(
            response.stream.timeout(_idleTimeout, onTimeout: _endWithTimeout),
          )
          .map((event) => jsonDecode(event) as Map<String, Object?>)
          .expand(ChunkExpander().call)
          .transform(StreamTransformer.fromHandlers(handleData: _endAfterRun));
    } on http.RequestAbortedException {
      // The caller cancelled the run: nobody is left to hear of it.
    } finally {
      if (client == null) {
        httpClient.close();
      }
    }
  }
}
