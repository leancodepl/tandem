import 'dart:ui' show ColorSpace;

import 'package:flutter/painting.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:json_annotation/json_annotation.dart';
import 'package:tandem/tandem.dart';

void main() {
  test('a color reads back what it writes, with or without alpha', () {
    _expectReadsBack(const ColorConverter(), const [
      Color(0xFF1E88E5),
      Color(0x801E88E5),
      Color(0x00000000),
      Color(0xFFFFFFFF),
    ]);

    const p3 = Color.from(
      alpha: 1,
      red: .5,
      green: .4,
      blue: .3,
      colorSpace: .displayP3,
    );
    final srgb = p3.withValues(colorSpace: .sRGB);
    final read = const ColorConverter().fromJson(
      const ColorConverter().toJson(p3),
    );

    expect(read.colorSpace, ColorSpace.sRGB);
    for (final (channel, expected) in [
      (read.r, srgb.r),
      (read.g, srgb.g),
      (read.b, srgb.b),
      (read.a, srgb.a),
    ]) {
      expect(channel, closeTo(expected, .5 / 255));
    }
  });

  test('insets read back what they write, with their direction', () {
    const physical = <EdgeInsets>[
      .zero,
      .all(16),
      .symmetric(vertical: 8, horizontal: 16),
      .only(top: 8),
      .only(bottom: 4),
      .symmetric(vertical: 8),
      .only(left: 16),
      .symmetric(horizontal: 16),
      .fromLTRB(2, 1.5, 3, 0),
      .all(1e21),
    ];
    const directional = <EdgeInsetsDirectional>[
      .zero,
      .all(16),
      .symmetric(vertical: 8, horizontal: 16),
      .only(top: 8),
      .only(bottom: 4),
      .symmetric(vertical: 8),
      .only(start: 16),
      .symmetric(horizontal: 16),
      .fromSTEB(2, 1.5, 3, 0),
      .all(1e21),
    ];

    _expectReadsBack(const EdgeInsetsConverter(), physical);
    _expectReadsBack(const EdgeInsetsDirectionalConverter(), directional);
    _expectReadsBack(const EdgeInsetsGeometryConverter(), <EdgeInsetsGeometry>[
      ...physical,
      ...directional,
    ]);
  });

  test('insets keep the requested direction when no side names one', () {
    for (final json in ['0', '8 16', 'top 8', 'bottom 4']) {
      expect(
        const EdgeInsetsDirectionalConverter().fromJson(json),
        isA<EdgeInsetsDirectional>(),
        reason: json,
      );
      expect(
        const EdgeInsetsConverter().fromJson(json),
        isA<EdgeInsets>(),
        reason: json,
      );
      expect(
        const EdgeInsetsGeometryConverter().fromJson(json),
        isA<EdgeInsets>(),
        reason: json,
      );
    }
    expect(
      const EdgeInsetsGeometryConverter().fromJson('top 8 start 0'),
      const EdgeInsetsDirectional.only(top: 8),
    );
  });

  test('an alignment reads back what it writes', () {
    const physical = <Alignment>[
      .topLeft,
      .topCenter,
      .topRight,
      .centerLeft,
      .center,
      .centerRight,
      .bottomLeft,
      .bottomCenter,
      .bottomRight,
    ];
    const directional = <AlignmentDirectional>[
      .topStart,
      .topCenter,
      .topEnd,
      .centerStart,
      .center,
      .centerEnd,
      .bottomStart,
      .bottomCenter,
      .bottomEnd,
    ];
    const directionalCenters = <AlignmentDirectional>[
      .topCenter,
      .center,
      .bottomCenter,
    ];

    _expectReadsBack(const AlignmentConverter(), physical);
    _expectReadsBack(const AlignmentDirectionalConverter(), directional);
    _expectReadsBack(const AlignmentGeometryConverter(), <AlignmentGeometry>[
      ...physical,
      ...directional.where((value) => !directionalCenters.contains(value)),
    ]);
    for (final center in directionalCenters) {
      const converter = AlignmentGeometryConverter();
      expect(converter.fromJson(converter.toJson(center)), center);
    }
  });

  test('a converter refuses what it cannot read or write', () {
    final unreadable = <(Object? Function(String), String)>[
      for (final json in ['', '1e88e5', '#fff', '#1e88e5f', '#gggggg'])
        (const ColorConverter().fromJson, json),
      for (final read in [
        const EdgeInsetsGeometryConverter().fromJson,
        const EdgeInsetsConverter().fromJson,
        const EdgeInsetsDirectionalConverter().fromJson,
      ])
        for (final json in [
          '',
          '8 16 4',
          '-4',
          'Infinity',
          'NaN',
          'top',
          'top x',
          'middle 8',
          'left 4 start 4',
        ])
          (read, json),
      (const EdgeInsetsConverter().fromJson, 'start 8'),
      (const EdgeInsetsDirectionalConverter().fromJson, 'left 4'),
      for (final read in [
        const AlignmentGeometryConverter().fromJson,
        const AlignmentConverter().fromJson,
        const AlignmentDirectionalConverter().fromJson,
      ])
        for (final json in ['', 'top', 'TopLeft']) (read, json),
      (const AlignmentConverter().fromJson, 'topStart'),
      (const AlignmentDirectionalConverter().fromJson, 'topLeft'),
    ];
    final unwritable = <String Function()>[
      () => const EdgeInsetsGeometryConverter().toJson(
        const EdgeInsets.only(left: 4)
            .add(const EdgeInsetsDirectional.only(start: 4)),
      ),
      () => const EdgeInsetsConverter().toJson(const .only(top: -4)),
      () => const EdgeInsetsConverter().toJson(const .all(.infinity)),
      () => const EdgeInsetsDirectionalConverter().toJson(const .only(end: -4)),
      () => const AlignmentConverter().toJson(const Alignment(.3, .2)),
    ];

    for (final (read, json) in unreadable) {
      expect(() => read(json), throwsFormatException, reason: json);
    }
    for (final write in unwritable) {
      expect(write, throwsArgumentError);
    }
  });
}

void _expectReadsBack<T>(JsonConverter<T, String> converter, List<T> values) {
  for (final value in values) {
    final json = converter.toJson(value);
    final read = converter.fromJson(json);
    expect((read, read.runtimeType), (value, value.runtimeType), reason: json);
  }
}
