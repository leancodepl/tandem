import 'package:flutter/material.dart';
import 'package:waypoint_design_system/src/foundations/wp_text_style.dart';

final class const WPTotal(
  final String caption,
  final String amount, {
  super.key,
}) extends StatelessWidget {
  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: .start,
    mainAxisSize: .min,
    children: [
      Text(caption, style: WPTextStyle.label),
      Text(amount, style: WPTextStyle.time.copyWith(fontSize: 26)),
    ],
  );
}
