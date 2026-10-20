import 'dart:async';
import 'dart:convert';

/// Reads SSE `data` fields, ignoring comments and other fields.
/// Delivers the last event even without a trailing blank line.
///
/// Cancelling the result cancels [bytes].
Stream<String> parseSse(Stream<List<int>> bytes) {
  final parser = _SseParser();

  return utf8.decoder
      .bind(bytes)
      .transform(const LineSplitter())
      .transform(
        StreamTransformer.fromHandlers(
          handleData: parser.addLine,
          handleDone: parser.close,
        ),
      );
}

final class _SseParser() {
  static const _dataPrefix = 'data:';

  final _data = <String>[];

  void addLine(String line, EventSink<String> sink) {
    if (line.isEmpty) {
      _dispatch(sink);
      return;
    }
    if (line.startsWith(_dataPrefix)) {
      final value = line.substring(_dataPrefix.length);
      // The grammar drops one space after the colon.
      _data.add(value.startsWith(' ') ? value.substring(1) : value);
    }
  }

  void close(EventSink<String> sink) {
    _dispatch(sink);
    sink.close();
  }

  void _dispatch(EventSink<String> sink) {
    if (_data.isEmpty) return;

    sink.add(_data.join('\n'));
    _data.clear();
  }
}
