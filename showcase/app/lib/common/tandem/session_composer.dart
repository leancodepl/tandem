import 'package:flutter/widgets.dart';
import 'package:flutter_hooks/flutter_hooks.dart';
import 'package:tandem/tandem.dart';
import 'package:waypoint/common/tandem/session_status.dart';
import 'package:waypoint_design_system/waypoint_design_system.dart';

final class const SessionComposer({super.key, required final String hint})
    extends HookWidget {
  @override
  Widget build(BuildContext context) {
    final text = useTextEditingController();
    final session = TandemSessionScope.of(context);
    final status = session.status;
    return WPComposer(
      controller: text,
      hint: hint,
      working: status.isRunning,
      onSend: () {
        session.send(text.text);
        text.clear();
        // Keep the screen in view while the assistant changes it.
        FocusScope.of(context).unfocus();
      },
      onStop: status.isStoppable ? session.stop : null,
    );
  }
}
