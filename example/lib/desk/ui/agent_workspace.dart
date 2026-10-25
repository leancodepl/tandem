import 'dart:math' as math;

import 'package:example/desk/ui/desk_theme.dart';
import 'package:flutter/material.dart';

/// A screen's content and its chat, side by side when there is room and
/// stacked on a phone.
final class const AgentWorkspace({
  super.key,
  required final String title,
  required final Widget chat,
  required final Widget child,
}) extends StatelessWidget {
  @override
  Widget build(BuildContext context) => SafeArea(
    child: LayoutBuilder(
      builder: (context, constraints) {
        final stacked = constraints.maxWidth < 760;

        return SingleChildScrollView(
          padding: const .all(12),
          child: SizedBox(
            height: math.max(stacked ? 500 : 320, constraints.maxHeight - 24),
            child: Flex(
              direction: stacked ? .vertical : .horizontal,
              spacing: 12,
              crossAxisAlignment: .stretch,
              children: [
                Expanded(
                  child: _Panel(title: title, child: child),
                ),
                Expanded(
                  child: _Panel(title: 'Agent', child: chat),
                ),
              ],
            ),
          ),
        );
      },
    ),
  );
}

final class const _Panel({
  required final String title,
  required final Widget child,
}) extends StatelessWidget {
  @override
  Widget build(BuildContext context) => Material(
    color: context.colorScheme.surfaceContainer,
    shape: RoundedRectangleBorder(
      side: BorderSide(color: context.colorScheme.outlineVariant),
      borderRadius: .circular(8),
    ),
    clipBehavior: .antiAlias,
    child: Column(
      crossAxisAlignment: .stretch,
      children: [
        Padding(
          padding: const .symmetric(horizontal: 16, vertical: 12),
          child: Text(title, style: context.textTheme.titleSmall),
        ),
        const Divider(height: 1),
        Expanded(child: child),
      ],
    ),
  );
}
