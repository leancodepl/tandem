import 'package:flutter/widgets.dart';
import 'package:waypoint_design_system/src/foundations/wp_colors.dart';

final class const WPDot({super.key}) extends StatelessWidget {
  @override
  Widget build(BuildContext context) => const DecoratedBox(
    decoration: BoxDecoration(color: WPColors.ai, shape: BoxShape.circle),
    child: SizedBox.square(dimension: 7),
  );
}
