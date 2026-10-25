import 'package:tandem/src/protocol/ag_ui.dart';
import 'package:tandem/src/session/tool_answer.dart';

/// The tool of a view the in-app agent draws on, such as a `TandemView`.
/// While a view is attached to a session, every run offers the agent its
/// tool. The session knows the view only through this interface, so an app
/// without a view leaves the code that draws out of its release build.
// The experimental lint asks for a primary constructor on an interface too.
// ignore: use_primary_constructors
abstract interface class ViewTool {
  /// The tool's name. Tandem's own tools start with `tandem_`, which keeps
  /// them apart from the app's methods.
  static const name = 'tandem_show_view';

  /// The AG-UI tool, whose description teaches the agent what it may draw.
  JsonObject get definition;

  /// Draws what the agent sent as the arguments of the tool, or says what to
  /// fix. Throws only when the agent list throws.
  ToolAnswer show(JsonObject arguments);
}
