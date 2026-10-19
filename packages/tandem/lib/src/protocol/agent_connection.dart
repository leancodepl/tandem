import 'dart:async';
import 'dart:convert';

import 'package:http/http.dart' as http;
import 'package:tandem/src/errors.dart';
import 'package:tandem/src/protocol/chunk_events.dart';
import 'package:tandem/src/protocol/sse.dart';

// ADK sends a `: ping` comment every 15 s. parseSse drops it, so the timeout
// watches the raw bytes: 60 s without any, or without the response headers,
// means the connection is dead.
const _idleTimeout = Duration(seconds: 60);

// Without `onTimeout`, `timeout` only adds the error and keeps the dead
// connection open. Ending the stream cancels it.
void _endWithTimeout(EventSink<List<int>> sink) {
  sink
    ..addError(TimeoutException('No bytes from the agent', _idleTimeout))
    ..close();
}

// A response may replay older runs before the requested one. Closing the
// sink after the run's end cancels the response, which closes the
// connection if the server keeps it.
StreamTransformer<Map<String, Object?>, Map<String, Object?>> _requestedRun(
  Map<String, Object?> input,
) {
  var active = input['runId'] is! String;
  var started = false;

  return StreamTransformer.fromHandlers(
    handleData: (event, sink) {
      if (event['type'] == 'RUN_STARTED') {
        started = true;
        active =
            input['runId'] is! String ||
            (event['runId'] == input['runId'] &&
                event['threadId'] == input['threadId']);
      }
      if (active ||
          (!started &&
              event['type'] == 'RUN_ERROR' &&
              (!event.containsKey('runId') ||
                  event['runId'] == input['runId']) &&
              (!event.containsKey('threadId') ||
                  event['threadId'] == input['threadId']))) {
        sink.add(event);
        if (event['type'] case 'RUN_FINISHED' || 'RUN_ERROR') {
          sink.close();
        }
      }
    },
  );
}

/// The link to the agent: one AG-UI run per call. Implement it for another
/// transport or a fake agent.
// The experimental lint asks for a primary constructor on an interface too.
// ignore: use_primary_constructors
abstract interface class AgentConnection {
  /// Posts [input], the body of one AG-UI run, and streams the events of the
  /// run as decoded JSON.
  ///
  /// `TEXT_MESSAGE_CHUNK` and `TOOL_CALL_CHUNK` come as the content, start
  /// and args events they abbreviate, each sender, parent or subagent,
  /// continuing its own open message or call. A chunk without an id that
  /// several subagents could own fails the stream with a [FormatException].
  ///
  /// Replayed runs before the requested `runId` and `threadId` are skipped.
  /// The stream ends right after its `RUN_FINISHED` or `RUN_ERROR`, and the
  /// connection closes with it. A stream that ends earlier, or fails, means
  /// the run broke. Cancelling the subscription aborts the request, even
  /// while it waits for the response headers, and its future completes once
  /// the connection is cleaned up.
  ///
  /// The session cancels only when it is disposed, when the stream fails, or
  /// when an event fails the run.
  /// Stopping a run does not cancel it: ADK keeps running, and the thread
  /// stays consistent only if the run's events are read to the end.
  Stream<Map<String, Object?>> run(Map<String, Object?> input);
}

/// Talks to an AG-UI endpoint over HTTP and reads the run's events as
/// server-sent events. Give it a [client] that adds headers, such as the
/// user's token.
final class HttpAgentConnection(
  final Uri endpoint, {

  /// Every run uses it and none closes it. Without one, each run opens its
  /// own and closes it at the end.
  final http.Client? client,
}) implements AgentConnection {
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
        return subscription.cancel();
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
            ..headers.addAll({
              'Accept': 'text/event-stream',
              'Content-Type': 'application/json',
            })
            // Bytes, not `body`, which would add a charset to the content type.
            ..bodyBytes = utf8.encode(jsonEncode(input));
      final response = await httpClient.send(request).timeout(_idleTimeout);
      if (response.statusCode != 200) {
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
          .transform(_requestedRun(input))
          .expand(ChunkExpander().call);
    } on http.RequestAbortedException {
      // The caller cancelled the run: nobody is left to hear of it.
    } finally {
      if (client == null) {
        httpClient.close();
      }
    }
  }
}
