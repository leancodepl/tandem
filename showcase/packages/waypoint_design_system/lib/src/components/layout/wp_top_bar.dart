import 'package:flutter/material.dart';
import 'package:waypoint_design_system/src/atoms/wp_buttons.dart';
import 'package:waypoint_design_system/src/foundations/wp_text_style.dart';

final class const WPTopBar({
  super.key,
  required final VoidCallback onBack,
  final String? title,
  final String? trailing,

  final bool wide = false,
}) extends StatelessWidget {
  @override
  Widget build(BuildContext context) => SafeArea(
    bottom: false,
    child: Padding(
      padding: .fromLTRB(wide ? 24 : 8, 4, wide ? 36 : 20, 4),
      child: Row(
        spacing: 8,
        children: [
          WPBackButton(onPressed: onBack),
          if (title case final title?)
            Flexible(child: Text(title, style: WPTextStyle.title)),
          if (trailing case final trailing?)
            Expanded(
              child: Text(
                trailing,
                textAlign: .end,
                maxLines: 1,
                overflow: .ellipsis,
                style: WPTextStyle.label,
              ),
            ),
        ],
      ),
    ),
  );
}
