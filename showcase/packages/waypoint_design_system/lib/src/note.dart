import 'package:flutter/widgets.dart';
import 'package:waypoint_design_system/src/theme.dart';

/// A short line with an icon, such as a warning or what is done.
final class const WaypointNote(
  final IconData icon,
  final String text, {
  super.key,
  final NoteTone tone = .muted,

  /// Cuts the text with an ellipsis after this many lines.
  final int? maxLines,
}) extends StatelessWidget {
  @override
  Widget build(BuildContext context) => Row(
    crossAxisAlignment: .start,
    spacing: 8,
    children: [
      Padding(
        padding: const .only(top: 1),
        child: Icon(icon, size: 16, color: tone.icon),
      ),
      Expanded(
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

  /// What the assistant brings up.
  ai(Palette.aiText, Palette.aiText),

  /// A step the assistant did.
  done(Palette.aiText, Palette.ink),
  warn(Palette.warn, Palette.warn),
}
