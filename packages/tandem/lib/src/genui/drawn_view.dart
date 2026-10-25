import 'dart:async';

import 'package:a2ui_core/a2ui_core.dart';
import 'package:flutter/foundation.dart';
import 'package:tandem/src/agent_list.dart';
import 'package:tandem/src/genui/catalog.dart';
import 'package:tandem/src/genui/view_check.dart';
import 'package:tandem/src/genui/view_tool_description.dart';
import 'package:tandem/src/protocol/ag_ui.dart';
import 'package:tandem/src/report.dart';
import 'package:tandem/src/session/tandem_session.dart';
import 'package:tandem/src/session/tool_answer.dart';
import 'package:tandem/src/session/view_tool.dart';

/// What the in-app agent drew on one screen, attached to [session] from the
/// start. Its data model holds a copy of what the screen lists with `.sees`,
/// which only this class writes, on every change of the surface.
///
/// Notifies when the agent draws.
final class DrawnView(final TandemSession session)
    extends ChangeNotifier
    implements ViewTool {
  this {
    _changes = session.surface.changes.listen((_) => _copySees());
    session.attach(this);
  }

  late final StreamSubscription<Object?> _changes;
  MessageProcessor<ComponentApi>? _processor;
  var _disposed = false;

  /// What the agent drew last, or null before it drew.
  SurfaceModel<ComponentApi>? get surface =>
      _processor?.model.allSurfaces.singleOrNull;

  @override
  JsonObject get definition => {
    AgUiFields.name: ViewTool.name,
    AgUiFields.description: viewToolDescription,
    AgUiFields.parameters: {
      'type': 'object',
      'properties': {
        _messages: {
          'type': 'array',
          'items': {'type': 'object'},
        },
      },
      'required': [_messages],
    },
  };

  @override
  ToolAnswer show(JsonObject arguments) {
    if (_disposed) {
      return .refused('No view is on the screen now.');
    }
    final messages = arguments[_messages];
    if (messages is! List<Object?>) {
      return .refused('Pass "$_messages": a JSON array of A2UI messages.');
    }
    final listing = AgentListing.of(session.surface);
    final problems = ViewCheck(listing).problems(messages);
    if (problems.isNotEmpty) {
      return .refused(problems.join('\n'));
    }
    _processor?.dispose();
    _processor = tandemProcessor()..processMessages(messages);
    _copy(listing);
    notifyListeners();
    return ToolAnswer.shown;
  }

  /// Detaches from the session: the next run no longer offers the tool, and
  /// a call of the open run is refused.
  @override
  void dispose() {
    _disposed = true;
    session.detach(this);
    unawaited(_changes.cancel());
    _processor?.dispose();
    super.dispose();
  }

  void _copySees() {
    try {
      _copy(AgentListing.of(session.surface));
    } catch (err, st) {
      report(err, st);
    }
  }

  void _copy(AgentListing listing) {
    if (surface case final drawn?) {
      for (final MapEntry(key: name, :value) in listing.seen.entries) {
        drawn.dataModel.set('/$name', value);
      }
    }
  }
}

const _messages = 'messages';
