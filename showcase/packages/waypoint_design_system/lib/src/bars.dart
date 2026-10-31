import 'package:flutter/material.dart';
import 'package:waypoint_design_system/l10n/design_system_localizations.dart';
import 'package:waypoint_design_system/src/buttons.dart';
import 'package:waypoint_design_system/src/layout.dart';
import 'package:waypoint_design_system/src/theme.dart';

final class const WaypointActionBar({
  super.key,
  required final Widget child,

  final bool active = false,
  final double gutter = 20,

  /// Keeps clear of the screen's bottom edge, when nothing is below the bar.
  final bool bottom = true,
}) extends StatelessWidget {
  @override
  Widget build(BuildContext context) => DecoratedBox(
    decoration: BoxDecoration(
      color: Palette.surface,
      border: Border(
        top: BorderSide(color: active ? Palette.ai : Palette.line),
      ),
    ),
    child: Padding(
      padding: .fromLTRB(
        gutter,
        14,
        gutter,
        14 + (bottom ? MediaQuery.paddingOf(context).bottom : 0),
      ),
      child: Readable(child: child),
    ),
  );
}

final class const WaypointSubmit({
  super.key,
  required final String label,
  required final VoidCallback? onSubmit,
  final WaypointTotal? total,
  final bool busy = false,
}) extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final button = WaypointButton(label, busy: busy, onPressed: onSubmit);
    return switch (total) {
      final total? => OverflowBar(
        alignment: .spaceBetween,
        overflowSpacing: 12,
        spacing: 16,
        children: [total, button],
      ),
      null => SizedBox(width: double.infinity, child: button),
    };
  }
}

final class const WaypointTotal(
  final String caption,
  final String amount, {
  super.key,
}) extends StatelessWidget {
  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: .start,
    mainAxisSize: .min,
    children: [
      Text(caption, style: AppText.label),
      Text(amount, style: AppText.time.copyWith(fontSize: 26)),
    ],
  );
}

final class const WaypointConfirmation(
  final String title, {
  super.key,
  final String? reference,
}) extends StatelessWidget {
  @override
  Widget build(BuildContext context) => Row(
    mainAxisSize: .min,
    crossAxisAlignment: .start,
    spacing: 8,
    children: [
      const Padding(
        padding: .only(top: 2),
        child: Icon(Icons.check_circle_rounded, size: 18, color: Palette.ink),
      ),
      Flexible(
        child: Column(
          crossAxisAlignment: .start,
          mainAxisSize: .min,
          children: [
            Text(title, style: AppText.title),
            if (reference case final reference?)
              Text(reference, style: AppText.label),
          ],
        ),
      ),
    ],
  );
}

final class const WaypointApproval(
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
      Text(question, style: AppText.title),
      WaypointDecision(onApprove: onApprove, onReject: onReject),
    ],
  );
}

final class const WaypointDecision({
  super.key,
  required final VoidCallback onApprove,
  required final VoidCallback onReject,
}) extends StatelessWidget {
  @override
  Widget build(BuildContext context) => Row(
    spacing: 8,
    children: [
      Expanded(
        child: WaypointButton(
          DesignSystemLocalizations.of(context).reject,
          small: true,
          primary: false,
          onPressed: onReject,
        ),
      ),
      Expanded(
        child: WaypointButton(
          DesignSystemLocalizations.of(context).approve,
          small: true,
          onPressed: onApprove,
        ),
      ),
    ],
  );
}
