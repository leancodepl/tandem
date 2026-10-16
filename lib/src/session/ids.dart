// Internal: not exported.

import 'dart:math';

final _random = Random.secure();

/// A random RFC 4122 version 4 UUID, such as
/// `0b7f5c4e-2d1a-4c3b-9e8f-1a2b3c4d5e6f`.
String newUuid() {
  final bytes = [for (var i = 0; i < 16; i++) _random.nextInt(256)];
  bytes[6] = (bytes[6] & 0x0f) | 0x40;
  bytes[8] = (bytes[8] & 0x3f) | 0x80;
  final hex = [
    for (final byte in bytes) byte.toRadixString(16).padLeft(2, '0'),
  ].join();
  return '${hex.substring(0, 8)}-${hex.substring(8, 12)}-'
      '${hex.substring(12, 16)}-${hex.substring(16, 20)}-${hex.substring(20)}';
}
