import 'package:flutter/material.dart';
import 'package:waypoint_design_system/src/foundations/wp_colors.dart';
import 'package:waypoint_design_system/src/foundations/wp_layout.dart';
import 'package:waypoint_design_system/src/foundations/wp_radii.dart';

/// Opens [child] as a dialog on a tablet and as a sheet from the bottom on
/// a phone. Returns what it closes with.
Future<T?> showWPSheet<T>(BuildContext context, {required Widget child}) {
  if (context.isTablet) {
    return showDialog<T>(
      context: context,
      barrierColor: WPColors.scrim,
      builder: (context) => Dialog(
        backgroundColor: WPColors.panel,
        insetPadding: const .all(40),
        shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.all(WPRadii.sheet),
          side: BorderSide(color: WPColors.lineStrong),
        ),
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 560, maxHeight: 760),
          child: child,
        ),
      ),
    );
  }
  return showModalBottomSheet<T>(
    context: context,
    isScrollControlled: true,
    useSafeArea: true,
    backgroundColor: WPColors.panel,
    barrierColor: WPColors.scrim,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: WPRadii.sheet),
    ),
    // A modal bottom sheet does not move up for the keyboard on its own.
    builder: (context) => AnimatedPadding(
      duration: const Duration(milliseconds: 100),
      padding: .only(bottom: MediaQuery.viewInsetsOf(context).bottom),
      child: FractionallySizedBox(heightFactor: .92, child: child),
    ),
  );
}
