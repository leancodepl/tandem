import 'dart:async';

import 'package:a2ui_core/a2ui_core.dart';
import 'package:flutter/foundation.dart';
import 'package:tandem/src/agent_list.dart';
import 'package:tandem/src/genui/catalog.dart';
import 'package:tandem/src/genui/catalog_prompt.dart';
import 'package:tandem/src/genui/view_check.dart';
import 'package:tandem/src/protocol/ag_ui.dart';
import 'package:tandem/src/report.dart';
import 'package:tandem/src/session/attached_view.dart';
import 'package:tandem/src/session/session_status.dart';
import 'package:tandem/src/session/tandem_session.dart';
import 'package:tandem/src/session/tool_answer.dart';

/// What the in-app agent drew on one screen with `show_view`, as A2UI in a
/// processor of Tandem's catalog. It attaches to [session] at once. Its data
/// model holds a copy of what the screen lists with `.sees`, which only this
/// class writes, on every change of the surface. A press of a button calls
/// its method as the view, through the session.
///
/// Notifies when the drawing, the copy or a button's call changes.
final class DrawnView(final TandemSession session)
    extends ChangeNotifier
    implements AttachedView {
  this {
    _changes = session.surface.changes.listen((_) => _seesChanged());
    session.attach(this);
  }

  late final _processor = tandemProcessor(
    onAction: (action) => unawaited(_press(action)),
  );
  late final StreamSubscription<Object?> _changes;
  SurfaceModel<ComponentApi>? _surface;
  AgentListing? _listing;
  final _waiting = <String>{};
  var _disposed = false;

  /// The surface the agent drew, null before it drew one.
  SurfaceModel<ComponentApi>? get surface => _surface;

  @override
  JsonObject get tool => {
    AgUiFields.name: AttachedView.toolName,
    AgUiFields.description: catalogPrompt,
    AgUiFields.parameters: _parameters,
  };

  @override
  ToolAnswer show(JsonObject arguments) {
    if (_disposed) {
      return .refused('No view is on the screen now.');
    }
    if (arguments[_messages] case final List<Object?> messages) {
      final problems = ViewCheck(_listingNow).problems(messages);
      if (problems.isNotEmpty) {
        return .refused(problems.join('\n'));
      }
      _draw(messages);
      return .shown;
    }
    return .refused('Pass $_messages: a JSON array of A2UI messages.');
  }

  /// Whether the button [button] may call [tool] now: its last call has an
  /// answer, the screen lists [tool] and, when [tool] needs approval, the
  /// screen asks and the session is idle.
  bool canPress(String button, String tool) {
    final listing = _listingNow;
    if (_waiting.contains(button) || !listing.lists(tool)) {
      return false;
    }
    return !listing.needsApproval(tool) ||
        (session.asksForApproval && session.status is Idle);
  }

  /// Detaches from the session; [show] refuses from now on.
  @override
  void dispose() {
    _disposed = true;
    session.detach(this);
    unawaited(_changes.cancel());
    _processor.dispose();
    super.dispose();
  }

  // Read once per change of the surface, not on every build.
  AgentListing get _listingNow => _listing ??= AgentListing.of(session.surface);

  void _draw(List<Object?> messages) {
    for (final drawn in [..._processor.model.allSurfaces]) {
      _processor.model.deleteSurface(drawn.id);
    }
    _processor.processMessages(messages);
    _surface = _processor.model.allSurfaces.firstOrNull;
    _copySees();
    notifyListeners();
  }

  void _seesChanged() {
    _listing = null;
    try {
      _copySees();
    } catch (err, st) {
      report(err, st);
    }
    notifyListeners();
  }

  void _copySees() {
    if (_surface case final drawn?) {
      for (final MapEntry(key: name, :value) in _listingNow.seen.entries) {
        drawn.dataModel.set('/$name', value);
      }
    }
  }

  Future<void> _press(A2uiRendererAction action) async {
    final button = action.sourceComponentId;
    _waiting.add(button);
    notifyListeners();
    // The agent learns the answer from the session; the view shows `.sees`.
    await session.calls.call(.view, action.name, {...action.context});
    if (_disposed) {
      return;
    }
    _waiting.remove(button);
    notifyListeners();
  }
}

const _messages = 'messages';

const _parameters = {
  'type': 'object',
  'properties': {
    _messages: {
      'type': 'array',
      'items': {'type': 'object'},
    },
  },
  'required': [_messages],
};
