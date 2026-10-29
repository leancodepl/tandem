import 'package:flutter/material.dart';
import 'package:waypoint_design_system/src/buttons.dart';
import 'package:waypoint_design_system/src/layout.dart';
import 'package:waypoint_design_system/src/theme.dart';

/// A screen of its own, above the tabs.
final class const WaypointPage({super.key, required final Widget child})
    extends StatelessWidget {
  @override
  Widget build(BuildContext context) => Scaffold(body: child);
}

/// The way back, with the page's [title] next to it, or a [trailing] line
/// such as what the trip is for at the other end. It keeps clear of the
/// status bar.
final class const WaypointTopBar({
  super.key,
  required final VoidCallback onBack,
  final String? title,
  final String? trailing,

  /// On a wide layout, whose content sits further in.
  final bool wide = false,
}) extends StatelessWidget {
  @override
  Widget build(BuildContext context) => SafeArea(
    bottom: false,
    child: Padding(
      padding: .fromLTRB(wide ? 24 : 8, 4, wide ? 36 : 20, 4),
      child: Row(
        spacing: 8,
        children: [
          WaypointBackButton(onPressed: onBack),
          if (title case final title?) Text(title, style: AppText.title),
          if (trailing case final trailing?)
            Expanded(
              child: Text(
                trailing,
                textAlign: .end,
                maxLines: 1,
                overflow: .ellipsis,
                style: AppText.label,
              ),
            ),
        ],
      ),
    ),
  );
}

/// The page's name in large capitals, with a short line above or below
/// it, and [trailing] such as a button at its end.
final class const WaypointPageTitle(
  final String title, {
  super.key,
  final String? above,
  final String? below,
  final Widget? trailing,
}) extends StatelessWidget {
  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: .stretch,
    children: [
      if (above case final above?) ...[
        Text(above, style: AppText.label),
        const SizedBox(height: 4),
      ],
      Row(
        crossAxisAlignment: .end,
        children: [
          Expanded(child: Text(title, style: AppText.headline)),
          if (trailing case final trailing?)
            Padding(padding: const .only(bottom: 10), child: trailing),
        ],
      ),
      if (below case final below?)
        Text(below, style: AppText.body.copyWith(color: Palette.muted)),
    ],
  );
}

/// A page of a tab: its [title], with [above] and [trailing] as on
/// [WaypointPageTitle], over [children] in a list that keeps clear of the
/// status bar.
final class const WaypointTabPage({
  super.key,
  required final String title,
  final String? above,
  final Widget? trailing,
  required final List<Widget> children,
}) extends StatelessWidget {
  @override
  Widget build(BuildContext context) => SafeArea(
    bottom: false,
    child: Readable(
      child: ListView(
        padding: const .fromLTRB(20, 24, 20, 32),
        children: [
          WaypointPageTitle(title, above: above, trailing: trailing),
          const SizedBox(height: 20),
          ...children,
        ],
      ),
    ),
  );
}
