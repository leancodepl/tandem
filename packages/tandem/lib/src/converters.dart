import 'package:flutter/painting.dart';
import 'package:json_annotation/json_annotation.dart';

/// The form of [ColorConverter], as the agent reads it.
const colorForm =
    'A color as #RRGGBB, or #RRGGBBAA with its opacity, as in CSS.';

/// A color as `#RRGGBB`, or `#RRGGBBAA` with its opacity, as in CSS.
///
/// Tandem writes 8 bits per channel in sRGB, so a color of another color
/// space, such as Display P3, is converted to sRGB and may change slightly.
final class const ColorConverter() implements JsonConverter<Color, String> {
  @override
  Color fromJson(String json) {
    final hex = RegExp(r'^#([0-9a-fA-F]{6}|[0-9a-fA-F]{8})$').firstMatch(json);
    if (hex == null) {
      throw FormatException('Write #RRGGBB or #RRGGBBAA, not "$json".');
    }
    final digits = hex[1] ?? '';
    final rgb = int.parse(digits.substring(0, 6), radix: 16);
    final alpha = digits.length == 8
        ? int.parse(digits.substring(6), radix: 16)
        : 0xFF;
    return Color(alpha << 24 | rgb);
  }

  @override
  String toJson(Color object) {
    final srgb = object.withValues(colorSpace: .sRGB);
    String channel(double value) =>
        (value.clamp(0, 1) * 255).round().toRadixString(16).padLeft(2, '0');
    final rgb = [srgb.r, srgb.g, srgb.b].map(channel).join();
    final alpha = channel(srgb.a);
    return alpha == 'ff' ? '#$rgb' : '#$rgb$alpha';
  }
}

/// The form of [EdgeInsetsGeometryConverter], as the agent reads it.
const edgeInsetsGeometryForm =
    'Insets in logical pixels: one number for every side, as "16"; two '
    'for top and bottom, then left and right, as "8 16"; or sides by '
    'name, as "top 8 start 16 end 16". start and end follow the reading '
    'direction, left and right do not, and one value names only one kind.';

/// Insets in logical pixels: one number for every side, as "16"; two for
/// top and bottom, then left and right, as "8 16"; or sides by name, as
/// "top 8 start 16 end 16". start and end follow the reading direction,
/// left and right do not, and one value names only one kind. Text that
/// names neither reads as [EdgeInsets], so [EdgeInsetsDirectional] without
/// start and end writes "start 0", as "top 8 start 0". It writes only sides
/// that are finite and not below 0, and throws an [ArgumentError] for
/// others and for insets that mix both directions.
final class const EdgeInsetsGeometryConverter()
    implements JsonConverter<EdgeInsetsGeometry, String> {
  @override
  EdgeInsetsGeometry fromJson(String json) => _readInsets(json);

  @override
  String toJson(EdgeInsetsGeometry object) => _writeInsets(object);
}

/// The form of [EdgeInsetsConverter], as the agent reads it.
const edgeInsetsForm =
    'Insets in logical pixels: one number for every side, as "16"; two '
    'for top and bottom, then left and right, as "8 16"; or sides by '
    'name, as "top 8 left 16". Only left and right, which do not follow '
    'the reading direction.';

/// Insets in logical pixels: one number for every side, as "16"; two for
/// top and bottom, then left and right, as "8 16"; or sides by name, as
/// "top 8 left 16". Only left and right, which do not follow the reading
/// direction. It writes only sides that are finite and not below 0, and
/// throws an [ArgumentError] for others.
final class const EdgeInsetsConverter()
    implements JsonConverter<EdgeInsets, String> {
  @override
  EdgeInsets fromJson(String json) => switch (_readInsets(json)) {
    final EdgeInsets insets => insets,
    _ => throw const FormatException('Name left and right, not start or end.'),
  };

  @override
  String toJson(EdgeInsets object) => _writeInsets(object);
}

/// The form of [EdgeInsetsDirectionalConverter], as the agent reads it.
const edgeInsetsDirectionalForm =
    'Insets in logical pixels that follow the reading direction: one '
    'number for every side, as "16"; two for top and bottom, then start '
    'and end, as "8 16"; or sides by name, as "top 8 start 16".';

/// Insets in logical pixels that follow the reading direction: one number
/// for every side, as "16"; two for top and bottom, then start and end, as
/// "8 16"; or sides by name, as "top 8 start 16". It writes only sides that
/// are finite and not below 0, and throws an [ArgumentError] for others.
final class const EdgeInsetsDirectionalConverter()
    implements JsonConverter<EdgeInsetsDirectional, String> {
  @override
  EdgeInsetsDirectional fromJson(String json) {
    final insets = _readInsets(json, directional: true);
    if (insets is EdgeInsetsDirectional) return insets;
    throw const FormatException('Name start and end, not left or right.');
  }

  @override
  String toJson(EdgeInsetsDirectional object) => _writeInsets(object);
}

/// The form of [AlignmentGeometryConverter], as the agent reads it.
const alignmentGeometryForm =
    'A place in a box by name: topLeft, topCenter, topRight, centerLeft, '
    'center, centerRight, bottomLeft, bottomCenter or bottomRight; or, to '
    'follow the reading direction, topStart, topEnd, centerStart, '
    'centerEnd, bottomStart or bottomEnd.';

/// A place in a box by name: topLeft, topCenter, topRight, centerLeft,
/// center, centerRight, bottomLeft, bottomCenter or bottomRight; or, to
/// follow the reading direction, topStart, topEnd, centerStart, centerEnd,
/// bottomStart or bottomEnd. topCenter, center and bottomCenter read as
/// [Alignment], which places a child as [AlignmentDirectional]'s do. It
/// writes only these alignments, and throws an [ArgumentError] for another,
/// such as `Alignment(0.3, 0.2)`.
final class const AlignmentGeometryConverter()
    implements JsonConverter<AlignmentGeometry, String> {
  @override
  AlignmentGeometry fromJson(String json) =>
      _readAlignment(json, _allAlignments);

  @override
  String toJson(AlignmentGeometry object) =>
      _writeAlignment(object, _allAlignments);
}

/// The form of [AlignmentConverter], as the agent reads it.
const alignmentForm =
    'A place in a box by name: topLeft, topCenter, topRight, centerLeft, '
    'center, centerRight, bottomLeft, bottomCenter or bottomRight.';

/// A place in a box by name: topLeft, topCenter, topRight, centerLeft,
/// center, centerRight, bottomLeft, bottomCenter or bottomRight. It writes
/// only these alignments, and throws an [ArgumentError] for another, such as
/// `Alignment(0.3, 0.2)`.
final class const AlignmentConverter()
    implements JsonConverter<Alignment, String> {
  @override
  Alignment fromJson(String json) => _readAlignment(json, _alignments);

  @override
  String toJson(Alignment object) => _writeAlignment(object, _alignments);
}

/// The form of [AlignmentDirectionalConverter], as the agent reads it.
const alignmentDirectionalForm =
    'A place in a box that follows the reading direction, by name: '
    'topStart, topCenter, topEnd, centerStart, center, centerEnd, '
    'bottomStart, bottomCenter or bottomEnd.';

/// A place in a box that follows the reading direction, by name: topStart,
/// topCenter, topEnd, centerStart, center, centerEnd, bottomStart,
/// bottomCenter or bottomEnd. It writes only these alignments, and throws an
/// [ArgumentError] for another.
final class const AlignmentDirectionalConverter()
    implements JsonConverter<AlignmentDirectional, String> {
  @override
  AlignmentDirectional fromJson(String json) =>
      _readAlignment(json, _allDirectionalAlignments);

  @override
  String toJson(AlignmentDirectional object) =>
      _writeAlignment(object, _allDirectionalAlignments);
}

const _alignments = <String, Alignment>{
  'topLeft': .topLeft,
  'topCenter': .topCenter,
  'topRight': .topRight,
  'centerLeft': .centerLeft,
  'center': .center,
  'centerRight': .centerRight,
  'bottomLeft': .bottomLeft,
  'bottomCenter': .bottomCenter,
  'bottomRight': .bottomRight,
};

const _directionalAlignments = <String, AlignmentDirectional>{
  'topStart': .topStart,
  'topEnd': .topEnd,
  'centerStart': .centerStart,
  'centerEnd': .centerEnd,
  'bottomStart': .bottomStart,
  'bottomEnd': .bottomEnd,
};

const _allDirectionalAlignments = <String, AlignmentDirectional>{
  ..._directionalAlignments,
  'topCenter': .topCenter,
  'center': .center,
  'bottomCenter': .bottomCenter,
};

const _allAlignments = <String, AlignmentGeometry>{
  ..._alignments,
  ..._directionalAlignments,
};

T _readAlignment<T extends AlignmentGeometry>(
  String json,
  Map<String, T> byName,
) =>
    byName[json] ??
    (throw FormatException('Write one of ${byName.keys.join(', ')}.'));

String _writeAlignment(
  AlignmentGeometry value,
  Map<String, AlignmentGeometry> byName,
) {
  for (final MapEntry(key: name, value: member) in byName.entries) {
    if (member == value) return name;
  }
  throw ArgumentError.value(value, 'object', 'has no name');
}

EdgeInsetsGeometry _readInsets(String text, {bool directional = false}) {
  final words = text.trim().split(RegExp(r'\s+'));
  final numbers = words.map(_side).toList();
  if (numbers case [final all?]) {
    return directional ? EdgeInsetsDirectional.all(all) : EdgeInsets.all(all);
  }
  if (numbers case [final vertical?, final horizontal?]) {
    return directional
        ? EdgeInsetsDirectional.symmetric(
            vertical: vertical,
            horizontal: horizontal,
          )
        : EdgeInsets.symmetric(vertical: vertical, horizontal: horizontal);
  }
  if (words.length.isOdd) throw FormatException(_insetsHelp(text));
  final sides = <String, double>{};
  for (var index = 0; index < words.length; index += 2) {
    final side = words[index];
    final value = _side(words[index + 1]);
    if (!_sideNames.contains(side) ||
        value == null ||
        sides.containsKey(side)) {
      throw FormatException(_insetsHelp(text));
    }
    sides[side] = value;
  }
  final physical = sides.containsKey('left') || sides.containsKey('right');
  final relative = sides.containsKey('start') || sides.containsKey('end');
  if (physical && relative) {
    throw const FormatException(
      'Name left and right, or start and end, not both.',
    );
  }
  final isDirectional = physical || relative ? relative : directional;
  return isDirectional
      ? EdgeInsetsDirectional.only(
          top: sides['top'] ?? 0,
          bottom: sides['bottom'] ?? 0,
          start: sides['start'] ?? 0,
          end: sides['end'] ?? 0,
        )
      : EdgeInsets.only(
          top: sides['top'] ?? 0,
          bottom: sides['bottom'] ?? 0,
          left: sides['left'] ?? 0,
          right: sides['right'] ?? 0,
        );
}

String _writeInsets(EdgeInsetsGeometry insets) {
  final sides = switch (insets) {
    final EdgeInsets insets => {
      'top': insets.top,
      'bottom': insets.bottom,
      'left': insets.left,
      'right': insets.right,
    },
    final EdgeInsetsDirectional insets => {
      'top': insets.top,
      'bottom': insets.bottom,
      'start': insets.start,
      'end': insets.end,
    },
    _ => throw ArgumentError.value(insets, 'object', 'mixes two directions'),
  };
  if (sides.values.every(_isSide)) {
    final text = [
      for (final MapEntry(key: side, :value) in sides.entries)
        if (value != 0) '$side ${_number(value)}',
    ];
    // Without start or end, EdgeInsetsGeometryConverter would read EdgeInsets.
    if (sides['start'] == 0 && sides['end'] == 0) {
      text.add('start 0');
    }
    return text.isEmpty ? '0' : text.join(' ');
  }
  throw ArgumentError.value(
    insets,
    'object',
    'has a side below 0 or not finite',
  );
}

double? _side(String word) => switch (double.tryParse(word)) {
  final value? when _isSide(value) => value,
  _ => null,
};

// A side's logical pixels: a finite number, not below 0.
bool _isSide(double value) => value.isFinite && value >= 0;

String _number(double value) => '$value'.replaceFirst(RegExp(r'\.0$'), '');

String _insetsHelp(String text) =>
    'Write one number, two, or sides by name, as "top 8 start 16"; '
    'not "$text".';

const _sideNames = {'top', 'bottom', 'left', 'right', 'start', 'end'};
