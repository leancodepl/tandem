import 'package:flutter/material.dart';
import 'package:waypoint_design_system/src/foundations/wp_colors.dart';

final class const WPDivider({
  super.key,
  final bool vertical = false,
  final Color color = WPColors.line,
}) extends StatelessWidget {
  @override
  Widget build(BuildContext context) => vertical
      ? VerticalDivider(width: 1, color: color)
      : Divider(height: 1, color: color);
}
