import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  // Each Dart block of the examples doc follows a comment that names its
  // file, so the doc shows only code that compiles.
  test('every snippet of doc/examples.md is in its file', () {
    final doc = File('../doc/examples.md').readAsStringSync();
    final snippets = RegExp(
      r'<!-- (\S+) -->\n```dart\n(.*?)```',
      dotAll: true,
    ).allMatches(doc);
    expect(snippets, isNotEmpty);
    expect(
      '```dart'.allMatches(doc),
      hasLength(snippets.length),
      reason: 'A Dart block without its file',
    );
    for (final snippet in snippets) {
      expect(
        File('../${snippet[1]}').readAsStringSync(),
        contains(snippet[2]),
        reason: '${snippet[1]}',
      );
    }
  });
}
