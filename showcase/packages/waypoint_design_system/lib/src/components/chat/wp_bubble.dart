import 'package:flutter/widgets.dart';
import 'package:waypoint_design_system/src/foundations/wp_colors.dart';
import 'package:waypoint_design_system/src/foundations/wp_text_style.dart';

final class const WPBubble(final String text, {super.key})
    extends StatelessWidget {
  @override
  Widget build(BuildContext context) => Align(
    alignment: .centerRight,
    child: ConstrainedBox(
      constraints: const BoxConstraints(maxWidth: 300),
      child: DecoratedBox(
        decoration: const BoxDecoration(
          color: WPColors.raised,
          borderRadius: BorderRadius.only(
            topLeft: Radius.circular(10),
            topRight: Radius.circular(10),
            bottomLeft: Radius.circular(10),
            bottomRight: Radius.circular(3),
          ),
        ),
        child: Padding(
          padding: const .symmetric(horizontal: 14, vertical: 10),
          child: Text(text, style: WPTextStyle.body),
        ),
      ),
    ),
  );
}
