import 'package:flutter/material.dart';
import 'package:waypoint_design_system/l10n/wp_localizations.dart';
import 'package:waypoint_design_system/src/atoms/wp_text_field.dart';
import 'package:waypoint_design_system/src/foundations/wp_colors.dart';

final class const WPComposer({
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
    final l10n = WPLocalizations.of(context);
    final (IconData icon, VoidCallback? onPressed, String label) = working
        ? (Icons.stop_rounded, onStop, l10n.stop)
        : (Icons.arrow_upward_rounded, onSend, l10n.send);
    return WPTextField(
      controller: controller,
      hint: hint,
      textInputAction: .send,
      onEditingComplete: onSend,
      trailing: Tooltip(
        message: label,
        child: Material(
          color: onPressed == null ? WPColors.raised : WPColors.ink,
          borderRadius: const BorderRadius.all(Radius.circular(8)),
          child: InkWell(
            onTap: onPressed,
            borderRadius: const BorderRadius.all(Radius.circular(8)),
            child: SizedBox.square(
              dimension: 36,
              child: Icon(
                icon,
                size: 20,
                color: onPressed == null ? WPColors.muted : WPColors.bg,
              ),
            ),
          ),
        ),
      ),
    );
  }
}
