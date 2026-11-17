import 'dart:async';

import 'package:http/http.dart' as http;

final class RunClient(final Duration idleTimeout, final http.Client _client)
    extends http.BaseClient {
  final _abort = Completer<void>();
  var _readingSuccessfulResponse = false;
  void Function()? onSend;
  bool get readingSuccessfulResponse => _readingSuccessfulResponse;

  @override
  Future<http.StreamedResponse> send(http.BaseRequest request) async {
    if (_abort.isCompleted) throw http.RequestAbortedException(request.url);
    onSend?.call();
    final body = await request.finalize().toBytes();
    if (_abort.isCompleted) throw http.RequestAbortedException(request.url);
    final abortable =
        http.AbortableRequest(
            request.method,
            request.url,
            abortTrigger: _abort.future,
          )
          ..headers.addAll(request.headers)
          ..followRedirects = request.followRedirects
          ..maxRedirects = request.maxRedirects
          ..persistentConnection = request.persistentConnection
          ..bodyBytes = body;
    final response = await _client
        .send(abortable)
        .timeout(
          idleTimeout,
          onTimeout: () => throw TimeoutException(
            'Timed out waiting for Firebase response headers.',
            idleTimeout,
          ),
        );
    _readingSuccessfulResponse = response.statusCode == 200;
    final bodyStream = response.stream.handleError((
      Object error,
      StackTrace stack,
    ) {
      _readingSuccessfulResponse = false;
      Error.throwWithStackTrace(error, stack);
    });
    return http.StreamedResponse(
      bodyStream.timeout(
        idleTimeout,
        onTimeout: (sink) {
          sink
            ..addError(
              TimeoutException(
                'Timed out waiting for Firebase response bytes.',
                idleTimeout,
              ),
            )
            ..close();
        },
      ),
      response.statusCode,
      contentLength: response.contentLength,
      request: response.request,
      headers: response.headers,
      isRedirect: response.isRedirect,
      persistentConnection: response.persistentConnection,
      reasonPhrase: response.reasonPhrase,
    );
  }

  @override
  void close() {
    if (_abort.isCompleted) return;
    _abort.complete();
    _client.close();
  }
}
