import 'dart:math';

const _hexDigits = '0123456789abcdef';
const _variantDigits = '89ab';

final _random = Random.secure();

/// A random RFC 4122 version 4 UUID, such as
/// `0b7f5c4e-2d1a-4c3b-9e8f-1a2b3c4d5e6f`.
String newId() {
  String digits(int count, [String alphabet = _hexDigits]) => [
    for (var i = 0; i < count; i++) alphabet[_random.nextInt(alphabet.length)],
  ].join();

  return '${digits(8)}-${digits(4)}-4${digits(3)}-'
      '${digits(1, _variantDigits)}${digits(3)}-${digits(12)}';
}
