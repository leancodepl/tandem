import 'package:flutter/widgets.dart';

/// The widths the screens change their layout at, and the width of a side
/// panel.
abstract final class Widths() {
  /// The shortest side of a tablet.
  static const tablet = 600.0;

  /// The widest a page's content reads well at, and the room a trip needs
  /// next to the assistant.
  static const readable = 760.0;

  /// A window with room around a form.
  static const wide = 900.0;

  static const sidePanel = 385.0;
}

extension Layout on BuildContext {
  /// A tablet in either orientation: the app keeps its side rail and opens
  /// forms as dialogs.
  bool get isTablet => MediaQuery.sizeOf(this).shortestSide >= Widths.tablet;
}

/// A page's content at a width that reads well, centred on a wide screen.
final class const Readable({super.key, required final Widget child})
    extends StatelessWidget {
  @override
  Widget build(BuildContext context) => Align(
    alignment: .topCenter,
    child: ConstrainedBox(
      constraints: const BoxConstraints(maxWidth: Widths.readable),
      child: child,
    ),
  );
}
