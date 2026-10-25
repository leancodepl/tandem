import 'dart:async';

import 'package:a2ui_core/a2ui_core.dart';
import 'package:flutter/foundation.dart';
import 'package:tandem/src/agent_list.dart';
import 'package:tandem/src/genui/a2ui.dart';
import 'package:tandem/src/genui/catalog.dart';
import 'package:tandem/src/genui/view_check.dart';
import 'package:tandem/src/genui/view_tool_description.dart';
import 'package:tandem/src/protocol/ag_ui.dart';
import 'package:tandem/src/report.dart';
import 'package:tandem/src/session/session_status.dart';
import 'package:tandem/src/session/tandem_session.dart';
import 'package:tandem/src/session/tool_answer.dart';
import 'package:tandem/src/session/view_tool.dart';

/// What the in-app agent drew on one screen, attached to [session] from the
/// start. Its data model holds a copy of what the screen lists with `.sees`,
/// which only this class writes, on every change of the surface. A press on
/// a button calls its method for the view, through the session.
///
/// Notifies when a press starts or ends and when the surface changes, for
/// the buttons.
final class DrawnView(final TandemSession session)
    extends ChangeNotifier
    implements ViewTool {
  this {
    _changes = session.surface.changes.listen((_) => _seesChanged());
    session.attach(this);
  }

  /// What the agent drew last, or null before it drew.
  final surface = ValueNotifier<SurfaceModel<ComponentApi>?>(null);

  late final StreamSubscription<Object?> _changes;
  MessageProcessor<ComponentApi>? _processor;

  /// The agent list as the buttons read it, since the last change of the
  /// surface.
  AgentListing? _listing;

  /// The buttons whose call has no answer yet. A button of a list template
  /// is one per item.
  final _pressed = <_ButtonKey>{};
  var _disposed = false;

  @override
  JsonObject get definition => {
    AgUiFields.name: ViewTool.name,
    AgUiFields.description: viewToolDescription,
    AgUiFields.parameters: {
      'type': 'object',
      'properties': {
        'messages': {
          'type': 'array',
          'items': {'type': 'object'},
        },
      },
      'required': ['messages'],
    },
  };

  @override
  ToolAnswer show(JsonObject arguments) {
    if (_disposed) {
      return .refused('No view is on the screen now.');
    }
    final messages = arguments['messages'];
    if (messages is! List<Object?>) {
      return .refused('Pass "messages": a JSON array of A2UI messages.');
    }
    final listing = AgentListing.of(session.surface);
    final problems = ViewCheck(listing).problems(messages);
    if (problems.isNotEmpty) {
      return .refused(problems.join('\n'));
    }
    final processor = tandemProcessor()..processMessages(messages);
    _listing = listing;
    final drawn = processor.model.allSurfaces.single;
    _copy(listing, drawn);
    surface.value = drawn;
    _processor?.dispose();
    _processor = processor;
    return ToolAnswer.shown;
  }

  /// Whether [button] may be pressed now: its last press has an answer, the
  /// screen lists its method and, when the method needs approval, the screen
  /// asks and the session is idle.
  bool canPress(ComponentNode<ComponentApi> button) {
    final method = _actionOf(button)?.method;
    final listing = _listing;
    if (method == null ||
        listing == null ||
        _pressed.contains(button.key) ||
        !listing.lists(method)) {
      return false;
    }
    return !listing.needsApproval(method) ||
        (session.asksForApproval && session.status is Idle);
  }

  /// Calls the method of [button] for the view, with the arguments its
  /// action names, and keeps it pressed until the call has an answer.
  Future<void> press(ComponentNode<ComponentApi> button) async {
    if (_actionOf(button) case (:final method, :final arguments)) {
      _pressed.add(button.key);
      notifyListeners();
      try {
        await session.callFor(.view, method, arguments);
      } finally {
        _pressed.remove(button.key);
        if (!_disposed) {
          notifyListeners();
        }
      }
    }
  }

  /// Detaches from the session: the next run no longer offers the tool, and
  /// a call of the open run is refused.
  @override
  void dispose() {
    _disposed = true;
    session.detach(this);
    unawaited(_changes.cancel());
    surface.dispose();
    _processor?.dispose();
    super.dispose();
  }

  void _seesChanged() {
    try {
      final listing = _listing = AgentListing.of(session.surface);
      if (surface.value case final drawn?) {
        _copy(listing, drawn);
      }
    } catch (err, st) {
      _listing = null;
      report(err, st);
    }
    notifyListeners();
  }

  static void _copy(AgentListing listing, SurfaceModel<ComponentApi> drawn) {
    for (final MapEntry(key: name, :value) in listing.seen.entries) {
      drawn.dataModel.set('/$name', value);
    }
  }

  /// The method that [button] calls, with its arguments read from the data
  /// now.
  static ({String method, JsonObject arguments})? _actionOf(
    ComponentNode<ComponentApi> button,
  ) {
    final context = button.context;
    final action = context?.dataContext.resolveAction(
      context.componentModel.properties[A2uiFields.action],
    );
    return switch (action) {
      {
        A2uiFields.event: {
          A2uiFields.name: final String method,
          A2uiFields.context: final JsonObject arguments,
        },
      } =>
        (method: method, arguments: arguments),
      _ => null,
    };
  }
}

typedef _ButtonKey = ({String componentId, String dataPath});

extension on ComponentNode<ComponentApi> {
  _ButtonKey get key => (componentId: componentId, dataPath: dataPath);
}
