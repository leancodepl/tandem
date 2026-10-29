import 'package:flutter/painting.dart';

/// A text style of the kit, named for where it goes.
final class const KitStyle._(
  final double size, {
  final FontWeight weight = .w400,
}) {
  static const banner = KitStyle._(28, weight: .w800);
  static const heading = KitStyle._(22, weight: .w700);
  static const plain = KitStyle._(15);
  static const fine = KitStyle._(11);

  /// This style at [factor] times its size, for a user who reads large text.
  KitStyle scaled(double factor) => KitStyle._(size * factor, weight: weight);

  /// The style as a Flutter text takes it.
  TextStyle get text => TextStyle(fontSize: size, fontWeight: weight);
}
