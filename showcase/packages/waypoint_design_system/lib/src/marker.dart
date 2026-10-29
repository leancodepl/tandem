import 'package:flutter/widgets.dart';
import 'package:waypoint_design_system/src/theme.dart';

/// The blue bar at the left edge of what the assistant filled in or
/// changed. It grows in when [marked] and out when not.
final class const Marker({super.key, required final bool marked})
    extends StatelessWidget {
  @override
  Widget build(BuildContext context) => AnimatedContainer(
    duration: const Duration(milliseconds: 360),
    curve: Curves.easeOutCubic,
    width: marked ? 3 : 0,
    decoration: const BoxDecoration(
      color: Palette.ai,
      borderRadius: BorderRadius.horizontal(right: Radius.circular(2)),
    ),
  );
}
