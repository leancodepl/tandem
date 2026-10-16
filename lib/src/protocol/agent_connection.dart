import 'dart:async';

import 'package:http/http.dart' as http;
import 'package:tandem/src/protocol/http/http_sse_connection.dart';
import 'package:tandem/src/protocol/wire/events.dart';
import 'package:tandem/src/protocol/wire/run_input.dart';

/// The way to the agent backend: runs one run and streams its events.
///
/// A session talks to its agent only through this interface. Adapters:
/// [AgentConnection.http] for a real AG-UI backend and `ScriptedAgent` from
/// `package:tandem/testing.dart` for tests. Another AG-UI Dart package would
/// be one more adapter that sends `input.toJson()` and decodes every event
/// with [WireEvent.fromJson].
///
/// One connection usually serves the whole app, because one agent backend
/// serves every agent-aware screen; each session still has its own thread.
/// With `tandem_bloc`, provide it with `RepositoryProvider<AgentConnection>`.
abstract interface class AgentConnection {
  /// Connects to an AG-UI endpoint: an HTTP POST of the run input, with the
  /// response read as Server-Sent Events.
  ///
  /// [headers] is called once per run, so it can return a fresh auth token;
  /// what it returns is added to (and may override) the default
  /// `content-type` and `accept` headers. The run fails with a connection
  /// error when the status is not 2xx (the status and body are in the
  /// error), when a 2xx answer is not `text/event-stream` (usually a wrong
  /// URL), when nothing, keep-alive comments included, arrives for
  /// [idleTimeout] (default 60 seconds; ag-ui-adk sends a keep-alive every
  /// 15 seconds), or when [headers] does not complete within [idleTimeout]. Every run uses a new client from [newClient] (default
  /// `http.Client.new`), which is closed when the run ends or is stopped.
  factory AgentConnection.http(
    Uri endpoint, {
    FutureOr<Map<String, String>> Function()? headers,
    Duration idleTimeout,
    http.Client Function()? newClient,
  }) = HttpSseConnection;

  /// Starts one run for [input] and streams its events.
  ///
  /// The contract every adapter keeps:
  /// - Nothing happens until the stream is listened to, and it is listened
  ///   to once.
  /// - Cancelling the subscription aborts the run.
  /// - The stream ends after `RUN_FINISHED` or `RUN_ERROR`, or earlier when
  ///   the backend closes it; the session treats an early end as finished.
  /// - A transport failure is a stream error; its `toString()` is what the
  ///   user's error shows. A `RUN_ERROR` event is the agent's own failure and
  ///   is an event, not an error.
  /// - An event of an unknown type is an [UnknownEvent] value, never an
  ///   error.
  Stream<WireEvent> run(RunInput input);
}
