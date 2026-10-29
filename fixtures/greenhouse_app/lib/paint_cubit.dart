import 'dart:ui';

import 'package:json_annotation/json_annotation.dart';
import 'package:tandem/tandem.dart';

part 'paint_cubit.g.dart';

/// A color as an ARGB number, as this app's backend writes it.
final class const ColorNumberConverter() implements JsonConverter<Color, int> {
  @override
  Color fromJson(int json) => Color(json);

  @override
  int toJson(Color object) => object.toARGB32();
}

/// A screen whose colors are numbers, unlike the design system's.
@TandemAgent(converters: [ColorNumberConverter()])
final class PaintCubit() with _$PaintCubit {
  @override
  List<AgentCapability> get agentCapabilities => [.sees(brand)];

  @override
  Stream<Object?> get changes => const Stream.empty();

  /// The brand color of the greenhouse.
  Color get brand => const Color(0xFF2E7D32);
}
