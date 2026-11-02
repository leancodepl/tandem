import 'package:flutter/material.dart';
import 'package:waypoint_design_system/src/atoms/wp_buttons.dart';
import 'package:waypoint_design_system/src/atoms/wp_total.dart';

final class const WPSubmit({
  super.key,
  required final String label,
  required final VoidCallback? onSubmit,
  final WPTotal? total,
  final bool busy = false,
}) extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final button = WPButton(label, busy: busy, onPressed: onSubmit);
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
