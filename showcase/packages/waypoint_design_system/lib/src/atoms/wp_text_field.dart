import 'package:flutter/material.dart';
import 'package:waypoint_design_system/src/foundations/wp_colors.dart';
import 'package:waypoint_design_system/src/foundations/wp_radii.dart';
import 'package:waypoint_design_system/src/foundations/wp_text_style.dart';

final class const WPTextField({
  super.key,
  required final TextEditingController controller,
  required final String hint,
  final int minLines = 1,
  final int maxLines = 4,
  final TextInputAction? textInputAction,
  final VoidCallback? onEditingComplete,
  final Widget? trailing,
}) extends StatelessWidget {
  @override
  Widget build(BuildContext context) => DecoratedBox(
    decoration: BoxDecoration(
      color: WPColors.bg,
      border: Border.all(color: WPColors.lineStrong),
      borderRadius: WPRadii.control,
    ),
    child: Row(
      crossAxisAlignment: .end,
      children: [
        Expanded(
          child: TextField(
            controller: controller,
            style: WPTextStyle.body,
            minLines: minLines,
            maxLines: maxLines,
            textInputAction: textInputAction,
            autocorrect: false,
            enableSuggestions: false,
            onEditingComplete: onEditingComplete,
            decoration: InputDecoration(
              hintText: hint,
              hintStyle: const TextStyle(color: WPColors.muted),
              border: InputBorder.none,
              isDense: true,
              contentPadding: const .fromLTRB(14, 14, 8, 14),
            ),
          ),
        ),
        if (trailing case final trailing?)
          Padding(padding: const .all(6), child: trailing),
      ],
    ),
  );
}
