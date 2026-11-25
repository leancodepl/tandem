import 'package:flutter_test/flutter_test.dart';
import 'package:tandem/src/protocol/response_status.dart';

void main() {
  test('a status has three digits', () {
    for (final code in [100, 999]) {
      expect(ResponseStatus(code).code, code);
    }
    for (final code in [99, 1000]) {
      expect(() => ResponseStatus(code), throwsA(isA<AssertionError>()));
    }
  });
}
