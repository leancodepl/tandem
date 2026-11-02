import 'package:flutter/material.dart';
import 'package:waypoint_design_system/src/atoms/wp_card.dart';
import 'package:waypoint_design_system/src/foundations/wp_colors.dart';
import 'package:waypoint_design_system/src/foundations/wp_text_style.dart';

final class const WPListCard({
  super.key,
  required final String title,
  required final String subtitle,
  required final String caption,
  final List<Widget> footer = const [],
  final Color border = WPColors.line,
  required final VoidCallback onTap,
}) extends StatelessWidget {
  @override
  Widget build(BuildContext context) => WPCard(
    onTap: onTap,
    border: border,
    padding: const .fromLTRB(16, 14, 12, 16),
    child: Row(
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: .start,
            spacing: 4,
            children: [
              Text(title, style: WPTextStyle.cardTitle),
              Text(subtitle, style: WPTextStyle.body),
              Text(caption, style: WPTextStyle.label),
              if (footer.isNotEmpty) ...[const SizedBox(height: 6), ...footer],
            ],
          ),
        ),
        const Icon(Icons.chevron_right_rounded, color: WPColors.muted),
      ],
    ),
  );
}
