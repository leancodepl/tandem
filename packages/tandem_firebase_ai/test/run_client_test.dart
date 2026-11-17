import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:tandem_firebase_ai/src/run_client.dart';

void main() {
  test(
    'closing aborts a request still waiting for headers and prevents reuse',
    () async {
      final sent = Completer<void>();
      final inner = MockClient.streaming((request, _) async {
        sent.complete();
        if (request case http.Abortable(:final abortTrigger?)) {
          await abortTrigger;
          throw http.RequestAbortedException(request.url);
        }
        throw StateError('Expected an abortable request.');
      });
      final client = RunClient(const Duration(seconds: 1), inner);
      final pending = client.get(Uri.https('example.invalid', '/generate'));
      final aborted = expectLater(
        pending,
        throwsA(isA<http.RequestAbortedException>()),
      );
      await sent.future;
      client.close();
      await aborted;
      await expectLater(
        client.get(Uri.https('example.invalid', '/late')),
        throwsA(isA<http.RequestAbortedException>()),
      );
    },
  );

  test(
    'idle timeout also observes a response body that never sends bytes',
    () async {
      final body = StreamController<List<int>>();
      final client = RunClient(
        const Duration(milliseconds: 10),
        MockClient.streaming(
          (_, _) async => http.StreamedResponse(body.stream, 200),
        ),
      );
      addTearDown(client.close);
      final response = await client.send(
        http.Request('POST', Uri.https('example.invalid', '/generate')),
      );
      await expectLater(
        response.stream.toList(),
        throwsA(
          isA<TimeoutException>().having(
            (error) => error.message,
            'message',
            'Timed out waiting for Firebase response bytes.',
          ),
        ),
      );
      await body.close();
    },
  );

  test(
    'a header timeout identifies the phase before any response bytes',
    () async {
      final headers = Completer<http.StreamedResponse>();
      final client = RunClient(
        const Duration(milliseconds: 10),
        MockClient.streaming((_, _) => headers.future),
      );
      addTearDown(client.close);
      await expectLater(
        client.send(
          http.Request('POST', Uri.https('example.invalid', '/generate')),
        ),
        throwsA(
          isA<TimeoutException>().having(
            (error) => error.message,
            'message',
            'Timed out waiting for Firebase response headers.',
          ),
        ),
      );
      headers.complete(http.StreamedResponse(const Stream.empty(), 200));
    },
  );
}
