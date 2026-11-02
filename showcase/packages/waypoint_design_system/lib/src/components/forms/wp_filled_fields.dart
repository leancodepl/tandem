import 'dart:async';

import 'package:flutter/widgets.dart';
import 'package:flutter_hooks/flutter_hooks.dart';
import 'package:waypoint_design_system/src/atoms/motion/wp_swap_text.dart';
import 'package:waypoint_design_system/src/components/cards/wp_group.dart';
import 'package:waypoint_design_system/src/components/forms/wp_field_row.dart';
import 'package:waypoint_design_system/src/foundations/wp_colors.dart';
import 'package:waypoint_design_system/src/foundations/wp_text_style.dart';

final class const WPFilledFields(
  final List<(String, String?)> rows, {
  super.key,
}) extends StatelessWidget {
  @override
  Widget build(BuildContext context) => WPGroup(
    children: [
      for (final (index, (label, value)) in rows.indexed)
        WPFilledField(label, value, order: index),
    ],
  );
}

/// A field of the form. A value the agent filled shows a moment after the
/// one above it, so the eye can follow the form filling in, and stays marked
/// in blue.
final class const WPFilledField(
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
    return WPFieldRow(
      label: label,
      marked: filled,
      child: WPSwapText(
        shown.value ?? '—',
        style: WPTextStyle.body.copyWith(
          color: filled ? WPColors.ink : WPColors.lineStrong,
        ),
      ),
    );
  }
}
