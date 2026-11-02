import 'package:flutter/widgets.dart';
import 'package:waypoint_design_system/src/foundations/wp_layout.dart';

final class const WPReadable({super.key, required final Widget child})
    extends StatelessWidget {
  @override
  Widget build(BuildContext context) => Align(
    alignment: .topCenter,
    child: ConstrainedBox(
      constraints: const BoxConstraints(maxWidth: WPWidths.readable),
      child: child,
    ),
  );
}
