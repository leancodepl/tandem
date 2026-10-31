import 'package:flutter/material.dart';
import 'package:waypoint_design_system/src/marker.dart';
import 'package:waypoint_design_system/src/theme.dart';

final class const WaypointCard({
  super.key,
  required final Widget child,
  final VoidCallback? onTap,

  /// Null for an outline only.
  final Color? color = Palette.surface,
  final Color border = Palette.line,
  final EdgeInsetsGeometry padding = const .fromLTRB(16, 14, 16, 16),

  final bool marked = false,
}) extends StatelessWidget {
  @override
  Widget build(BuildContext context) => TweenAnimationBuilder(
    tween: ColorTween(end: marked ? Palette.aiLine : border),
    duration: const Duration(milliseconds: 360),
    curve: Curves.easeOutCubic,
    // Over the content: it neither insets it nor hides under a tap's
    // highlight.
    builder: (context, shown, child) => DecoratedBox(
      position: .foreground,
      decoration: BoxDecoration(
        borderRadius: Radii.card,
        border: Border.all(color: shown ?? Palette.line),
      ),
      child: child,
    ),
    child: Material(
      color: color ?? Colors.transparent,
      borderRadius: Radii.card,
      child: InkWell(
        onTap: onTap,
        borderRadius: Radii.card,
        child: Stack(
          children: [
            Padding(padding: padding, child: child),
            Positioned(
              left: 0,
              top: 12,
              bottom: 12,
              child: Marker(marked: marked),
            ),
          ],
        ),
      ),
    ),
  );
}

final class const WaypointGroup({
  super.key,
  required final List<Widget> children,

  /// Null for an outline only.
  final Color? color = Palette.surface,
  final Color border = Palette.line,
}) extends StatelessWidget {
  @override
  Widget build(BuildContext context) => DecoratedBox(
    decoration: BoxDecoration(
      color: color,
      border: Border.all(color: border),
      borderRadius: Radii.card,
    ),
    child: ClipRRect(
      borderRadius: Radii.card,
      child: Column(
        children: [
          for (final (index, child) in children.indexed) ...[
            if (index > 0) const WaypointDivider(),
            child,
          ],
        ],
      ),
    ),
  );
}

final class const WaypointOption({
  super.key,
  required final String lead,
  required final String label,
  required final String trailing,
  required final bool selected,
  final VoidCallback? onTap,
}) extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final color = onTap == null ? Palette.muted : Palette.ink;
    return Material(
      color: selected ? Palette.raised : Colors.transparent,
      // Without onTap the option still takes the tap, so that a card around
      // the group does not.
      child: GestureDetector(
        onTap: () {},
        excludeFromSemantics: true,
        child: InkWell(
          onTap: onTap,
          child: ConstrainedBox(
            constraints: const BoxConstraints(minHeight: 44),
            child: Padding(
              padding: const .symmetric(horizontal: 12, vertical: 8),
              child: Row(
                spacing: 10,
                children: [
                  Text(
                    lead,
                    style: AppText.body.copyWith(
                      color: color,
                      fontWeight: selected ? FontWeight.w600 : FontWeight.w500,
                    ),
                  ),
                  Expanded(
                    child: Text(
                      label,
                      style: AppText.label,
                      overflow: .ellipsis,
                    ),
                  ),
                  Text(trailing, style: AppText.body.copyWith(color: color)),
                  SizedBox(
                    width: 18,
                    child: selected
                        ? const Icon(
                            Icons.check_rounded,
                            size: 18,
                            color: Palette.ink,
                          )
                        : null,
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

final class const WaypointMailCard({
  super.key,
  required final String from,
  required final String subject,
  final Widget? trailing,
  final bool selected = false,
  final VoidCallback? onTap,
}) extends StatelessWidget {
  @override
  Widget build(BuildContext context) => WaypointCard(
    onTap: onTap,
    border: selected ? Palette.ink : Palette.lineStrong,
    padding: const .fromLTRB(14, 12, 14, 12),
    child: Row(
      spacing: 12,
      children: [
        const Icon(Icons.mail_outline_rounded, size: 20, color: Palette.muted),
        Expanded(
          child: Column(
            crossAxisAlignment: .start,
            spacing: 2,
            children: [
              Text(from, style: AppText.title.copyWith(fontSize: 15)),
              Text(
                subject,
                maxLines: 1,
                overflow: .ellipsis,
                style: AppText.label,
              ),
            ],
          ),
        ),
        ?trailing,
      ],
    ),
  );
}

final class const WaypointTile({
  super.key,
  required final String title,
  final String? subtitle,
  final IconData? icon,
  final Widget? trailing,

  final bool dimmed = false,
}) extends StatelessWidget {
  @override
  Widget build(BuildContext context) => Row(
    spacing: 12,
    children: [
      if (icon case final icon?) Icon(icon, color: Palette.muted),
      Expanded(
        child: Column(
          crossAxisAlignment: .start,
          spacing: 2,
          children: [
            Text(
              title,
              style: AppText.body.copyWith(
                color: dimmed ? Palette.muted : Palette.ink,
              ),
            ),
            if (subtitle case final subtitle?)
              Text(subtitle, style: AppText.label),
          ],
        ),
      ),
      ?trailing,
    ],
  );
}

final class const WaypointListCard({
  super.key,
  required final String title,
  required final String subtitle,
  required final String caption,
  final List<Widget> footer = const [],
  final Color border = Palette.line,
  required final VoidCallback onTap,
}) extends StatelessWidget {
  @override
  Widget build(BuildContext context) => WaypointCard(
    onTap: onTap,
    border: border,
    padding: const .fromLTRB(16, 14, 12, 16),
    child: Row(
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: .start,
            spacing: 4,
            children: [
              Text(title, style: AppText.cardTitle),
              Text(subtitle, style: AppText.body),
              Text(caption, style: AppText.label),
              if (footer.isNotEmpty) ...[const SizedBox(height: 6), ...footer],
            ],
          ),
        ),
        const Icon(Icons.chevron_right_rounded, color: Palette.muted),
      ],
    ),
  );
}

final class const WaypointDividedColumn({
  super.key,
  required final bool first,
  required final Widget child,
}) extends StatelessWidget {
  @override
  Widget build(BuildContext context) => DecoratedBox(
    decoration: BoxDecoration(
      border: first
          ? null
          : const Border(left: BorderSide(color: Palette.line)),
    ),
    child: child,
  );
}

final class const WaypointDivider({
  super.key,
  final bool vertical = false,
  final Color color = Palette.line,
}) extends StatelessWidget {
  @override
  Widget build(BuildContext context) => vertical
      ? VerticalDivider(width: 1, color: color)
      : Divider(height: 1, color: color);
}
