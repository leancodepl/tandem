import 'package:flutter/painting.dart';
import 'package:json_annotation/json_annotation.dart';

/// The names of the kit's inks.
enum InkName() {
  ocean,
  ember,
  slate,
}

/// An ink of the kit, which only the kit mixes.
final class const KitInk._(final Color color);

/// An ink by its name.
final class const InkConverter() implements JsonConverter<KitInk, InkName> {
  static const _inks = {
    InkName.ocean: KitInk._(Color(0xFF00838F)),
    InkName.ember: KitInk._(Color(0xFFD84315)),
    InkName.slate: KitInk._(Color(0xFF455A64)),
  };

  @override
  KitInk fromJson(InkName json) =>
      _inks[json] ?? const KitInk._(Color(0x00000000));

  @override
  InkName toJson(KitInk object) =>
      _inks.entries.firstWhere((entry) => entry.value == object).key;
}
