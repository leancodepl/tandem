import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:tandem/protocol.dart';
import 'package:tandem/tandem.dart';

import '../fixtures/ag_ui_adk.dart';

const _input = RunInput(
  threadId: 'thread-1',
  runId: 'run-1',
  messages: [WireUserMessage('u1', 'Order 40 HDMI cables')],
  tools: [],
  state: {
    'order': {'notes': 'Zażółć'},
  },
);

const _runStarted =
    'data: {"type":"RUN_STARTED","threadId":"thread-1","runId":"run-1"}\n\n';
const _runFinished =
    'data: {"type":"RUN_FINISHED","threadId":"thread-1","runId":"run-1"}\n\n';

void main() {
  group('AgentConnection.http', () {
    test('POSTs the run input as JSON and asks for an event stream', () async {
      final backend = await _Backend.start(_respond(_runFinished));
      addTearDown(backend.close);

      await AgentConnection.http(backend.endpoint).run(_input).drain<void>();

      final request = backend.requests.single;
      expect(request.method, 'POST');
      expect(request.path, '/agent');
      expect(request.headers.contentType?.mimeType, 'application/json');
      expect(request.headers.value('accept'), 'text/event-stream');
      expect(jsonDecode(request.body), _input.toJson());
    });

    test('streams every event of a real ag-ui-adk run', () async {
      final transcript = utf8.decode(AgUiAdkTranscripts.bytes('A1'));
      final backend = await _Backend.start(
        _respond(transcript, contentType: 'text/event-stream; charset=utf-8'),
      );
      addTearDown(backend.close);

      final events = await AgentConnection.http(
        backend.endpoint,
      ).run(_input).toList();

      expect(
        events.map((event) => event.json),
        AgUiAdkTranscripts.frames('A1'),
      );
      expect(events.first, isA<RunStarted>());
      expect(events.last, isA<RunFinished>());
    });

    test('decodes frames split mid-line and inside a character', () async {
      const text =
          'data: {"type":"TEXT_MESSAGE_CONTENT","messageId":"m1",'
          '"delta":"Zażółć"}\n\n';
      final frame = utf8.encode(text);
      // Between the two bytes of "ż" in UTF-8.
      final inside =
          utf8.encode(text.substring(0, text.indexOf('ż'))).length + 1;
      final backend = await _Backend.start((exchange) async {
        final socket = await exchange.eventStream();
        await _send(socket, utf8.encode(_runStarted.substring(0, 9)));
        await _send(socket, utf8.encode(_runStarted.substring(9)));
        await _send(socket, frame.sublist(0, 4));
        await _send(socket, frame.sublist(4, inside));
        await _send(socket, frame.sublist(inside, frame.length - 1));
        await _send(socket, frame.sublist(frame.length - 1));
        await _send(socket, utf8.encode(_runFinished));
      });
      addTearDown(backend.close);

      final events = await AgentConnection.http(
        backend.endpoint,
      ).run(_input).toList();

      expect(events, [
        isA<RunStarted>(),
        isA<TextContent>().having((e) => e.delta, 'delta', 'Zażółć'),
        isA<RunFinished>(),
      ]);
    });

    test('skips CRLF keep-alive comments, which keep the run alive', () async {
      // slow.sse is a real ag-ui-adk run with its ": ping - ...\r\n\r\n".
      final transcript = utf8.decode(AgUiAdkTranscripts.bytes('slow'));
      final ping = RegExp(r': ping[^\r]*\r\n\r\n').firstMatch(transcript)!;
      final backend = await _Backend.start((exchange) async {
        final socket = await exchange.eventStream();
        await _send(socket, utf8.encode(transcript.substring(0, ping.start)));
        for (var i = 0; i < 4; i++) {
          await Future<void>.delayed(const Duration(milliseconds: 150));
          await _send(socket, utf8.encode(ping[0]!));
        }
        await _send(socket, utf8.encode(transcript.substring(ping.end)));
      });
      addTearDown(backend.close);

      final events = await AgentConnection.http(
        backend.endpoint,
        idleTimeout: const Duration(milliseconds: 500),
      ).run(_input).toList();

      expect(
        events.map((event) => event.json),
        AgUiAdkTranscripts.frames('slow'),
      );
    });

    test('ends after RUN_FINISHED although the server keeps the connection '
        'open', () async {
      final closed = Completer<void>();
      final backend = await _Backend.start((exchange) async {
        final socket = await exchange.eventStream();
        _onClosedByPeer(socket, closed);
        await _send(socket, utf8.encode(_runStarted + _runFinished));
      });
      addTearDown(backend.close);

      final events = await AgentConnection.http(
        backend.endpoint,
      ).run(_input).toList();

      expect(events, [isA<RunStarted>(), isA<RunFinished>()]);
      await closed.future.timeout(const Duration(seconds: 5));
    });

    test('ends after RUN_ERROR, also without RUN_STARTED', () async {
      final backend = await _Backend.start(
        _respond(utf8.decode(AgUiAdkTranscripts.bytes('G3'))),
      );
      addTearDown(backend.close);

      final events = await AgentConnection.http(
        backend.endpoint,
      ).run(_input).toList();

      expect(events, [
        isA<RunError>().having((e) => e.code, 'code', 'UNKNOWN_INTERRUPT'),
      ]);
    });

    test('fails with the status and body when the answer is not 2xx', () async {
      final backend = await _Backend.start(
        _respond(
          '{"detail":"missing threadId"}',
          status: 422,
          contentType: 'application/json',
        ),
      );
      addTearDown(backend.close);

      await expectLater(
        AgentConnection.http(backend.endpoint).run(_input),
        emitsInOrder([
          emitsError(
            _hasMessage(
              allOf(
                contains('HTTP 422'),
                contains('{"detail":"missing threadId"}'),
              ),
            ),
          ),
          emitsDone,
        ]),
      );
    });

    test('fails when a 2xx answer is not an event stream', () async {
      final backend = await _Backend.start(
        _respond(
          '<!doctype html><title>My app</title>',
          contentType: 'text/html',
        ),
      );
      addTearDown(backend.close);

      await expectLater(
        AgentConnection.http(backend.endpoint).run(_input),
        emitsInOrder([
          emitsError(
            _hasMessage(
              allOf(
                contains('text/html'),
                contains('text/event-stream'),
                contains('<!doctype html>'),
              ),
            ),
          ),
          emitsDone,
        ]),
      );
    });

    test('fails when nothing arrives for the idle timeout', () async {
      final backend = await _Backend.start((exchange) async {
        final socket = await exchange.eventStream();
        await _send(socket, utf8.encode(_runStarted));
      });
      addTearDown(backend.close);
      final stopwatch = Stopwatch()..start();

      await expectLater(
        AgentConnection.http(
          backend.endpoint,
          idleTimeout: const Duration(milliseconds: 300),
        ).run(_input),
        emitsInOrder([
          isA<RunStarted>(),
          emitsError(_hasMessage(contains('sent nothing for 300 ms'))),
          emitsDone,
        ]),
      );
      expect(
        stopwatch.elapsed,
        greaterThanOrEqualTo(const Duration(milliseconds: 300)),
      );
    });

    test('fails when the response headers do not arrive in time', () async {
      final backend = await _Backend.start(
        (exchange) => Completer<void>().future,
      );
      addTearDown(backend.close);

      await expectLater(
        AgentConnection.http(
          backend.endpoint,
          idleTimeout: const Duration(seconds: 1),
        ).run(_input),
        emitsInOrder([
          emitsError(_hasMessage(contains('sent nothing for 1 second'))),
          emitsDone,
        ]),
      );
    });

    test('fails when the headers callback does not complete in time', () async {
      final backend = await _Backend.start(_respond(_runFinished));
      addTearDown(backend.close);

      await expectLater(
        AgentConnection.http(
          backend.endpoint,
          headers: () => Completer<Map<String, String>>().future,
          idleTimeout: const Duration(seconds: 1),
        ).run(_input),
        emitsInOrder([
          emitsError(
            _hasMessage(
              equals('The headers callback did not complete within 1 second.'),
            ),
          ),
          emitsDone,
        ]),
      );
      expect(backend.requests, isEmpty);
    });

    test('closes the socket and the client when the subscription is '
        'cancelled', () async {
      final closed = Completer<void>();
      final backend = await _Backend.start((exchange) async {
        final socket = await exchange.eventStream();
        _onClosedByPeer(socket, closed);
        await _send(socket, utf8.encode(_runStarted));
      });
      addTearDown(backend.close);
      final client = _TrackingClient();
      final started = Completer<void>();

      final subscription = AgentConnection.http(
        backend.endpoint,
        newClient: () => client,
      ).run(_input).listen((event) => started.complete());
      await started.future;
      await subscription.cancel();

      expect(client.isClosed, isTrue);
      await closed.future.timeout(const Duration(seconds: 5));
    });

    test('uses a fresh client per run and closes it however the run '
        'ends', () async {
      var answers = 0;
      final backend = await _Backend.start((exchange) async {
        answers++;
        final answer = answers == 2
            ? _respond('nope', status: 500)
            : _respond(_runStarted + _runFinished);
        await answer(exchange);
      });
      addTearDown(backend.close);
      final clients = <_TrackingClient>[];
      final connection = AgentConnection.http(
        backend.endpoint,
        newClient: () {
          final client = _TrackingClient();
          clients.add(client);
          return client;
        },
      );

      await connection.run(_input).drain<void>();
      await connection.run(_input).handleError((Object _) {}).drain<void>();
      await connection.run(_input).take(1).drain<void>();

      expect(clients, hasLength(3));
      expect(clients.map((client) => client.isClosed), everyElement(isTrue));
    });

    test('calls the headers callback once per run', () async {
      final backend = await _Backend.start(_respond(_runFinished));
      addTearDown(backend.close);
      var calls = 0;
      final connection = AgentConnection.http(
        backend.endpoint,
        // Asynchronous, as when it refreshes a token first.
        headers: () =>
            Future.value({'authorization': 'Bearer token-${++calls}'}),
      );

      await connection.run(_input).drain<void>();
      await connection.run(_input).drain<void>();

      expect(calls, 2);
      expect(backend.requests.map((r) => r.headers.value('authorization')), [
        'Bearer token-1',
        'Bearer token-2',
      ]);
    });

    test('does nothing until the stream is listened to', () async {
      final backend = await _Backend.start(_respond(_runFinished));
      addTearDown(backend.close);
      var clients = 0;
      var headerCalls = 0;
      final connection = AgentConnection.http(
        backend.endpoint,
        headers: () => {'x-call': '${++headerCalls}'},
        newClient: () {
          clients++;
          return http.Client();
        },
      );

      final stream = connection.run(_input);
      await Future<void>.delayed(const Duration(milliseconds: 100));

      expect(backend.requests, isEmpty);
      expect(clients, 0);
      expect(headerCalls, 0);

      await stream.drain<void>();
      expect(backend.requests, hasLength(1));
      expect((clients, headerCalls), (1, 1));
    });

    test('can be listened to only once', () async {
      final backend = await _Backend.start(_respond(_runFinished));
      addTearDown(backend.close);
      final stream = AgentConnection.http(backend.endpoint).run(_input);

      final events = stream.toList();

      expect(() => stream.listen(null), throwsStateError);
      expect(await events, [isA<RunFinished>()]);
    });

    test('reports a refused connection as a stream error', () async {
      final unused = await ServerSocket.bind(InternetAddress.loopbackIPv4, 0);
      final port = unused.port;
      await unused.close();

      await expectLater(
        AgentConnection.http(
          Uri.parse('http://127.0.0.1:$port/agent'),
        ).run(_input),
        emitsInOrder([emitsError(isA<http.ClientException>()), emitsDone]),
      );
    });

    test('reports a failing headers callback as a stream error, without '
        'a request', () async {
      final backend = await _Backend.start(_respond(_runFinished));
      addTearDown(backend.close);

      await expectLater(
        AgentConnection.http(
          backend.endpoint,
          headers: () => throw StateError('No token'),
        ).run(_input),
        emitsInOrder([emitsError(isStateError), emitsDone]),
      );
      expect(backend.requests, isEmpty);
    });

    test('reports a connection that breaks mid-stream as a stream '
        'error', () async {
      final backend = await _Backend.start((exchange) async {
        final socket = await exchange.detachSocket();
        final chunk = utf8.encode(_runStarted);
        socket
          ..write(
            'HTTP/1.1 200 OK\r\ncontent-type: text/event-stream\r\n'
            'transfer-encoding: chunked\r\n\r\n',
          )
          ..write('${chunk.length.toRadixString(16)}\r\n')
          ..add(chunk)
          ..write('\r\n');
        await socket.flush();
        await Future<void>.delayed(const Duration(milliseconds: 50));
        socket.destroy();
      });
      addTearDown(backend.close);

      await expectLater(
        AgentConnection.http(backend.endpoint).run(_input),
        emitsInOrder([
          isA<RunStarted>(),
          emitsError(isA<http.ClientException>()),
          emitsDone,
        ]),
      );
    });
  });

  group('AgentConnection.http reading Server-Sent Events', () {
    test('decodes every transcript arriving one byte at a time', () async {
      for (final name in AgUiAdkTranscripts.names) {
        final bytes = AgUiAdkTranscripts.bytes(name);

        final events = await _connectionAnswering([
          for (final byte in bytes) [byte],
        ]).run(_input).toList();

        expect(
          events.map((event) => event.json),
          AgUiAdkTranscripts.frames(name),
          reason: name,
        );
        expect(events.whereType<UnknownEvent>(), isEmpty, reason: name);
      }
    });

    test('reads multi-line data, CR line endings and ignores other '
        'fields', () async {
      final events = await _connectionAnswering([
        utf8.encode(
          '﻿event: message\r'
          'id: 1\r'
          'retry: 1000\r'
          'data: {"type":"RUN_STARTED",\r'
          'data:"threadId":"t",\r'
          'data:  "runId":"r"}\r'
          '\r'
          ': a comment\n'
          '\n'
          'data:\n'
          '\n'
          'data: {"type":"RUN_FINISHED"}\r\n'
          '\r\n',
        ),
      ]).run(_input).toList();

      expect(events, [
        isA<RunStarted>()
            .having((e) => e.threadId, 'threadId', 't')
            .having((e) => e.runId, 'runId', 'r'),
        isA<RunFinished>(),
      ]);
    });

    test('treats a CR at the end of a chunk and an LF at the start of the '
        'next as one line end', () async {
      final events = await _connectionAnswering([
        utf8.encode(
          'data: {"type":"RUN_STARTED","threadId":"t","runId":"r"}\r',
        ),
        utf8.encode('\n\r'),
        utf8.encode('\ndata: {"type":"RUN_FINISHED"}\r\n\r\n'),
      ]).run(_input).toList();

      expect(events, [isA<RunStarted>(), isA<RunFinished>()]);
    });

    test('delivers a last frame that has no blank line after it', () async {
      final events = await _connectionAnswering([
        utf8.encode(_runStarted),
        utf8.encode('data: {"type":"RUN_FINISHED"}'),
      ]).run(_input).toList();

      expect(events, [isA<RunStarted>(), isA<RunFinished>()]);
    });

    test('stops reading after RUN_FINISHED', () async {
      final events = await _connectionAnswering([
        utf8.encode(_runStarted + _runFinished + _runStarted),
      ]).run(_input).toList();

      expect(events, [isA<RunStarted>(), isA<RunFinished>()]);
    });

    test('ends without an error when the server closes early', () async {
      final events = await _connectionAnswering([
        utf8.encode(_runStarted),
      ]).run(_input).toList();

      expect(events, [isA<RunStarted>()]);
    });

    test('turns frames it cannot decode into UnknownEvent values', () async {
      final events = await _connectionAnswering([
        utf8.encode(
          'data: {"type":"SUBAGENT_STARTED","subagentRunId":"sa-1"}\n\n'
          'data: not json\n\n'
          'data: [1, 2]\n\n'
          'data: {"type":"TOOL_CALL_START"}\n\n'
          '$_runFinished',
        ),
      ]).run(_input).toList();

      expect(events, [
        isA<UnknownEvent>()
            .having((e) => e.type, 'type', 'SUBAGENT_STARTED')
            .having((e) => e.problem, 'problem', isNull),
        isA<UnknownEvent>().having(
          (e) => e.problem,
          'problem',
          allOf(contains('not JSON'), contains('not json')),
        ),
        isA<UnknownEvent>().having(
          (e) => e.problem,
          'problem',
          contains('not a JSON object'),
        ),
        isA<UnknownEvent>()
            .having((e) => e.type, 'type', 'TOOL_CALL_START')
            .having((e) => e.problem, 'problem', isNotNull),
        isA<RunFinished>(),
      ]);
    });

    test('lets the headers callback override the default headers', () async {
      late http.BaseRequest sent;
      final connection = AgentConnection.http(
        Uri.parse('https://agent.test/agent'),
        headers: () => {'Accept': 'text/event-stream, */*'},
        newClient: () => MockClient.streaming((request, body) async {
          sent = request;
          return _eventStreamResponse([utf8.encode(_runFinished)]);
        }),
      );

      await connection.run(_input).drain<void>();

      expect(sent.headers['accept'], 'text/event-stream, */*');
      expect(sent.headers['content-type'], 'application/json');
    });
  });
}

typedef _Request = ({
  String method,
  String path,
  HttpHeaders headers,
  String body,
});

typedef _Handler = Future<void> Function(_Exchange exchange);

/// A local AG-UI backend that records every request and answers it with a
/// handler.
final class _Backend {
  _Backend._(this._server, this._handler) {
    _server.listen((request) => unawaited(_serve(request)));
  }

  static Future<_Backend> start(_Handler handler) async => _Backend._(
    await HttpServer.bind(InternetAddress.loopbackIPv4, 0),
    handler,
  );

  final HttpServer _server;
  final _Handler _handler;
  final _sockets = <Socket>[];

  /// Every request so far, in order.
  final requests = <_Request>[];

  /// The URL to POST runs to.
  Uri get endpoint => Uri.parse('http://127.0.0.1:${_server.port}/agent');

  Future<void> _serve(HttpRequest request) async {
    final body = await utf8.decodeStream(request);
    requests.add((
      method: request.method,
      path: request.uri.path,
      headers: request.headers,
      body: body,
    ));
    await _handler(_Exchange(request, _sockets));
  }

  Future<void> close() async {
    for (final socket in _sockets) {
      socket.destroy();
    }
    await _server.close(force: true);
  }
}

/// One request to the [_Backend], and the ways to answer it.
final class _Exchange {
  _Exchange(this.request, this._sockets);

  /// The request, with its body already read.
  final HttpRequest request;
  final List<Socket> _sockets;

  /// Takes over the socket; the caller writes the whole response itself.
  Future<Socket> detachSocket() async {
    final socket = await request.response.detachSocket(writeHeaders: false);
    _sockets.add(socket);
    return socket;
  }

  /// Starts an event stream whose bytes the caller writes to the returned
  /// socket, so it controls exactly how they arrive.
  Future<Socket> eventStream() async {
    final socket = await detachSocket();
    socket.write(
      'HTTP/1.1 200 OK\r\n'
      'content-type: text/event-stream; charset=utf-8\r\n'
      'connection: close\r\n'
      '\r\n',
    );
    await socket.flush();
    return socket;
  }
}

/// Answers with [body] in an ordinary response.
_Handler _respond(
  String body, {
  int status = 200,
  String contentType = 'text/event-stream',
}) => (exchange) async {
  final response = exchange.request.response
    ..statusCode = status
    ..headers.set('content-type', contentType)
    ..write(body);
  await response.close();
};

/// Writes [bytes] and waits a little, so the next write arrives on its own.
Future<void> _send(Socket socket, List<int> bytes) async {
  socket.add(bytes);
  await socket.flush();
  await Future<void>.delayed(const Duration(milliseconds: 20));
}

/// Completes [closed] when the client closes its side of [socket].
void _onClosedByPeer(Socket socket, Completer<void> closed) {
  void complete() {
    if (!closed.isCompleted) {
      closed.complete();
    }
  }

  socket.listen((_) {}, onError: (Object _) => complete(), onDone: complete);
}

/// A connection whose client answers every run with exactly [chunks].
AgentConnection _connectionAnswering(List<List<int>> chunks) =>
    AgentConnection.http(
      Uri.parse('https://agent.test/agent'),
      newClient: () => MockClient.streaming(
        (request, body) async => _eventStreamResponse(chunks),
      ),
    );

http.StreamedResponse _eventStreamResponse(List<List<int>> chunks) =>
    http.StreamedResponse(
      Stream.fromIterable(chunks),
      200,
      headers: {'content-type': 'text/event-stream'},
    );

/// Matches an error whose `toString()` matches [matcher].
Matcher _hasMessage(Matcher matcher) =>
    isA<Object>().having((error) => '$error', 'toString()', matcher);

/// A real client that remembers whether it was closed.
final class _TrackingClient extends http.BaseClient {
  final _inner = http.Client();

  /// Whether [close] was called.
  bool isClosed = false;

  @override
  Future<http.StreamedResponse> send(http.BaseRequest request) =>
      _inner.send(request);

  @override
  void close() {
    isClosed = true;
    _inner.close();
  }
}
