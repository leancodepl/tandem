import 'package:flutter/material.dart';
import 'package:waypoint_design_system/src/atoms/wp_marker.dart';
import 'package:waypoint_design_system/src/foundations/wp_colors.dart';
import 'package:waypoint_design_system/src/foundations/wp_radii.dart';

final class const WPCard({
  super.key,
  required final Widget child,
  final VoidCallback? onTap,

  /// Null for an outline only.
  final Color? color = WPColors.surface,
  final Color border = WPColors.line,
  final EdgeInsetsGeometry padding = const .fromLTRB(16, 14, 16, 16),

  final bool marked = false,
}) extends StatelessWidget {
  @override
  Widget build(BuildContext context) => TweenAnimationBuilder(
    tween: ColorTween(end: marked ? WPColors.aiLine : border),
    duration: const Duration(milliseconds: 360),
    curve: Curves.easeOutCubic,
    // Over the content: it neither insets it nor hides under a tap's
    // highlight.
    builder: (context, shown, child) => DecoratedBox(
      position: .foreground,
      decoration: BoxDecoration(
        borderRadius: WPRadii.card,
        border: Border.all(color: shown ?? WPColors.line),
      ),
      child: child,
    ),
    child: Material(
      color: color ?? Colors.transparent,
      borderRadius: WPRadii.card,
      child: InkWell(
        onTap: onTap,
        borderRadius: WPRadii.card,
        child: Stack(
          children: [
            Padding(padding: padding, child: child),
            Positioned(
              left: 0,
              top: 12,
              bottom: 12,
              child: WPMarker(marked: marked),
            ),
          ],
        ),
      ),
    ),
  );
}
