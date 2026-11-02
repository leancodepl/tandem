import 'package:flutter/material.dart';
import 'package:waypoint_design_system/src/foundations/wp_colors.dart';
import 'package:waypoint_design_system/src/foundations/wp_text_style.dart';

final class const WPConfirmation(
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
        child: Icon(Icons.check_circle_rounded, size: 18, color: WPColors.ink),
      ),
      Flexible(
        child: Column(
          crossAxisAlignment: .start,
          mainAxisSize: .min,
          children: [
            Text(title, style: WPTextStyle.title),
            if (reference case final reference?)
              Text(reference, style: WPTextStyle.label),
          ],
        ),
      ),
    ],
  );
}
