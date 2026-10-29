import 'package:flutter/material.dart';
import 'package:waypoint_design_system/src/card.dart';
import 'package:waypoint_design_system/src/layout.dart';
import 'package:waypoint_design_system/src/theme.dart';

/// A tab, with the number of what waits in it.
final class const WaypointDestination(
  final IconData icon,
  final IconData selectedIcon,
  final String label, {
  final int count = 0,
});

/// The app's tabs around [child]: a bar at the bottom on a phone, a rail on
/// a tablet.
final class const WaypointNavigationScaffold({
  super.key,
  required final List<WaypointDestination> destinations,
  required final int selectedIndex,
  required final ValueChanged<int> onSelected,
  required final Widget child,
}) extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    if (context.isTablet) {
      return Scaffold(
        body: Row(
          children: [
            NavigationRail(
              selectedIndex: selectedIndex,
              onDestinationSelected: onSelected,
              labelType: .all,
              destinations: [
                for (final destination in destinations)
                  NavigationRailDestination(
                    icon: _Badged(destination, selected: false),
                    selectedIcon: _Badged(destination, selected: true),
                    label: Text(destination.label),
                  ),
              ],
            ),
            const WaypointDivider(vertical: true),
            Expanded(child: child),
          ],
        ),
      );
    }
    return Scaffold(
      body: child,
      bottomNavigationBar: NavigationBar(
        selectedIndex: selectedIndex,
        onDestinationSelected: onSelected,
        destinations: [
          for (final destination in destinations)
            NavigationDestination(
              icon: _Badged(destination, selected: false),
              selectedIcon: _Badged(destination, selected: true),
              label: destination.label,
            ),
        ],
      ),
    );
  }
}

final class const _Badged(
  final WaypointDestination destination, {
  required final bool selected,
}) extends StatelessWidget {
  @override
  Widget build(BuildContext context) => Badge(
    isLabelVisible: destination.count > 0,
    label: Text('${destination.count}'),
    backgroundColor: Palette.ai,
    child: Icon(selected ? destination.selectedIcon : destination.icon),
  );
}
