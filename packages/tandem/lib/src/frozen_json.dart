import 'dart:collection';

import 'package:tandem/src/protocol/ag_ui.dart';

/// An owned, deeply unmodifiable copy of [object], so that nobody who holds
/// it can change what another holder reads. Throws a [FormatException] for a
/// key or a value that is not JSON.
JsonObject frozenJson(Map<Object?, Object?> object) {
  final owned = <String, Object?>{};
  for (final MapEntry(:key, :value) in object.entries) {
    if (key is! String) {
      throw FormatException(
        'A JSON object has a key that is not a string.',
        key,
      );
    }
    owned[key] = _frozenValue(value);
  }
  return UnmodifiableMapView(owned);
}

Object? _frozenValue(Object? value) => switch (value) {
  null || String() || bool() => value,
  final num number when number.isFinite => number,
  final Map<Object?, Object?> object => frozenJson(object),
  final List<Object?> values => List<Object?>.unmodifiable(
    values.map(_frozenValue),
  ),
  _ => throw FormatException('Not a JSON value.', value),
};
