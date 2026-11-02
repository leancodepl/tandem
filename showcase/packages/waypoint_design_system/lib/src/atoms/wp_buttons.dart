import 'package:flutter/material.dart';
import 'package:waypoint_design_system/l10n/wp_localizations.dart';
import 'package:waypoint_design_system/src/foundations/wp_colors.dart';
import 'package:waypoint_design_system/src/foundations/wp_radii.dart';
import 'package:waypoint_design_system/src/foundations/wp_text_style.dart';

final class const WPButton(
  final String label, {
  super.key,
  final VoidCallback? onPressed,
  final bool primary = true,
  final bool small = false,
  final IconData? icon,

  /// An action the traveller started runs. The agent at work on the screen
  /// shows in a `WPWorkStatus` instead.
  final bool busy = false,
}) extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final enabled = onPressed != null && !busy;
    final foreground = primary ? WPColors.bg : WPColors.ink;
    return Semantics(
      button: true,
      enabled: enabled,
      child: Material(
        color: primary
            ? (enabled || busy ? WPColors.ink : WPColors.raised)
            : Colors.transparent,
        shape: RoundedRectangleBorder(
          borderRadius: WPRadii.control,
          side: primary
              ? BorderSide.none
              : const BorderSide(color: WPColors.lineStrong),
        ),
        clipBehavior: .antiAlias,
        child: InkWell(
          onTap: enabled ? onPressed : null,
          child: ConstrainedBox(
            constraints: BoxConstraints(minHeight: small ? 38 : 48),
            child: Padding(
              padding: .symmetric(horizontal: small ? 14 : 18, vertical: 8),
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
                  Flexible(
                    child: Text(
                      label,
                      textAlign: .center,
                      style: WPTextStyle.button.copyWith(
                        color: enabled || busy ? foreground : WPColors.muted,
                        fontSize: small ? 14 : 15,
                      ),
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

final class const WPTextButton(
  final String label, {
  super.key,
  final VoidCallback? onPressed,
}) extends StatelessWidget {
  @override
  Widget build(BuildContext context) => TextButton(
    onPressed: onPressed,
    style: TextButton.styleFrom(
      foregroundColor: WPColors.ink,
      textStyle: WPTextStyle.label,
    ),
    child: Text(label),
  );
}

final class const WPCloseButton({
  super.key,
  required final VoidCallback onPressed,
}) extends StatelessWidget {
  @override
  Widget build(BuildContext context) => IconButton(
    tooltip: WPLocalizations.of(context).close,
    onPressed: onPressed,
    icon: const Icon(Icons.close_rounded, color: WPColors.muted),
  );
}

final class const WPBackButton({
  super.key,
  required final VoidCallback onPressed,
}) extends StatelessWidget {
  @override
  Widget build(BuildContext context) => IconButton(
    tooltip: WPLocalizations.of(context).back,
    onPressed: onPressed,
    icon: const Icon(Icons.arrow_back_rounded, color: WPColors.ink),
  );
}
