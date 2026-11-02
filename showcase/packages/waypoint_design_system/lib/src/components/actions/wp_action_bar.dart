import 'package:flutter/material.dart';
import 'package:waypoint_design_system/src/components/layout/wp_readable.dart';
import 'package:waypoint_design_system/src/foundations/wp_colors.dart';

final class const WPActionBar({
  super.key,
  required final Widget child,

  final bool active = false,
  final double gutter = 20,

  final bool includeBottomInset = true,
}) extends StatelessWidget {
  @override
  Widget build(BuildContext context) => DecoratedBox(
    decoration: BoxDecoration(
      color: WPColors.surface,
      border: Border(
        top: BorderSide(color: active ? WPColors.ai : WPColors.line),
      ),
    ),
    child: Padding(
      padding: .fromLTRB(
        gutter,
        14,
        gutter,
        14 + (includeBottomInset ? MediaQuery.paddingOf(context).bottom : 0),
      ),
      child: WPReadable(child: child),
    ),
  );
}
