import 'dart:async';
import 'dart:convert';

import 'package:http/http.dart' as http;
import 'package:tandem/src/errors.dart';
import 'package:tandem/src/protocol/ag_ui.dart';
import 'package:tandem/src/protocol/chunk_events.dart';
import 'package:tandem/src/protocol/sse.dart';

/// One AG-UI run per call, over a transport or a fake agent.
// The experimental lint asks for a primary constructor on an interface too.
// ignore: use_primary_constructors
abstract interface class AgentConnection {
  /// Starts a run with [input] and streams it as decoded JSON.
  ///
  /// Skips replayed runs, expands text and tool-call chunks, and closes after
  /// `RUN_FINISHED` or `RUN_ERROR`. An ambiguous chunk fails with a
  /// [FormatException]. An earlier end or stream error means the run broke.
  /// Cancelling aborts even pending response headers and waits for cleanup.
  /// Drain a stopped run to keep the agent's thread consistent.
  Stream<JsonObject> run(JsonObject input);
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
  static const _idleTimeout = Duration(seconds: 60);

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
      final response = await httpClient.send(request).timeout(_idleTimeout);
      if (response.statusCode != 200) {
        final body = await response.stream.bytesToString().timeout(
          _idleTimeout,
        );
        throw AgentHttpException(response.statusCode, body);
      }

      // Count raw bytes so ADK's ping comments reset the timeout.
      final bytes = response.stream.timeout(
        _idleTimeout,
        onTimeout: _endWithTimeout,
      );
      // Delegation keeps cancellation responsive while waiting for events.
      yield* parseSse(bytes)
          .map((event) => jsonDecode(event) as JsonObject)
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

  // Closing the sink cancels the silent connection; an error alone does not.
  static void _endWithTimeout(EventSink<List<int>> sink) {
    sink
      ..addError(TimeoutException('No bytes from the agent', _idleTimeout))
      ..close();
  }
}

// Closing the sink cancels a response the server may leave open.
StreamTransformer<JsonObject, JsonObject> _requestedRun(JsonObject input) {
  var acceptingEvents = input[AgUiFields.runId] is! String;
  var awaitingRunStart = true;

  return StreamTransformer.fromHandlers(
    handleData: (event, sink) {
      if (event[AgUiFields.type] == AgUiEventTypes.runStarted) {
        awaitingRunStart = false;
        acceptingEvents = _isRequestedRun(event, input: input);
      }

      final isOpeningError =
          awaitingRunStart && _isRunErrorFor(event, input: input);
      if (acceptingEvents || isOpeningError) {
        sink.add(event);
        if (event[AgUiFields.type]
            case AgUiEventTypes.runFinished || AgUiEventTypes.runError) {
          sink.close();
        }
      }
    },
  );
}

bool _isRequestedRun(JsonObject event, {required JsonObject input}) {
  if (input[AgUiFields.runId] is! String) {
    return true;
  }

  return event[AgUiFields.runId] == input[AgUiFields.runId] &&
      event[AgUiFields.threadId] == input[AgUiFields.threadId];
}

bool _isRunErrorFor(JsonObject event, {required JsonObject input}) {
  if (event[AgUiFields.type] != AgUiEventTypes.runError) {
    return false;
  }
  if (event.containsKey(AgUiFields.runId) &&
      event[AgUiFields.runId] != input[AgUiFields.runId]) {
    return false;
  }
  if (event.containsKey(AgUiFields.threadId) &&
      event[AgUiFields.threadId] != input[AgUiFields.threadId]) {
    return false;
  }

  return true;
}
