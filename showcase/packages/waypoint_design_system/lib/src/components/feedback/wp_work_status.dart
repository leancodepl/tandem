import 'package:flutter/material.dart';
import 'package:waypoint_design_system/src/foundations/wp_colors.dart';
import 'package:waypoint_design_system/src/foundations/wp_text_style.dart';

/// What the agent is doing on part of a screen, with a progress bar while
/// it works. An action the traveller started shows as a busy
/// `WPButton` instead.
final class const WPWorkStatus(
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
              style: WPTextStyle.label.copyWith(
                color: working ? WPColors.aiText : WPColors.muted,
              ),
            ),
            if (working)
              const LinearProgressIndicator(
                minHeight: 2,
                color: WPColors.ai,
                backgroundColor: WPColors.line,
              ),
          ],
        ),
      ),
      null => const SizedBox(width: double.infinity),
    },
  );
}
