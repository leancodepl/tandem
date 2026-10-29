import 'package:tandem/src/agent_list.dart';
import 'package:tandem/src/protocol/ag_ui.dart';
import 'package:tandem/src/session/tool_answer.dart';

/// The tool of a view the in-app agent draws on, such as a `TandemView`.
/// While a view is attached to a session, every run offers the agent its
/// tool. The session knows the view only through this interface.
abstract interface class ViewTool() {
  /// The tool's name. Tandem's own tools start with `tandem_`, which keeps
  /// them apart from the app's methods.
  static const name = 'tandem_show_view';

  /// The AG-UI tool for a run that sees [listing], whose description teaches
  /// the agent what it may draw, or null when the view cannot draw now.
  JsonObject? definition(AgentListing listing);

  /// Draws what the agent sent as the arguments of the tool, or says what to
  /// fix.
  ToolAnswer show(JsonObject arguments);
}
