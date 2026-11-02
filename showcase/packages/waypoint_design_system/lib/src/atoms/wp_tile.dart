import 'package:flutter/material.dart';
import 'package:waypoint_design_system/src/foundations/wp_colors.dart';
import 'package:waypoint_design_system/src/foundations/wp_text_style.dart';

final class const WPTile({
  super.key,
  required final String title,
  final String? subtitle,
  final IconData? icon,
  final Widget? trailing,

  final bool dimmed = false,
}) extends StatelessWidget {
  @override
  Widget build(BuildContext context) => Row(
    spacing: 12,
    children: [
      if (icon case final icon?) Icon(icon, color: WPColors.muted),
      Expanded(
        child: Column(
          crossAxisAlignment: .start,
          spacing: 2,
          children: [
            Text(
              title,
              style: WPTextStyle.body.copyWith(
                color: dimmed ? WPColors.muted : WPColors.ink,
              ),
            ),
            if (subtitle case final subtitle?)
              Text(subtitle, style: WPTextStyle.label),
          ],
        ),
      ),
      ?trailing,
    ],
  );
}
