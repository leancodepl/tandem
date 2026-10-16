import 'dart:async';
import 'dart:convert';

const _dataPrefix = 'data:';
const _valuePadding = ' ';
const _dataSeparator = '\n';

/// Parses an SSE byte stream into the `data` of its events, following
/// https://html.spec.whatwg.org/multipage/server-sent-events.html#event-stream-interpretation
///
/// AG-UI sends only `data:` lines: comments, such as the keep-alive pings of
/// ADK, and every other field are dropped. Like the AG-UI TypeScript client,
/// a last event that is not followed by a blank line is still delivered when
/// the stream ends.
///
/// Cancelling the returned stream cancels [bytes] at once, which closes the
/// HTTP connection.
Stream<String> parseSse(Stream<List<int>> bytes) {
  final data = <String>[];

  void dispatch(EventSink<String> sink) {
    if (data.isNotEmpty) {
      sink.add(data.join(_dataSeparator));
      data.clear();
    }
  }

  void handleLine(String line, EventSink<String> sink) {
    if (line.isEmpty) {
      return dispatch(sink);
    }
    if (line.startsWith(_dataPrefix)) {
      final value = line.substring(_dataPrefix.length);
      data.add(
        value.startsWith(_valuePadding)
            ? value.substring(_valuePadding.length)
            : value,
      );
    }
  }

  return utf8.decoder
      .bind(bytes)
      .transform(const LineSplitter())
      .transform(
        StreamTransformer.fromHandlers(
          handleData: handleLine,
          handleDone: (sink) {
            dispatch(sink);
            sink.close();
          },
        ),
      );
}
