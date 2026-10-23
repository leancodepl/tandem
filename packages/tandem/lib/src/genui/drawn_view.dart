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
import 'package:tandem/src/session/tandem_session.dart';
import 'package:tandem/src/session/tool_answer.dart';

/// What the in-app agent drew on one screen with `show_view`, as A2UI in a
/// processor of Tandem's catalog. It attaches to [session] at once. Its data
/// model holds a copy of what the screen lists with `.sees`, which only this
/// class writes, on every change of the surface.
final class DrawnView(final TandemSession session) implements AttachedView {
  this {
    _changes = session.surface.changes.listen((_) => _copySeesOrReport());
    session.attach(this);
  }

  final _processor = tandemProcessor();
  late final StreamSubscription<Object?> _changes;
  var _disposed = false;

  /// The surface the agent drew, null before it drew one.
  final surface = ValueNotifier<SurfaceModel<ComponentApi>?>(null);

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
      final listing = AgentListing.of(session.surface);
      final problems = ViewCheck(listing).problems(messages);
      if (problems.isNotEmpty) {
        return .refused(problems.join('\n'));
      }
      _draw(messages, listing);
      return .shown;
    }
    return .refused('Pass $_messages: a JSON array of A2UI messages.');
  }

  /// Detaches from the session; [show] refuses from now on.
  void dispose() {
    _disposed = true;
    session.detach(this);
    unawaited(_changes.cancel());
    _processor.dispose();
    surface.dispose();
  }

  void _draw(List<Object?> messages, AgentListing listing) {
    for (final drawn in [..._processor.model.allSurfaces]) {
      _processor.model.deleteSurface(drawn.id);
    }
    _processor.processMessages(messages);
    _copySees(listing);
    surface.value = _processor.model.allSurfaces.firstOrNull;
  }

  void _copySeesOrReport() {
    try {
      _copySees(AgentListing.of(session.surface));
    } catch (err, st) {
      report(err, st);
    }
  }

  void _copySees(AgentListing listing) {
    for (final drawn in _processor.model.allSurfaces) {
      for (final MapEntry(key: name, :value) in listing.seen.entries) {
        drawn.dataModel.set('/$name', value);
      }
    }
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
