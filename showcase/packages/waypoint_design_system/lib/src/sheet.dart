import 'package:flutter/material.dart';
import 'package:waypoint_design_system/src/layout.dart';
import 'package:waypoint_design_system/src/theme.dart';

/// Opens [child] as a dialog on a tablet and as a sheet from the bottom on
/// a phone. Returns what it closes with.
Future<T?> showWaypointSheet<T>(BuildContext context, {required Widget child}) {
  if (context.isTablet) {
    return showDialog<T>(
      context: context,
      barrierColor: Palette.scrim,
      builder: (context) => Dialog(
        backgroundColor: Palette.panel,
        insetPadding: const .all(40),
        shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.all(Radii.sheet),
          side: BorderSide(color: Palette.lineStrong),
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
    backgroundColor: Palette.panel,
    barrierColor: Palette.scrim,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radii.sheet),
    ),
    // A modal bottom sheet does not move up for the keyboard on its own.
    builder: (context) => AnimatedPadding(
      duration: const Duration(milliseconds: 100),
      padding: .only(bottom: MediaQuery.viewInsetsOf(context).bottom),
      child: FractionallySizedBox(heightFactor: .92, child: child),
    ),
  );
}
