import 'package:flutter/material.dart';
import 'package:waypoint_design_system/src/theme.dart';

/// What the agent is doing on part of a screen, with a progress bar while
/// it works. An action the traveller started shows as a busy
/// `WaypointButton` instead.
final class const WorkStatus(
  final String? text, {
  super.key,
  required final bool working,
}) extends StatelessWidget {
  @override
  Widget build(BuildContext context) => AnimatedSize(
    duration: const Duration(milliseconds: 280),
    curve: Curves.easeOutCubic,
    alignment: .topLeft,
    child: switch (text) {
      final text? => Padding(
        padding: const .only(top: 14),
        child: Column(
          crossAxisAlignment: .stretch,
          spacing: 8,
          children: [
            Text(
              text,
              style: AppText.label.copyWith(
                color: working ? Palette.aiText : Palette.muted,
              ),
            ),
            if (working)
              const LinearProgressIndicator(
                minHeight: 2,
                color: Palette.ai,
                backgroundColor: Palette.line,
              ),
          ],
        ),
      ),
      null => const SizedBox(width: double.infinity),
    },
  );
}
