import 'package:flutter/material.dart';
import 'package:waypoint_design_system/l10n/wp_localizations.dart';
import 'package:waypoint_design_system/src/atoms/wp_buttons.dart';
import 'package:waypoint_design_system/src/atoms/wp_note.dart';
import 'package:waypoint_design_system/src/components/layout/wp_page.dart';
import 'package:waypoint_design_system/src/foundations/wp_text_style.dart';

final class const WPErrorView(
  final String message, {
  super.key,

  /// Where [onBack] takes the traveller, such as "Your trips".
  required final String back,
  required final VoidCallback onBack,
}) extends StatelessWidget {
  @override
  Widget build(BuildContext context) => WPPage(
    child: SafeArea(
      child: Center(
        child: Padding(
          padding: const .symmetric(horizontal: 24),
          child: Column(
            mainAxisSize: .min,
            spacing: 16,
            children: [
              Text(message, textAlign: .center, style: WPTextStyle.title),
              WPButton(back, onPressed: onBack),
            ],
          ),
        ),
      ),
    ),
  );
}

final class const WPInlineError(
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
          child: WPNote(Icons.error_outline_rounded, message, tone: .warn),
        ),
        if (onRetry case final retry?)
          WPTextButton(WPLocalizations.of(context).tryAgain, onPressed: retry),
      ],
    ),
  );
}
