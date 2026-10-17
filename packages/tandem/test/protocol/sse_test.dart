import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:tandem/src/protocol/sse.dart';

void main() {
  test('parses split lines, split characters, CRLF pings and a last event '
      'without a blank line', () async {
    final chunks = [
      'data: {"a":',
      '1}\n\n: ping - x\r\n\r\ndata: "zaż',
      'ółć"\r',
      '\n\r\ndata: last',
    ].map(utf8.encode).toList();
    // Split the second chunk inside the two bytes of its last character, ż.
    final split = chunks[1];
    final bytes = [
      chunks[0],
      split.sublist(0, split.length - 1),
      split.sublist(split.length - 1),
      chunks[2],
      chunks[3],
    ];

    expect(await parseSse(Stream.fromIterable(bytes)).toList(), [
      '{"a":1}',
      '"zażółć"',
      'last',
    ]);
  });
}
