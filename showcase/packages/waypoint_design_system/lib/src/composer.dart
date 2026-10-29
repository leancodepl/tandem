import 'package:flutter/material.dart';
import 'package:waypoint_design_system/l10n/design_system_localizations.dart';
import 'package:waypoint_design_system/src/text_field.dart';
import 'package:waypoint_design_system/src/theme.dart';

/// The field to write to the assistant, with Send, or Stop while it works.
final class const WaypointComposer({
  super.key,
  required final TextEditingController controller,
  required final String hint,
  required final bool working,
  required final VoidCallback onSend,

  /// Null while the work cannot be stopped.
  final VoidCallback? onStop,
}) extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final l10n = DesignSystemLocalizations.of(context);
    final (IconData icon, VoidCallback? onPressed, String label) = working
        ? (Icons.stop_rounded, onStop, l10n.stop)
        : (Icons.arrow_upward_rounded, onSend, l10n.send);
    return WaypointTextField(
      controller: controller,
      hint: hint,
      textInputAction: .send,
      onEditingComplete: onSend,
      trailing: Tooltip(
        message: label,
        child: Material(
          color: onPressed == null ? Palette.raised : Palette.ink,
          borderRadius: const BorderRadius.all(Radius.circular(8)),
          child: InkWell(
            onTap: onPressed,
            borderRadius: const BorderRadius.all(Radius.circular(8)),
            child: SizedBox.square(
              dimension: 36,
              child: Icon(
                icon,
                size: 20,
                color: onPressed == null ? Palette.muted : Palette.bg,
              ),
            ),
          ),
        ),
      ),
    );
  }
}
