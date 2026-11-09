import 'dart:convert';
import 'dart:io';

import 'package:stream_channel/stream_channel.dart';

/// An AG-UI agent for browser tests, run in a VM isolate by `spawnHybridUri`.
/// Sends its endpoint and streams an older run before the requested run.
/// Keeps the response open and reports when the client closes it.
/// It runs with flutter_tools' package config, so it imports only `dart:`
/// libraries and `stream_channel`.
Future<void> hybridMain(StreamChannel<Object?> channel) async {
  final server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
  channel.sink.add('http://${server.address.host}:${server.port}/agent');

  await for (final request in server) {
    final response = request.response
      ..headers.set('Access-Control-Allow-Origin', '*');
    if (request.method == 'OPTIONS') {
      response.headers
        ..set('Access-Control-Allow-Methods', 'POST')
        ..set('Access-Control-Allow-Headers', 'accept, content-type');
      await response.close();
      continue;
    }

    final input = jsonDecode(
      await utf8.decoder.bind(request).join(),
    ) as Map<String, Object?>;
    response
      ..headers.contentType = ContentType('text', 'event-stream')
      ..headers.chunkedTransferEncoding = false
      ..persistentConnection = false;
    // HttpResponse does not notice a client that leaves an open response.
    final socket = await response.detachSocket();
    socket.listen(null, onDone: () => channel.sink.add('closed'));
    for (final runId in ['run-replayed', input['runId']]) {
      for (final type in ['RUN_STARTED', 'RUN_FINISHED']) {
        final event = {
          'type': type,
          'threadId': input['threadId'],
          'runId': runId,
        };
        socket.write('data: ${jsonEncode(event)}\n\n');
      }
    }
  }
}
