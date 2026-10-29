import 'dart:async';

import 'package:flutter/widgets.dart';
import 'package:flutter_hooks/flutter_hooks.dart';
import 'package:waypoint_design_system/src/appear.dart';
import 'package:waypoint_design_system/src/card.dart';
import 'package:waypoint_design_system/src/field_row.dart';
import 'package:waypoint_design_system/src/theme.dart';

/// A part of a form under its heading.
final class const WaypointSection(
  final String title, {
  super.key,
  required final Widget child,
}) extends StatelessWidget {
  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: .stretch,
    spacing: 8,
    children: [
      Text(title, style: AppText.day),
      child,
    ],
  );
}

/// The fields of a form that the agent fills in, as label and value. A
/// field without a value shows a dash.
final class const FilledFields(final List<(String, String?)> rows, {super.key})
    extends StatelessWidget {
  @override
  Widget build(BuildContext context) => WaypointGroup(
    children: [
      for (final (index, (label, value)) in rows.indexed)
        FilledField(label, value, order: index),
    ],
  );
}

/// A field of the form. A value the agent filled shows a moment after the
/// one above it, so the eye can follow the form filling in, and stays marked
/// in blue.
final class const FilledField(
  final String label,
  final String? value, {
  super.key,
  required final int order,
}) extends HookWidget {
  @override
  Widget build(BuildContext context) {
    final shown = useState(value);
    useEffect(() {
      if (shown.value == null && value != null) {
        final delay = Timer(
          Duration(milliseconds: 140 * order),
          () => shown.value = value,
        );
        return delay.cancel;
      }
      shown.value = value;
      return null;
    }, [value]);

    final filled = shown.value != null;
    return FieldRow(
      label: label,
      marked: filled,
      child: WaypointSwapText(
        shown.value ?? '—',
        style: AppText.body.copyWith(
          color: filled ? Palette.ink : Palette.lineStrong,
        ),
      ),
    );
  }
}
