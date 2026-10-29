import 'package:flutter/material.dart';
import 'package:waypoint_design_system/src/theme.dart';

/// A field to write in, with [trailing] such as its button at the end.
final class const WaypointTextField({
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
      color: Palette.bg,
      border: Border.all(color: Palette.lineStrong),
      borderRadius: Radii.control,
    ),
    child: Row(
      crossAxisAlignment: .end,
      children: [
        Expanded(
          child: TextField(
            controller: controller,
            style: AppText.body,
            minLines: minLines,
            maxLines: maxLines,
            textInputAction: textInputAction,
            autocorrect: false,
            enableSuggestions: false,
            onEditingComplete: onEditingComplete,
            decoration: InputDecoration(
              hintText: hint,
              hintStyle: const TextStyle(color: Palette.muted),
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
