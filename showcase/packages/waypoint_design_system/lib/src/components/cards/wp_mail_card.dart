import 'package:flutter/material.dart';
import 'package:waypoint_design_system/src/atoms/wp_card.dart';
import 'package:waypoint_design_system/src/foundations/wp_colors.dart';
import 'package:waypoint_design_system/src/foundations/wp_text_style.dart';

final class const WPMailCard({
  super.key,
  required final String from,
  required final String subject,
  final Widget? trailing,
  final bool selected = false,
  final VoidCallback? onTap,
}) extends StatelessWidget {
  @override
  Widget build(BuildContext context) => WPCard(
    onTap: onTap,
    border: selected ? WPColors.ink : WPColors.lineStrong,
    padding: const .fromLTRB(14, 12, 14, 12),
    child: Row(
      spacing: 12,
      children: [
        const Icon(Icons.mail_outline_rounded, size: 20, color: WPColors.muted),
        Expanded(
          child: Column(
            crossAxisAlignment: .start,
            spacing: 2,
            children: [
              Text(from, style: WPTextStyle.title.copyWith(fontSize: 15)),
              Text(
                subject,
                maxLines: 1,
                overflow: .ellipsis,
                style: WPTextStyle.label,
              ),
            ],
          ),
        ),
        ?trailing,
      ],
    ),
  );
}
