import 'package:flutter/widgets.dart';
import 'package:waypoint_design_system/src/marker.dart';
import 'package:waypoint_design_system/src/theme.dart';

/// A row of a form: its label, what it holds, and under it the [error]
/// or else the [note]. The blue bar marks what the assistant filled in.
/// [onTap] takes a tap anywhere on the row. With [action] as well, the row
/// shows that icon at its end and is a button, unless it [holdsInput]: a
/// tap on a row with its own text input only focuses that input.
final class const FieldRow({
  super.key,
  required final String label,
  required final Widget child,
  final String? error,
  final String? note,
  required final bool marked,
  final VoidCallback? onTap,
  final IconData? action,
  final bool holdsInput = false,
}) extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final acts = onTap != null && action != null;
    return Semantics(
      button: acts && !holdsInput,
      child: GestureDetector(
        behavior: .opaque,
        onTap: onTap,
        child: Stack(
          children: [
            Padding(
              padding: const .fromLTRB(16, 10, 14, 11),
              child: Row(
                spacing: 10,
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: .stretch,
                      spacing: 2,
                      children: [
                        Text(label, style: AppText.label),
                        child,
                        if (error case final error?)
                          Text(
                            error,
                            style: AppText.label.copyWith(color: Palette.warn),
                          )
                        else if (note case final note?)
                          Text(note, style: AppText.label),
                      ],
                    ),
                  ),
                  if (action case final action? when acts)
                    Icon(action, size: 18, color: Palette.muted),
                ],
              ),
            ),
            Positioned(
              left: 0,
              top: 10,
              bottom: 10,
              child: Marker(marked: marked),
            ),
          ],
        ),
      ),
    );
  }
}
