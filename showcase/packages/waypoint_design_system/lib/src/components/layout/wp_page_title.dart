import 'package:flutter/material.dart';
import 'package:waypoint_design_system/src/foundations/wp_colors.dart';
import 'package:waypoint_design_system/src/foundations/wp_text_style.dart';

final class const WPPageTitle(
  final String title, {
  super.key,
  final String? above,
  final String? below,
  final Widget? trailing,
}) extends StatelessWidget {
  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: .stretch,
    children: [
      if (above case final above?) ...[
        Text(above, style: WPTextStyle.label),
        const SizedBox(height: 4),
      ],
      OverflowBar(
        alignment: .spaceBetween,
        overflowSpacing: 12,
        spacing: 16,
        children: [
          Text(title, style: WPTextStyle.headline),
          if (trailing case final trailing?)
            Padding(padding: const .only(bottom: 10), child: trailing),
        ],
      ),
      if (below case final below?)
        Text(below, style: WPTextStyle.body.copyWith(color: WPColors.muted)),
    ],
  );
}
