import 'package:flutter/painting.dart';
import 'package:json_annotation/json_annotation.dart';

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

/// Insets in logical pixels: one number for every side, as "16"; two for
/// top and bottom, then left and right, as "8 16"; or sides by name, as
/// "top 8 start 16 end 16". start and end follow the reading direction,
/// left and right do not, and one value names only one kind. Text that
/// names neither reads as [EdgeInsets], so [EdgeInsetsDirectional] without
/// start and end writes "start 0", as "top 8 start 0".
final class const EdgeInsetsGeometryConverter()
    implements JsonConverter<EdgeInsetsGeometry, String> {
  @override
  EdgeInsetsGeometry fromJson(String json) => _Insets.parse(json).geometry;

  @override
  String toJson(EdgeInsetsGeometry object) => switch (object) {
    final EdgeInsets insets => _Insets.physical(insets).text,
    final EdgeInsetsDirectional insets => _Insets.directional(insets).text,
    _ => throw ArgumentError.value(object, 'object', 'mixes two directions'),
  };
}

/// Insets in logical pixels: one number for every side, as "16"; two for
/// top and bottom, then left and right, as "8 16"; or sides by name, as
/// "top 8 left 16". Only left and right, which do not follow the reading
/// direction.
final class const EdgeInsetsConverter()
    implements JsonConverter<EdgeInsets, String> {
  @override
  EdgeInsets fromJson(String json) => switch (_Insets.parse(json).geometry) {
    final EdgeInsets insets => insets,
    _ => throw const FormatException('Name left and right, not start or end.'),
  };

  @override
  String toJson(EdgeInsets object) => _Insets.physical(object).text;
}

/// Insets in logical pixels that follow the reading direction: one number
/// for every side, as "16"; two for top and bottom, then start and end, as
/// "8 16"; or sides by name, as "top 8 start 16".
final class const EdgeInsetsDirectionalConverter()
    implements JsonConverter<EdgeInsetsDirectional, String> {
  @override
  EdgeInsetsDirectional fromJson(String json) {
    final insets = _Insets.parse(json, directional: true);
    return switch (insets.geometry) {
      final EdgeInsetsDirectional insets => insets,
      _ => throw const FormatException(
        'Name start and end, not left or right.',
      ),
    };
  }

  @override
  String toJson(EdgeInsetsDirectional object) =>
      _Insets.directional(object).text;
}

/// A place in a box by name: topLeft, topCenter, topRight, centerLeft,
/// center, centerRight, bottomLeft, bottomCenter or bottomRight; or, to
/// follow the reading direction, topStart, topEnd, centerStart, centerEnd,
/// bottomStart or bottomEnd. topCenter, center and bottomCenter read as
/// [Alignment], which places a child as [AlignmentDirectional]'s do.
final class const AlignmentGeometryConverter()
    implements JsonConverter<AlignmentGeometry, String> {
  @override
  AlignmentGeometry fromJson(String json) =>
      _alignments[json] ??
      _directionalAlignments[json] ??
      (throw FormatException(
        'Write one of '
        '${[..._alignments.keys, ..._directionalAlignments.keys].join(', ')}.',
      ));

  @override
  String toJson(AlignmentGeometry object) =>
      _nameOf(object, _alignments) ??
      _nameOf(object, _directionalAlignments) ??
      (throw ArgumentError.value(object, 'object', 'has no name'));
}

/// A place in a box by name: topLeft, topCenter, topRight, centerLeft,
/// center, centerRight, bottomLeft, bottomCenter or bottomRight.
final class const AlignmentConverter()
    implements JsonConverter<Alignment, String> {
  @override
  Alignment fromJson(String json) =>
      _alignments[json] ??
      (throw FormatException('Write one of ${_alignments.keys.join(', ')}.'));

  @override
  String toJson(Alignment object) =>
      _nameOf(object, _alignments) ??
      (throw ArgumentError.value(object, 'object', 'has no name'));
}

/// A place in a box that follows the reading direction, by name: topStart,
/// topCenter, topEnd, centerStart, center, centerEnd, bottomStart,
/// bottomCenter or bottomEnd.
final class const AlignmentDirectionalConverter()
    implements JsonConverter<AlignmentDirectional, String> {
  @override
  AlignmentDirectional fromJson(String json) =>
      _directionalCenters[json] ??
      _directionalAlignments[json] ??
      (throw FormatException(
        'Write one of '
        '${[..._directionalAlignments.keys, ..._directionalCenters.keys].join(', ')}.',
      ));

  @override
  String toJson(AlignmentDirectional object) =>
      _nameOf(object, _directionalAlignments) ??
      _nameOf(object, _directionalCenters) ??
      (throw ArgumentError.value(object, 'object', 'has no name'));
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

const _directionalCenters = <String, AlignmentDirectional>{
  'topCenter': .topCenter,
  'center': .center,
  'bottomCenter': .bottomCenter,
};

String? _nameOf<T>(T value, Map<String, T> byName) {
  for (final MapEntry(key: name, value: member) in byName.entries) {
    if (member == value) return name;
  }
  return null;
}

/// The sides of insets as text: a number for each side named, and whether
/// they follow the reading direction.
final class _Insets._(
  final Map<String, double> _sides, {
  required final bool isDirectional,
}) {
  factory parse(String text, {bool directional = false}) {
    final words = text.trim().split(RegExp(r'\s+'));
    final numbers = words.map(_side).toList();
    if (numbers.every((number) => number != null)) {
      final values = numbers.nonNulls.toList();
      final (start, end) = directional ? ('start', 'end') : ('left', 'right');
      return switch (values) {
        [final all] => ._({
          'top': all,
          'bottom': all,
          start: all,
          end: all,
        }, isDirectional: directional),
        [final vertical, final horizontal] => ._({
          'top': vertical,
          'bottom': vertical,
          start: horizontal,
          end: horizontal,
        }, isDirectional: directional),
        _ => throw FormatException(_help(text)),
      };
    }
    if (words.length.isOdd) throw FormatException(_help(text));
    final sides = <String, double>{};
    for (var index = 0; index < words.length; index += 2) {
      final side = words[index];
      final value = _side(words[index + 1]);
      if (!_names.contains(side) || value == null) {
        throw FormatException(_help(text));
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
    final namesDirection = physical || relative;
    return ._(sides, isDirectional: namesDirection ? relative : directional);
  }

  factory physical(EdgeInsets insets) => .written(insets, {
    'top': insets.top,
    'bottom': insets.bottom,
    'left': insets.left,
    'right': insets.right,
  }, isDirectional: false);

  factory directional(EdgeInsetsDirectional insets) => .written(insets, {
    'top': insets.top,
    'bottom': insets.bottom,
    'start': insets.start,
    'end': insets.end,
  }, isDirectional: true);

  factory written(
    EdgeInsetsGeometry insets,
    Map<String, double> sides, {
    required bool isDirectional,
  }) {
    if (sides.values.every(_isSide)) {
      return ._(sides, isDirectional: isDirectional);
    }
    throw ArgumentError.value(
      insets,
      'object',
      'has a side below 0 or not finite',
    );
  }

  EdgeInsetsGeometry get geometry => isDirectional
      ? EdgeInsetsDirectional.only(
          top: _sideOf('top'),
          bottom: _sideOf('bottom'),
          start: _sideOf('start'),
          end: _sideOf('end'),
        )
      : EdgeInsets.only(
          top: _sideOf('top'),
          bottom: _sideOf('bottom'),
          left: _sideOf('left'),
          right: _sideOf('right'),
        );

  String get text {
    final sides = [
      for (final MapEntry(key: side, :value) in _sides.entries)
        if (value != 0) '$side ${_number(value)}',
    ];
    // Without start or end, EdgeInsetsGeometryConverter would read EdgeInsets.
    if (isDirectional && _sideOf('start') == 0 && _sideOf('end') == 0) {
      sides.add('start 0');
    }
    return sides.isEmpty ? '0' : sides.join(' ');
  }

  double _sideOf(String name) => _sides[name] ?? 0;

  static double? _side(String word) => switch (double.tryParse(word)) {
    final value? when _isSide(value) => value,
    _ => null,
  };

  /// A side's logical pixels: a finite number, not below 0.
  static bool _isSide(double value) => value.isFinite && value >= 0;

  static String _number(double value) =>
      '$value'.replaceFirst(RegExp(r'\.0$'), '');

  static String _help(String text) =>
      'Write one number, two, or sides by name, as "top 8 start 16"; '
      'not "$text".';

  static const _names = {'top', 'bottom', 'left', 'right', 'start', 'end'};
}
