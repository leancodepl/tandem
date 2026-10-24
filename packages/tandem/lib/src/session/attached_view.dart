import 'package:tandem/src/protocol/ag_ui.dart';
import 'package:tandem/src/session/tool_answer.dart';

/// A view the in-app agent draws on, such as a `TandemView`. Every run that
/// starts while it is attached offers the agent its [tool].
// The experimental lint asks for a primary constructor on an interface too.
// ignore: use_primary_constructors
abstract interface class AttachedView {
  /// The name of [tool].
  static const toolName = 'show_view';

  /// The AG-UI tool named [toolName], with what the agent may draw.
  JsonObject get tool;

  /// Draws what the agent sent as the [arguments] of [tool], or says why
  /// not. Never throws for arguments of the wrong shape.
  ToolAnswer show(JsonObject arguments);
}
