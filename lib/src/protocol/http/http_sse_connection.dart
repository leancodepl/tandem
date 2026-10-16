import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';

import 'package:http/http.dart' as http;
import 'package:tandem/src/protocol/agent_connection.dart';
import 'package:tandem/src/protocol/wire/events.dart';
import 'package:tandem/src/protocol/wire/run_input.dart';

/// The HTTP and Server-Sent Events adapter behind [AgentConnection.http].
///
/// Each run is one `POST` of `RunInput.toJson()` to [endpoint] with
/// `content-type: application/json` and `accept: text/event-stream`. The
/// response is read as Server-Sent Events: every `data:` frame is one AG-UI
/// event. Frames may end lines with LF, CRLF or CR, may span several `data:`
/// lines and may arrive split anywhere; comment frames (ag-ui-adk's
/// `: ping`) only keep the run alive.
///
/// A run fails with a stream error when:
/// - the headers callback, the client or the request fails;
/// - the status is not 2xx (the status and body are in the message);
/// - a 2xx response says it is not `text/event-stream`, which usually means
///   the endpoint is not an AG-UI agent (for example a web server answering
///   every path with its index page);
/// - nothing at all arrives for [idleTimeout], response headers included;
/// - the headers callback does not complete within [idleTimeout].
///
/// The stream ends after `RUN_FINISHED` or `RUN_ERROR`, even when the server
/// keeps the connection open, or when the server closes the response. Data
/// that is not a JSON object becomes an [UnknownEvent] with a problem.
final class HttpSseConnection implements AgentConnection {
  /// See [AgentConnection.http].
  HttpSseConnection(
    this.endpoint, {
    FutureOr<Map<String, String>> Function()? headers,
    this.idleTimeout = const Duration(seconds: 60),
    http.Client Function()? newClient,
  }) : _headers = headers,
       _newClient = newClient ?? http.Client.new;

  /// Where runs are POSTed.
  final Uri endpoint;

  /// How long the stream may stay silent before the run fails.
  final Duration idleTimeout;

  final FutureOr<Map<String, String>> Function()? _headers;
  final http.Client Function() _newClient;

  @override
  Stream<WireEvent> run(RunInput input) => _SseRun(this, input).events;
}

/// Why a run over HTTP failed on the transport level.
///
/// Its [toString] is the [message], which the session shows as the error of
/// the run.
final class AgentHttpException implements Exception {
  /// Creates the exception.
  const AgentHttpException(this.message, {this.statusCode, this.body});

  /// What went wrong, in words a developer can act on.
  final String message;

  /// The HTTP status, when the backend answered.
  final int? statusCode;

  /// The response body, when the backend answered with something other
  /// than an event stream.
  final String? body;

  @override
  String toString() => message;
}

/// The state of one run: request, response, idle timer and SSE decoding.
final class _SseRun {
  _SseRun(this._connection, this._input);

  /// The most of an error body that is kept and put in the message.
  static const _maxErrorBody = 64 * 1024;
  static const _maxErrorBodyInMessage = 1000;

  final HttpSseConnection _connection;
  final RunInput _input;
  final _abort = Completer<void>();
  late final _events = StreamController<WireEvent>(
    onListen: _start,
    onCancel: _cancel,
  );

  http.Client? _client;
  StreamSubscription<List<int>>? _body;
  Timer? _idleTimer;
  bool _isDone = false;

  Stream<WireEvent> get events => _events.stream;

  void _start() => unawaited(_open());

  Future<void> _open() async {
    try {
      // A callback that hangs, such as a token refresh without network,
      // must not keep the run open forever.
      _restartIdleTimer(isWaitingForHeaders: true);
      final headers = await _connection._headers?.call() ?? const {};
      if (_isDone) {
        return;
      }
      final client = _client = _connection._newClient();
      final request =
          http.AbortableRequest(
              'POST',
              _connection.endpoint,
              abortTrigger: _abort.future,
            )
            ..headers['content-type'] = 'application/json'
            ..headers['accept'] = 'text/event-stream'
            ..headers.addAll(headers)
            ..body = jsonEncode(_input.toJson());
      _restartIdleTimer();
      final response = await client.send(request);
      if (_isDone) {
        unawaited(response.stream.listen(null).cancel());
        return;
      }
      _restartIdleTimer();
      final contentType = response.headers['content-type'];
      if (response.statusCode < 200 || response.statusCode >= 300) {
        _readErrorBody(response, (body) => _httpError(response, body));
      } else if (contentType != null && !_isEventStream(contentType)) {
        _readErrorBody(
          response,
          (body) => _notEventStream(response, contentType, body),
        );
      } else {
        _readEvents(response);
      }
    } catch (err, st) {
      _fail(err, st);
    }
  }

  void _readEvents(http.StreamedResponse response) {
    final frames = _SseFrames(_onData);
    final lines = const LineSplitter().startChunkedConversion(frames);
    final bytes = const Utf8Decoder(
      allowMalformed: true,
    ).startChunkedConversion(lines);
    _body = response.stream.listen(
      (chunk) {
        _restartIdleTimer();
        bytes.add(chunk);
      },
      onError: _fail,
      onDone: () {
        bytes.close();
        _finish();
      },
    );
  }

  void _readErrorBody(
    http.StreamedResponse response,
    AgentHttpException Function(String body) error,
  ) {
    final body = BytesBuilder(copy: false);
    void complete() => _fail(
      error(utf8.decode(body.takeBytes(), allowMalformed: true).trim()),
      StackTrace.current,
    );

    _body = response.stream.listen(
      (chunk) {
        _restartIdleTimer();
        body.add(chunk);
        if (body.length >= _maxErrorBody) {
          complete();
        }
      },
      onError: _fail,
      onDone: complete,
    );
  }

  /// One complete `data` of a frame. A frame with empty data carries no
  /// event and is skipped.
  void _onData(String data) {
    if (_isDone || data.trim().isEmpty) {
      return;
    }
    final event = _decode(data);
    _events.add(event);
    if (event is RunFinished || event is RunError) {
      _finish();
    }
  }

  void _restartIdleTimer({bool isWaitingForHeaders = false}) {
    _idleTimer?.cancel();
    _idleTimer = Timer(_connection.idleTimeout, () {
      final duration = _describeDuration(_connection.idleTimeout);
      _fail(
        AgentHttpException(
          isWaitingForHeaders
              ? 'The headers callback did not complete within $duration.'
              : 'The agent backend sent nothing for $duration.',
        ),
        StackTrace.current,
      );
    });
  }

  AgentHttpException _httpError(http.StreamedResponse response, String body) {
    final reason = response.reasonPhrase;
    final status = reason == null || reason.isEmpty
        ? 'HTTP ${response.statusCode}'
        : 'HTTP ${response.statusCode} $reason';
    return AgentHttpException(
      body.isEmpty
          ? 'The agent backend answered with $status.'
          : 'The agent backend answered with $status: ${_excerpt(body)}',
      statusCode: response.statusCode,
      body: body,
    );
  }

  AgentHttpException _notEventStream(
    http.StreamedResponse response,
    String contentType,
    String body,
  ) {
    final description =
        'The agent backend answered with "$contentType" instead of '
        '"text/event-stream" (HTTP ${response.statusCode}). Check that the '
        'endpoint is an AG-UI agent.';
    return AgentHttpException(
      body.isEmpty ? description : '$description ${_excerpt(body)}',
      statusCode: response.statusCode,
      body: body,
    );
  }

  /// Reports [error] and ends the run, unless it has already ended.
  void _fail(Object error, StackTrace stackTrace) {
    if (_isDone) {
      return;
    }
    _events.addError(error, stackTrace);
    _finish();
  }

  /// Ends the run and releases the connection, unless it has already ended.
  void _finish() {
    if (_isDone) {
      return;
    }
    unawaited(_release());
    unawaited(_events.close());
  }

  Future<void> _cancel() async {
    if (_isDone) {
      return;
    }
    await _release();
  }

  Future<void> _release() async {
    _isDone = true;
    _idleTimer?.cancel();
    if (!_abort.isCompleted) {
      _abort.complete();
    }
    final cancelling = _body?.cancel();
    _client?.close();
    await cancelling;
  }

  String _excerpt(String text) => text.length <= _maxErrorBodyInMessage
      ? text
      : '${text.substring(0, _maxErrorBodyInMessage)}…';
}

/// Turns SSE lines into the `data` of each complete frame, following the
/// WHATWG event stream rules for the fields AG-UI uses.
///
/// `event`, `id` and `retry` fields and comment lines are ignored. A frame
/// that is still open when the stream ends is delivered too, so a backend
/// that omits the last blank line loses nothing.
final class _SseFrames implements Sink<String> {
  _SseFrames(this._onData);

  final void Function(String data) _onData;
  final _data = StringBuffer();
  bool _hasData = false;
  bool _isFirstLine = true;

  @override
  void add(String line) {
    var text = line;
    if (_isFirstLine) {
      _isFirstLine = false;
      if (text.startsWith('﻿')) {
        text = text.substring(1);
      }
    }
    if (text.isEmpty) {
      _dispatch();
      return;
    }
    if (text.startsWith(':')) {
      return;
    }
    final colon = text.indexOf(':');
    final field = colon < 0 ? text : text.substring(0, colon);
    if (field != 'data') {
      return;
    }
    var value = colon < 0 ? '' : text.substring(colon + 1);
    if (value.startsWith(' ')) {
      value = value.substring(1);
    }
    if (_hasData) {
      _data.write('\n');
    }
    _data.write(value);
    _hasData = true;
  }

  @override
  void close() => _dispatch();

  void _dispatch() {
    if (!_hasData) {
      return;
    }
    final data = _data.toString();
    _data.clear();
    _hasData = false;
    _onData(data);
  }
}

/// Decodes the `data` of one frame; never throws.
WireEvent _decode(String data) {
  final Object? json;
  try {
    json = jsonDecode(data);
  } on FormatException catch (err) {
    return UnknownEvent(
      const {},
      problem: 'The SSE data is not JSON (${err.message}): ${_short(data)}',
    );
  }
  return switch (json) {
    final Map<String, Object?> object => WireEvent.fromJson(object),
    _ => UnknownEvent(
      const {},
      problem: 'The SSE data is not a JSON object: ${_short(data)}',
    ),
  };
}

/// Whether a `content-type` header value names `text/event-stream`.
bool _isEventStream(String contentType) =>
    contentType.split(';').first.trim().toLowerCase() == 'text/event-stream';

String _describeDuration(Duration duration) {
  if (duration.inMilliseconds % 1000 != 0) {
    return '${duration.inMilliseconds} ms';
  }
  final seconds = duration.inSeconds;
  return seconds == 1 ? '1 second' : '$seconds seconds';
}

String _short(String text) =>
    text.length <= 200 ? text : '${text.substring(0, 200)}…';
