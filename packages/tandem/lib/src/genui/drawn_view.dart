import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:tandem/src/agent_list.dart';
import 'package:tandem/src/agent_schema.dart';
import 'package:tandem/src/genui/action_arguments.dart';
import 'package:tandem/src/genui/agent_catalog.dart';
import 'package:tandem/src/genui/view_check.dart';
import 'package:tandem/src/genui/view_description.dart';
import 'package:tandem/src/genui/view_render.dart';
import 'package:tandem/src/genui/view_requirements.dart';
import 'package:tandem/src/protocol/ag_ui.dart';
import 'package:tandem/src/report.dart';
import 'package:tandem/src/session/session_status.dart';
import 'package:tandem/src/session/tandem_session.dart';
import 'package:tandem/src/session/tool_answer.dart';
import 'package:tandem/src/session/view_tool.dart';

/// What the in-app agent drew on one screen with [catalog], attached to
/// [session] from the start. It reads what the screen lists with `.sees`
/// again on every change of the surface, and draws with it. An action of
/// the view calls its method for the view, through the session, one at a
/// time.
///
/// Notifies when the view, the data or the session changes, for
/// `TandemView`.
final class DrawnView(final TandemSession session, final AgentCatalog catalog)
    extends ChangeNotifier
    implements ViewTool, ViewActions {
  this {
    _changes = session.surface.changes.listen((_) => _read());
    session
      ..addListener(_sessionChanged)
      ..attach(this);
    _read();
    if (kDebugMode) _requirements.checkExample(session.surface.agentSchema);
  }

  late final _requirements = ViewRequirements(catalog);
  late final StreamSubscription<Object?> _changes;

  /// The view the agent drew last, null before.
  DrawnComponents? _drawn;

  /// What the screen listed at the last read, null while a view cannot show
  /// on it: its data grew past the limit, the screen's list throws or does
  /// not fit the catalog.
  AgentListing? _listing;

  var _busy = false;
  var _disposed = false;
  SessionStatus? _status;

  @override
  JsonObject? definition(AgentListing listing) {
    if (_disposed || _requirements.conflictWith(listing) != null) return null;
    return {
      AgUiFields.name: ViewTool.name,
      AgUiFields.description: viewDescription(catalog, listing),
      AgUiFields.parameters: _parameters.schema,
    };
  }

  @override
  ToolAnswer show(JsonObject arguments) {
    if (_disposed || !session.isActive) {
      return .refused('No view is on the screen now.');
    }
    final listing = AgentListing.of(session.surface);
    switch (_requirements.check(arguments['components'], listing)) {
      case ViewToShow(:final view):
        _drawn = view;
        _listing = listing;
        notifyListeners();
        return ToolAnswer.shown;
      case ViewNotShown(:final answer):
        return answer;
    }
  }

  /// The view as widgets, an empty box before the agent draws, or
  /// [whenUnavailable] while it cannot show.
  Widget build(BuildContext context, WidgetBuilder whenUnavailable) {
    final drawn = _drawn;
    final listing = _listing;
    if (drawn == null) return const SizedBox.shrink();
    if (listing == null) return whenUnavailable(context);
    return ViewRender(drawn, listing, this).build() ?? const SizedBox.shrink();
  }

  @override
  ActionState stateOf(String method, {required bool field}) {
    final listing = _listing;
    if (_disposed || listing == null) return .unlisted;
    return _stateIn(listing, method, field: field);
  }

  /// The state of [method] by what [listing] says of it.
  ActionState _stateIn(
    AgentListing listing,
    String method, {
    required bool field,
  }) {
    if (!listing.lists(method)) return .unlisted;
    final needsApproval = listing.listedWithApproval(method);
    // An action that can never run here leaves its component out.
    if (needsApproval && (field || !session.asksForApproval)) return .unlisted;
    if (_busy || !session.isActive) return .waiting;
    if (needsApproval && !(session.asksForApproval && session.status is Idle)) {
      return .waiting;
    }
    return .available;
  }

  @override
  void call(
    String method,
    Map<String, ViewArgument> arguments,
    AgentListing seen, {
    FieldEntry? entry,
  }) {
    final field = entry != null;
    if (stateOf(method, field: field) != .available) return;
    final tool = seen.toolNamed(method);
    final now = _requirements.read(session.surface);
    if (tool == null || now == null) return;
    // The view was drawn with the last change the screen reported, and the
    // method may need approval since.
    if (_stateIn(now, method, field: field) != .available) return;
    final resolved = ActionArguments(
      arguments,
      tool,
      seen,
    ).resolve(now: now, entry: entry);
    if (resolved == null) return;
    _busy = true;
    notifyListeners();
    unawaited(_run(method, resolved, seen));
  }

  Future<void> _run(
    String method,
    JsonObject arguments,
    AgentListing seen,
  ) async {
    try {
      await session.callFor(.view, method, arguments, seen: seen);
    } catch (err, st) {
      report(err, st);
    } finally {
      _busy = false;
      if (!_disposed) notifyListeners();
    }
  }

  /// Detaches from the session: the next run no longer offers the tool, and
  /// a call of the open run is refused.
  @override
  void dispose() {
    _disposed = true;
    session
      ..removeListener(_sessionChanged)
      ..detach(this);
    unawaited(_changes.cancel());
    super.dispose();
  }

  void _read() {
    if (_disposed) return;
    _listing = _requirements.read(session.surface, view: _drawn);
    notifyListeners();
  }

  void _sessionChanged() {
    if (_disposed || session.status == _status) return;
    _status = session.status;
    notifyListeners();
  }

  static const List<AgentParameter<Object?>> _parameters = [
    // A string, because a model fills an object only with the properties
    // its schema names, and a component's depend on it.
    AgentParameter<String>(
      'components',
      .string,
      description:
          'The components of the view as a JSON array, as in the example.',
    ),
  ];
}
