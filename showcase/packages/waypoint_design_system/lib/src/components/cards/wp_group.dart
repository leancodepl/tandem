import 'package:flutter/material.dart';
import 'package:waypoint_design_system/src/atoms/wp_divider.dart';
import 'package:waypoint_design_system/src/foundations/wp_colors.dart';
import 'package:waypoint_design_system/src/foundations/wp_radii.dart';

final class const WPGroup({
  super.key,
  required final List<Widget> children,

  /// Null for an outline only.
  final Color? color = WPColors.surface,
  final Color border = WPColors.line,
}) extends StatelessWidget {
  @override
  Widget build(BuildContext context) => DecoratedBox(
    decoration: BoxDecoration(
      color: color,
      border: Border.all(color: border),
      borderRadius: WPRadii.card,
    ),
    child: ClipRRect(
      borderRadius: WPRadii.card,
      child: Column(
        children: [
          for (final (index, child) in children.indexed) ...[
            if (index > 0) const WPDivider(),
            child,
          ],
        ],
      ),
    ),
  );
}
