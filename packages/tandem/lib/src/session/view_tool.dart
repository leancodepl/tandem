import 'package:tandem/src/agent_list.dart';
import 'package:tandem/src/protocol/ag_ui.dart';
import 'package:tandem/src/session/tool_answer.dart';

/// The tool of a view an agent draws on, such as a `TandemView`. While a
/// view is attached to a session, every run offers the in-app agent its
/// tool, and `TandemBridge` lists it for a coding agent. The session knows
/// the view only through this interface.
abstract interface class ViewTool() {
  /// The tool's name. Tandem's own tools start with `tandem_`, which keeps
  /// them apart from the app's methods.
  static const name = 'tandem_show_view';

  /// The AG-UI tool for an agent that sees [listing], whose description
  /// teaches the agent what it may draw, or null when the view cannot draw
  /// now.
  JsonObject? definition(AgentListing listing);

  /// Draws what the agent sent as the arguments of the tool, or says what to
  /// fix.
  ToolAnswer show(JsonObject arguments);
}

/// The view offered by one run, which may have left the screen since.
typedef OfferedView = ({ViewTool tool, JsonObject definition});

/// The session's attached view and its refusal limit across runs.
final class ViewDrawing() {
  static const _maxRefused = 3;
  ViewTool? _view;
  var _refused = 0;

  void attach(ViewTool view) => _view = view;

  void detach(ViewTool view) {
    if (identical(view, _view)) {
      _view = null;
    }
  }

  /// A new message lets the agent try drawing again.
  void resetRefusals() => _refused = 0;

  OfferedView? offer(AgentListing listing) {
    final view = _view;
    if (view == null || _refused >= _maxRefused) return null;
    return switch (view.definition(listing)) {
      final definition? => (tool: view, definition: definition),
      null => null,
    };
  }

  // A model that never draws a view that fits would try again on every run.
  ToolAnswer show(OfferedView view, JsonObject arguments) {
    if (_refused >= _maxRefused) {
      return ToolAnswer.drawingStopped(_maxRefused);
    }
    final answer = identical(view.tool, _view)
        ? view.tool.show(arguments)
        : ToolAnswer.refused('No view is on the screen now.');
    _refused = answer.status == .shown ? 0 : _refused + 1;
    return _refused < _maxRefused
        ? answer
        : ToolAnswer.drawingStopped(_maxRefused);
  }

  /// The tool, which the limit of refused views of runs does not withhold.
  JsonObject? definitionOutsideRun(AgentListing listing) =>
      _view?.definition(listing);

  /// Its views do not count toward the limit of refused views of runs.
  ToolAnswer showOutsideRun(JsonObject arguments) => switch (_view) {
    final view? => view.show(arguments),
    null => .refused('This screen has no TandemView to draw a view on.'),
  };
}
