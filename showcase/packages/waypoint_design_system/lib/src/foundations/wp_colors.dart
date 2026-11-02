import 'package:flutter/material.dart';

/// Waypoint is neutral; the blue marks only what the assistant did.
abstract final class WPColors() {
  static const bg = Color(0xFF0D1015);
  static const panel = Color(0xFF11151B);
  static const surface = Color(0xFF151A21);
  static const raised = Color(0xFF1D242D);
  static const line = Color(0xFF232A33);
  static const lineStrong = Color(0xFF353E4A);
  static const ink = Color(0xFFF1EEE8);
  static const muted = Color(0xFF98A0AA);

  /// Tandem's blue, the site's accent: the assistant's marks.
  static const ai = Color(0xFF0187FD);

  /// The border of a card the assistant changed: [line] 70 % of the way to
  /// [ai].
  static const aiLine = Color(0xFF0B6BC0);

  /// The assistant's blue for text on the dark surfaces.
  static const aiText = Color(0xFF4AA8FF);
  static const warn = Color(0xFFE5A94A);

  static const scrim = Color(0xB3000000);
}
