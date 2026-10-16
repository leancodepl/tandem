import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

/// Keeps the protocol layer separable: `lib/src/protocol` knows nothing about
/// the session engine, and the engine reaches the network only through
/// `AgentConnection`.
void main() {
  group('architecture', () {
    test('lib/src/protocol depends only on itself, dart:, http and meta', () {
      final violations = <String>[];
      for (final file in _dartFiles('lib/src/protocol')) {
        for (final uri in _directiveUris(file)) {
          final allowed =
              uri.startsWith('dart:') ||
              uri.startsWith('package:http/') ||
              uri.startsWith('package:meta/') ||
              uri.startsWith('package:tandem/src/protocol/') ||
              _resolvesInside(file, uri, 'lib/src/protocol');
          if (!allowed) {
            violations.add('${file.path}: $uri');
          }
        }
      }
      expect(violations, isEmpty);
    });

    test('the session engine never imports package:http', () {
      final violations = <String>[
        for (final dir in ['session', 'state', 'tools', 'view'])
          for (final file in _dartFiles('lib/src/$dir'))
            for (final uri in _directiveUris(file))
              if (uri.startsWith('package:http/')) '${file.path}: $uri',
      ];
      expect(violations, isEmpty);
    });

    test('the core never imports Flutter or bloc', () {
      final violations = <String>[
        for (final file in _dartFiles('lib'))
          for (final uri in _directiveUris(file))
            if (uri.startsWith('package:flutter/') ||
                uri.startsWith('package:bloc/') ||
                uri.startsWith('package:flutter_bloc/'))
              '${file.path}: $uri',
      ];
      expect(violations, isEmpty);
    });
  });
}

final _directive = RegExp(
  r'''^\s*(?:import|export)\s+['"]([^'"]+)['"]''',
  multiLine: true,
);

Iterable<File> _dartFiles(String dir) => Directory(dir)
    .listSync(recursive: true)
    .whereType<File>()
    .where((file) => file.path.endsWith('.dart'));

Iterable<String> _directiveUris(File file) => _directive
    .allMatches(file.readAsStringSync())
    .map((match) => match.group(1)!);

bool _resolvesInside(File file, String uri, String dir) {
  if (uri.contains(':')) {
    return false;
  }
  final resolved = Uri.file(file.path).resolve(uri).toFilePath();
  return Uri.file(resolved).normalizePath().toFilePath().startsWith(dir);
}
