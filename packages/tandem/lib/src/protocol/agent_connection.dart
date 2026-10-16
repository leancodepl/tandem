import 'dart:async';
import 'dart:convert';

import 'package:http/http.dart' as http;
import 'package:tandem/src/errors.dart';
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

/// The link to the agent: one AG-UI run per call.
abstract interface class AgentConnection() {
  /// For the classes that implement a connection.
  this;

  /// Posts [input], the body of one AG-UI run, and streams the events of the
  /// run as decoded JSON.
  ///
  /// The stream ends after `RUN_FINISHED` or `RUN_ERROR`. A stream that ends
  /// earlier, or fails, means the run broke. Cancelling the subscription
  /// closes the connection: do it only when the screen goes away.
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
  Stream<Map<String, Object?>> run(Map<String, Object?> input) async* {
    final used = client ?? http.Client();
    try {
      final request = http.Request('POST', endpoint)
        ..headers.addAll(_headers)
        // Bytes, not `body`, which would add a charset to the content type.
        ..bodyBytes = utf8.encode(jsonEncode(input));
      final response = await used.send(request).timeout(_idleTimeout);
      if (response.statusCode != _statusOk) {
        throw AgentHttpException(
          response.statusCode,
          await response.stream.bytesToString().timeout(_idleTimeout),
        );
      }
      // `yield*` and `map`, not `await for` and `yield`: the latter delays a
      // cancel until the next event arrives.
      yield* parseSse(
        response.stream.timeout(_idleTimeout, onTimeout: _endWithTimeout),
      ).map((event) => jsonDecode(event) as Map<String, Object?>);
    } finally {
      if (client == null) {
        used.close();
      }
    }
  }
}
