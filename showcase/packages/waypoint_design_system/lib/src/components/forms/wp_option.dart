import 'package:flutter/material.dart';
import 'package:waypoint_design_system/src/foundations/wp_colors.dart';
import 'package:waypoint_design_system/src/foundations/wp_text_style.dart';

final class const WPOption({
  super.key,
  required final String lead,
  required final String label,
  required final String trailing,
  required final bool selected,
  final VoidCallback? onTap,
}) extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final color = onTap == null ? WPColors.muted : WPColors.ink;
    return Material(
      color: selected ? WPColors.raised : Colors.transparent,
      // Without onTap the option still takes the tap, so that a card around
      // the group does not.
      child: GestureDetector(
        onTap: () {},
        excludeFromSemantics: true,
        child: InkWell(
          onTap: onTap,
          child: ConstrainedBox(
            constraints: const BoxConstraints(minHeight: 44),
            child: Padding(
              padding: const .symmetric(horizontal: 12, vertical: 8),
              child: Row(
                spacing: 10,
                children: [
                  Text(
                    lead,
                    style: WPTextStyle.body.copyWith(
                      color: color,
                      fontWeight: selected ? FontWeight.w600 : FontWeight.w500,
                    ),
                  ),
                  Expanded(
                    child: Text(
                      label,
                      style: WPTextStyle.label,
                      overflow: .ellipsis,
                    ),
                  ),
                  Text(
                    trailing,
                    style: WPTextStyle.body.copyWith(color: color),
                  ),
                  SizedBox(
                    width: 18,
                    child: selected
                        ? const Icon(
                            Icons.check_rounded,
                            size: 18,
                            color: WPColors.ink,
                          )
                        : null,
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
