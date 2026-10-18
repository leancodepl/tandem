import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  // `dart run skills@ get` skips a skill whose name does not start with
  // tandem-. The name in SKILL.md is the name of its directory.
  test('the skills installer finds every tandem skill', () {
    final skills = Directory('../packages/tandem/skills')
        .listSync()
        .whereType<Directory>();
    expect(skills, isNotEmpty);
    for (final skill in skills) {
      final name = skill.uri.pathSegments.lastWhere((s) => s.isNotEmpty);
      expect(name, startsWith('tandem-'));
      expect(
        File('${skill.path}/SKILL.md').readAsLinesSync(),
        contains('name: $name'),
      );
    }
  });
}
