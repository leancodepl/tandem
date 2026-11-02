import 'package:flutter/widgets.dart';
import 'package:waypoint_design_system/src/foundations/wp_text_style.dart';

final class const WPSection(
  final String title, {
  super.key,
  required final Widget child,
}) extends StatelessWidget {
  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: .stretch,
    spacing: 8,
    children: [
      Text(title, style: WPTextStyle.day),
      child,
    ],
  );
}
