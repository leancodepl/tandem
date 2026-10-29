import 'package:flutter/material.dart';
import 'package:waypoint_design_system/l10n/design_system_localizations.dart';
import 'package:waypoint_design_system/src/buttons.dart';
import 'package:waypoint_design_system/src/note.dart';
import 'package:waypoint_design_system/src/page.dart';
import 'package:waypoint_design_system/src/theme.dart';

/// A page that cannot show what it was opened for, with a way out that
/// works without a page to go back to.
final class const ErrorView(
  final String message, {
  super.key,

  /// Where [onBack] takes the traveller, such as "Your trips".
  required final String back,
  required final VoidCallback onBack,
}) extends StatelessWidget {
  @override
  Widget build(BuildContext context) => WaypointPage(
    child: SafeArea(
      child: Center(
        child: Padding(
          padding: const .symmetric(horizontal: 24),
          child: Column(
            mainAxisSize: .min,
            spacing: 16,
            children: [
              Text(message, textAlign: .center, style: AppText.title),
              WaypointButton(back, onPressed: onBack),
            ],
          ),
        ),
      ),
    ),
  );
}

/// What went wrong on part of a screen, in place of its `WorkStatus` or as
/// a line of the chat, with a way to try again.
final class const InlineError(
  final String message, {
  super.key,
  final VoidCallback? onRetry,
}) extends StatelessWidget {
  @override
  Widget build(BuildContext context) => Padding(
    padding: const .only(top: 14),
    child: Row(
      spacing: 8,
      children: [
        Expanded(
          child: WaypointNote(
            Icons.error_outline_rounded,
            message,
            tone: .warn,
          ),
        ),
        if (onRetry case final retry?)
          WaypointTextButton(
            DesignSystemLocalizations.of(context).tryAgain,
            onPressed: retry,
          ),
      ],
    ),
  );
}
