import 'package:flutter/widgets.dart';
import 'package:waypoint_design_system/src/theme.dart';

/// What the traveller wrote to the assistant, on the right of the thread.
final class const WaypointBubble(final String text, {super.key})
    extends StatelessWidget {
  @override
  Widget build(BuildContext context) => Align(
    alignment: .centerRight,
    child: ConstrainedBox(
      constraints: const BoxConstraints(maxWidth: 300),
      child: DecoratedBox(
        decoration: const BoxDecoration(
          color: Palette.raised,
          borderRadius: BorderRadius.only(
            topLeft: Radius.circular(10),
            topRight: Radius.circular(10),
            bottomLeft: Radius.circular(10),
            bottomRight: Radius.circular(3),
          ),
        ),
        child: Padding(
          padding: const .symmetric(horizontal: 14, vertical: 10),
          child: Text(text, style: AppText.body),
        ),
      ),
    ),
  );
}

/// A blue dot next to what waits for the traveller.
final class const WaypointDot({super.key}) extends StatelessWidget {
  @override
  Widget build(BuildContext context) => const DecoratedBox(
    decoration: BoxDecoration(color: Palette.ai, shape: BoxShape.circle),
    child: SizedBox.square(dimension: 7),
  );
}
