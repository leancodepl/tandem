import 'package:flutter/widgets.dart';

/// A text that slides up into place when it changes.
final class const WPSwapText(
  final String text, {
  super.key,
  required final TextStyle style,
}) extends StatelessWidget {
  @override
  Widget build(BuildContext context) => AnimatedSwitcher(
    duration: const Duration(milliseconds: 420),
    switchInCurve: Curves.easeOutCubic,
    switchOutCurve: Curves.easeInCubic,
    layoutBuilder: (current, previous) =>
        Stack(alignment: .centerLeft, children: [...previous, ?current]),
    transitionBuilder: (child, animation) => FadeTransition(
      opacity: animation,
      child: SlideTransition(
        position: Tween(
          begin: Offset(0, child.key == ValueKey(text) ? .5 : -.5),
          end: Offset.zero,
        ).animate(animation),
        child: child,
      ),
    ),
    child: Text(text, key: ValueKey(text), style: style),
  );
}
