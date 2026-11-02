import 'package:flutter/material.dart';
import 'package:waypoint_design_system/src/foundations/wp_colors.dart';

final class const WPDividedColumn({
  super.key,
  required final bool first,
  required final Widget child,
}) extends StatelessWidget {
  @override
  Widget build(BuildContext context) => DecoratedBox(
    decoration: BoxDecoration(
      border: first
          ? null
          : const Border(left: BorderSide(color: WPColors.line)),
    ),
    child: child,
  );
}
