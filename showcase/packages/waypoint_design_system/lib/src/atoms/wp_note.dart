import 'package:flutter/widgets.dart';
import 'package:waypoint_design_system/src/foundations/wp_colors.dart';
import 'package:waypoint_design_system/src/foundations/wp_text_style.dart';

final class const WPNote(
  final IconData icon,
  final String text, {
  super.key,
  final WPNoteTone tone = .muted,

  final int? maxLines,
}) extends StatelessWidget {
  @override
  Widget build(BuildContext context) => Row(
    mainAxisSize: .min,
    crossAxisAlignment: .start,
    spacing: 8,
    children: [
      Padding(
        padding: const .only(top: 1),
        child: Icon(icon, size: 16, color: tone.icon),
      ),
      Flexible(
        child: Text(
          text,
          maxLines: maxLines,
          overflow: maxLines == null ? null : .ellipsis,
          style: WPTextStyle.label.copyWith(color: tone.text),
        ),
      ),
    ],
  );
}

enum WPNoteTone(final Color icon, final Color text) {
  muted(WPColors.muted, WPColors.muted),

  ai(WPColors.aiText, WPColors.aiText),

  done(WPColors.aiText, WPColors.ink),
  warn(WPColors.warn, WPColors.warn),
}
