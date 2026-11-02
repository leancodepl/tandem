import 'package:flutter/widgets.dart';

abstract final class WPWidths() {
  /// The shortest side of a tablet.
  static const tablet = 600.0;

  /// The widest a page's content reads well at, and the room a trip needs
  /// next to the assistant.
  static const readable = 760.0;

  /// A window with room around a form.
  static const wide = 900.0;

  static const sidePanel = 385.0;
}

extension WPLayout on BuildContext {
  /// A tablet in either orientation: the app keeps its side rail and opens
  /// forms as dialogs.
  bool get isTablet => MediaQuery.sizeOf(this).shortestSide >= WPWidths.tablet;
}
