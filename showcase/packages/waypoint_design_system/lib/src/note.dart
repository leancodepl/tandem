import 'package:flutter/widgets.dart';
import 'package:waypoint_design_system/src/theme.dart';

final class const WaypointNote(
  final IconData icon,
  final String text, {
  super.key,
  final NoteTone tone = .muted,

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
          style: AppText.label.copyWith(color: tone.text),
        ),
      ),
    ],
  );
}

enum NoteTone(final Color icon, final Color text) {
  muted(Palette.muted, Palette.muted),

  ai(Palette.aiText, Palette.aiText),

  done(Palette.aiText, Palette.ink),
  warn(Palette.warn, Palette.warn),
}
