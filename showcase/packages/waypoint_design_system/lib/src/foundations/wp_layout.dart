import 'package:flutter/widgets.dart';

abstract final class WPWidths() {
  static const tablet = 600.0;
  static const readable = 760.0;
  static const wide = 900.0;
  static const sidePanel = 385.0;
}

extension WPLayout on BuildContext {
  bool get isTablet => MediaQuery.sizeOf(this).shortestSide >= WPWidths.tablet;
}
