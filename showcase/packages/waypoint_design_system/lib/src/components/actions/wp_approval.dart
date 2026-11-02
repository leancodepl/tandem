import 'package:flutter/material.dart';
import 'package:waypoint_design_system/l10n/wp_localizations.dart';
import 'package:waypoint_design_system/src/atoms/wp_buttons.dart';
import 'package:waypoint_design_system/src/foundations/wp_text_style.dart';

final class const WPApproval(
  final String question, {
  super.key,
  required final VoidCallback onApprove,
  required final VoidCallback onReject,
}) extends StatelessWidget {
  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: .stretch,
    spacing: 12,
    children: [
      Text(question, style: WPTextStyle.title),
      WPDecision(onApprove: onApprove, onReject: onReject),
    ],
  );
}

final class const WPDecision({
  super.key,
  required final VoidCallback onApprove,
  required final VoidCallback onReject,
}) extends StatelessWidget {
  @override
  Widget build(BuildContext context) => Row(
    spacing: 8,
    children: [
      Expanded(
        child: WPButton(
          WPLocalizations.of(context).reject,
          small: true,
          primary: false,
          onPressed: onReject,
        ),
      ),
      Expanded(
        child: WPButton(
          WPLocalizations.of(context).approve,
          small: true,
          onPressed: onApprove,
        ),
      ),
    ],
  );
}
