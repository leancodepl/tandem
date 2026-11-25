import 'dart:async';

import 'package:http/http.dart' as http;
import 'package:tandem/tandem.dart';

/// The HTTP client of one run. The Firebase SDK can neither abort a request
/// nor time out, so this client does both: [close] aborts the request, and
/// each wait of the run fails after [_idleTimeout].
final class RunClient(
  final Duration _idleTimeout, {
  required final void Function(TimeoutException) _onCredentialsTimeout,
}) extends http.BaseClient {
  final _inner = http.Client();
  final _aborted = Completer<void>();
  Timer? _credentialsTimeout;
  ResponseStatus? _responseStatus;

  /// The status of the response whose body the SDK reads, from its headers
  /// until the transport of that body fails.
  ResponseStatus? get responseStatus => _responseStatus;

  /// Starts the wait for the SDK's request. The SDK asks for credentials
  /// before it sends, and nothing can fail its stream while it waits for
  /// them, so that timeout goes to `onCredentialsTimeout`.
  void expectRequest() {
    _credentialsTimeout = Timer(
      _idleTimeout,
      () => _onCredentialsTimeout(_timedOut('credentials', _idleTimeout)),
    );
  }

  @override
  Future<http.StreamedResponse> send(http.BaseRequest request) async {
    _credentialsTimeout?.cancel();
    final abortable = await _abortable(request);
    // Credentials can arrive after the run ended. The request is then not
    // sent.
    if (_aborted.isCompleted) throw http.RequestAbortedException(request.url);

    final response = await _inner
        .send(abortable)
        .timeout(
          _idleTimeout,
          onTimeout: () => throw _timedOut('response headers', _idleTimeout),
        );
    _responseStatus = ResponseStatus(response.statusCode);
    final body = response.stream.handleError(_transportFailed);
    return _withBody(response, _failingWhenIdle(body));
  }

  @override
  void close() {
    if (_aborted.isCompleted) return;

    _aborted.complete();
    _credentialsTimeout?.cancel();
    _inner.close();
  }

  /// A copy of [request] that [close] aborts. The SDK sends a plain one.
  Future<http.AbortableRequest> _abortable(http.BaseRequest request) async =>
      http.AbortableRequest(
          request.method,
          request.url,
          abortTrigger: _aborted.future,
        )
        ..headers.addAll(request.headers)
        ..followRedirects = request.followRedirects
        ..maxRedirects = request.maxRedirects
        ..persistentConnection = request.persistentConnection
        ..bodyBytes = await request.finalize().toBytes();

  void _transportFailed(Object error, StackTrace stack) {
    _responseStatus = null;
    // The SDK still gets the error.
    Error.throwWithStackTrace(error, stack);
  }

  Stream<List<int>> _failingWhenIdle(Stream<List<int>> body) => body.timeout(
    _idleTimeout,
    // Closing the sink cancels the silent connection; an error alone does
    // not.
    onTimeout: (sink) => sink
      ..addError(_timedOut('response bytes', _idleTimeout))
      ..close(),
  );
}

TimeoutException _timedOut(String awaited, Duration timeout) =>
    TimeoutException('Timed out waiting for Firebase $awaited.', timeout);

http.StreamedResponse _withBody(
  http.StreamedResponse response,
  Stream<List<int>> body,
) => http.StreamedResponse(
  body,
  response.statusCode,
  contentLength: response.contentLength,
  request: response.request,
  headers: response.headers,
  isRedirect: response.isRedirect,
  persistentConnection: response.persistentConnection,
  reasonPhrase: response.reasonPhrase,
);
