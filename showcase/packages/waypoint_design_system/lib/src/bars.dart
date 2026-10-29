import 'package:flutter/material.dart';
import 'package:waypoint_design_system/l10n/design_system_localizations.dart';
import 'package:waypoint_design_system/src/buttons.dart';
import 'package:waypoint_design_system/src/layout.dart';
import 'package:waypoint_design_system/src/theme.dart';

/// The bar at the bottom of a screen with what the traveller acts on: a
/// form's submit, or the assistant's request to approve.
final class const WaypointActionBar({
  super.key,
  required final Widget child,

  /// A request waits for the traveller.
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

/// A form's submit, for a [WaypointActionBar]: its [total] and the
/// traveller's button, which takes the whole width without a total.
/// [onSubmit] is null while the agent works or something is missing.
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
    return Row(
      spacing: 16,
      children: switch (total) {
        final total? => [Expanded(child: total), button],
        null => [Expanded(child: button)],
      },
    );
  }
}

/// What something costs, under what it is.
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

/// What is booked or submitted, for a [WaypointActionBar]: a check with
/// [title], over its [reference] when it has one.
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

/// What the assistant asks to do in the traveller's name, for a
/// [WaypointActionBar], with the traveller's answer.
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

/// The traveller's answer to a request: Reject, then Approve.
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
