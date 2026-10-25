import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  // Each Dart block of these docs follows a comment that names its file, so
  // the docs show only code that compiles. A block in a list item is
  // indented, and its comment with it.
  for (final path in [
    'README.md',
    'packages/tandem/example/example.md',
    'packages/tandem_generator/example/example.md',
  ]) {
    test('every snippet of $path is in its file', () {
      final doc = File('../$path').readAsStringSync();
      final snippets = RegExp(
        r'^( *)<!-- (\S+) -->\n(?:[ \t]*\n)*\1```dart\n(.*?)^\1```',
        multiLine: true,
        dotAll: true,
      ).allMatches(doc);
      expect(snippets, isNotEmpty);
      expect(
        '```dart'.allMatches(doc),
        hasLength(snippets.length),
        reason: 'A Dart block without its file',
      );
      for (final snippet in snippets) {
        final indent = snippet[1] ?? '';
        final code = [
          for (final line in (snippet[3] ?? '').split('\n'))
            if (line.startsWith(indent))
              line.substring(indent.length)
            else
              line,
        ].join('\n');
        expect(
          File('../${snippet[2]}').readAsStringSync(),
          contains(code),
          reason: '${snippet[2]}',
        );
      }
    });
  }

  test('the README of tandem is a copy of the README', () {
    // pub.dev plays no video, so the copy shows the film as a GIF.
    final readme = File('../README.md').readAsStringSync().replaceFirst(
      RegExp(r'^https://github\.com/user-attachments/\S+$', multiLine: true),
      'the film',
    );
    final copy = File('../packages/tandem/README.md')
        .readAsStringSync()
        .replaceFirst(
          RegExp(
            r'^<p align="center">\n[^\n]*\.gif[^\n]*\n</p>$',
            multiLine: true,
          ),
          'the film',
        );
    expect(copy, readme);
  });
}
