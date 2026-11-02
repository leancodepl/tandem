import 'package:flutter/widgets.dart';
import 'package:waypoint_design_system/src/foundations/wp_colors.dart';

final class const WPMarker({super.key, required final bool marked})
    extends StatelessWidget {
  @override
  Widget build(BuildContext context) => AnimatedContainer(
    duration: const Duration(milliseconds: 360),
    curve: Curves.easeOutCubic,
    width: marked ? 3 : 0,
    decoration: const BoxDecoration(
      color: WPColors.ai,
      borderRadius: BorderRadius.horizontal(right: Radius.circular(2)),
    ),
  );
}
