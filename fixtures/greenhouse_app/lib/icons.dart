import 'package:flutter/widgets.dart';
import 'package:json_annotation/json_annotation.dart';

/// An icon by name: leaf, drop or sun.
final class const IconNameConverter()
    implements JsonConverter<IconData, String> {
  static const _icons = {
    'leaf': IconData(0xea35),
    'drop': IconData(0xe798),
    'sun': IconData(0xe430),
  };

  @override
  IconData fromJson(String json) =>
      _icons[json] ??
      (throw FormatException('Write one of ${_icons.keys.join(', ')}.'));

  @override
  String toJson(IconData object) =>
      _icons.entries.firstWhere((entry) => entry.value == object).key;
}
