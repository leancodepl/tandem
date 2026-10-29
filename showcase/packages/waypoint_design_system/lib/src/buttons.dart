import 'package:flutter/material.dart';
import 'package:waypoint_design_system/l10n/design_system_localizations.dart';
import 'package:waypoint_design_system/src/theme.dart';

/// The app's one primary and one secondary button.
final class const WaypointButton(
  final String label, {
  super.key,
  final VoidCallback? onPressed,
  final bool primary = true,
  final bool small = false,
  final IconData? icon,

  /// An action the traveller started runs. The agent at work on the screen
  /// shows in a `WorkStatus` instead.
  final bool busy = false,
}) extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final enabled = onPressed != null && !busy;
    final foreground = primary ? Palette.bg : Palette.ink;
    return Semantics(
      button: true,
      enabled: enabled,
      child: Material(
        color: primary
            ? (enabled || busy ? Palette.ink : Palette.raised)
            : Colors.transparent,
        shape: RoundedRectangleBorder(
          borderRadius: Radii.control,
          side: primary
              ? BorderSide.none
              : const BorderSide(color: Palette.lineStrong),
        ),
        clipBehavior: .antiAlias,
        child: InkWell(
          onTap: enabled ? onPressed : null,
          child: SizedBox(
            height: small ? 38 : 48,
            child: Padding(
              padding: .symmetric(horizontal: small ? 14 : 18),
              child: Row(
                mainAxisSize: .min,
                mainAxisAlignment: .center,
                spacing: 8,
                children: [
                  if (busy)
                    SizedBox.square(
                      dimension: 14,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: foreground,
                      ),
                    )
                  else if (icon case final icon?)
                    Icon(icon, size: 18, color: foreground),
                  Text(
                    label,
                    style: AppText.button.copyWith(
                      color: enabled || busy ? foreground : Palette.muted,
                      fontSize: small ? 14 : 15,
                    ),
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

/// A button that is only its label, for a small action inside a row.
final class const WaypointTextButton(
  final String label, {
  super.key,
  final VoidCallback? onPressed,
}) extends StatelessWidget {
  @override
  Widget build(BuildContext context) => TextButton(
    onPressed: onPressed,
    style: TextButton.styleFrom(
      foregroundColor: Palette.ink,
      textStyle: AppText.label,
    ),
    child: Text(label),
  );
}

/// Closes the sheet or dialog it is on.
final class const WaypointCloseButton({
  super.key,
  required final VoidCallback onPressed,
}) extends StatelessWidget {
  @override
  Widget build(BuildContext context) => IconButton(
    tooltip: DesignSystemLocalizations.of(context).close,
    onPressed: onPressed,
    icon: const Icon(Icons.close_rounded, color: Palette.muted),
  );
}

/// Goes back to the page before.
final class const WaypointBackButton({
  super.key,
  required final VoidCallback onPressed,
}) extends StatelessWidget {
  @override
  Widget build(BuildContext context) => IconButton(
    tooltip: DesignSystemLocalizations.of(context).back,
    onPressed: onPressed,
    icon: const Icon(Icons.arrow_back_rounded, color: Palette.ink),
  );
}
