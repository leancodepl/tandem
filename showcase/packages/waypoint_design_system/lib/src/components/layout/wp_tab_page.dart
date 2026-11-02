import 'package:flutter/material.dart';
import 'package:waypoint_design_system/src/components/layout/wp_page_title.dart';
import 'package:waypoint_design_system/src/components/layout/wp_readable.dart';

final class const WPTabPage({
  super.key,
  required final String title,
  final String? above,
  final Widget? trailing,
  required final List<Widget> children,
}) extends StatelessWidget {
  @override
  Widget build(BuildContext context) => SafeArea(
    bottom: false,
    child: WPReadable(
      child: ListView(
        padding: const .fromLTRB(20, 24, 20, 32),
        children: [
          WPPageTitle(title, above: above, trailing: trailing),
          const SizedBox(height: 20),
          ...children,
        ],
      ),
    ),
  );
}
