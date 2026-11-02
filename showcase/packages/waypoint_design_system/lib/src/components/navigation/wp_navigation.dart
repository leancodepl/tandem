import 'package:flutter/material.dart';
import 'package:waypoint_design_system/src/atoms/wp_divider.dart';
import 'package:waypoint_design_system/src/foundations/wp_colors.dart';
import 'package:waypoint_design_system/src/foundations/wp_layout.dart';

final class const WPDestination(
  final IconData icon,
  final IconData selectedIcon,
  final String label, {
  final int count = 0,
});

final class const WPNavigationScaffold({
  super.key,
  required final List<WPDestination> destinations,
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
            const WPDivider(vertical: true),
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
  final WPDestination destination, {
  required final bool selected,
}) extends StatelessWidget {
  @override
  Widget build(BuildContext context) => Badge(
    isLabelVisible: destination.count > 0,
    label: Text('${destination.count}'),
    backgroundColor: WPColors.ai,
    child: Icon(selected ? destination.selectedIcon : destination.icon),
  );
}
