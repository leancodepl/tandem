import 'dart:convert';
import 'dart:developer' as developer;

import 'package:flutter/foundation.dart';
import 'package:tandem/src/agent_list.dart';
import 'package:tandem/src/debug/open_screens.dart';
import 'package:tandem/src/protocol/ag_ui.dart';
import 'package:tandem/src/session/tandem_session.dart';
import 'package:tandem/src/session/tool_answer.dart';
import 'package:tandem/src/session/tool_call.dart';

/// Lets a coding agent, such as Claude Code or Cursor, call the methods that
/// the open screens of a debug build list, as the in-app agent does. The
/// coding agent reaches the app through the Dart MCP server and the VM
/// service extensions `ext.tandem.describe` and `ext.tandem.call`:
///
/// ```dart
/// void main() {
///   TandemBridge.enable();
///   runApp(const App());
/// }
/// ```
///
/// Every `TandemScope` of a debug build is an open screen, also one without
/// `agent`. A call goes to the front screen: the only one open, or else the
/// only one on the current route. [describe] and [call] give the JSON of the
/// extensions, for tests.
final class TandemBridge._() {
  static var _registered = false;
  static var _autoApprove = false;

  /// What [describe] showed, by the `context` it gave, newest last.
  static final _contexts = <String, _Described>{};
  static var _lastContext = 0;
  static const _keptContexts = 32;

  /// Registers the extensions, once per isolate. Does nothing in a profile
  /// or release build.
  ///
  /// A call of a method listed with `.callsWithApproval` waits for the user,
  /// as the in-app agent's calls do. With [autoApprove], for automation,
  /// every call runs at once, also on a screen with `approvals: .none()`.
  /// The last call of [enable] holds.
  static void enable({bool autoApprove = false}) {
    if (kDebugMode) {
      _autoApprove = autoApprove;
      _register();
    }
  }

  /// The open screens under `screens`, each with its `id`, whether it is the
  /// `front` one, what the agent `sees`, the `tools` it may call and which of
  /// them `needsApproval`. Once a call of a coding agent asked the user, its
  /// `tool`, `arguments` and answer are the `lastApproval`: `pending` while
  /// the user decides, `approved` while the method runs.
  ///
  /// Each screen has a `context`, which a [call] whose arguments point at
  /// values with `{"path": ...}` passes back, so that the paths read what
  /// the coding agent saw. Only the latest contexts are kept.
  static Map<String, Object?> describe() {
    final front = OpenScreens.front;
    return {
      'screens': [
        for (final screen in OpenScreens.all)
          _describe(screen, front: identical(screen, front)),
      ],
    };
  }

  /// Calls [tool] with [arguments] on the front screen, or on the screen
  /// whose id is [screen]. The answer is the in-app agent's tool answer with
  /// its `status`, such as `returned` with the `result`, and the `screens`
  /// after the call.
  ///
  /// A call that waits for the user answers once the user decided, such as
  /// `rejected_by_user`. Meanwhile the same call waits for the same answer,
  /// and another call that needs approval is refused.
  ///
  /// An argument that points at a value of the screen, `{"path": ...}`,
  /// needs the [context] that [describe] gave for the screen: the call is
  /// refused without it, when it is unknown or when a new session of the
  /// scope replaced the one it showed, and a path whose value changed since
  /// is refused as for the in-app agent.
  ///
  /// [describe] and [call] throw a [StateError] when an agent list does not
  /// fit the generated code, and the extension answers with it.
  static Future<Map<String, Object?>> call(
    String tool, {
    Map<String, Object?> arguments = const {},
    String? screen,
    String? context,
  }) async {
    final target = OpenScreens.find(screen);
    if (target == null) {
      return _withScreens(.refused(OpenScreens.whyNotFound(screen)));
    }
    final described = switch (context) {
      final context? => _contexts[context],
      null => null,
    };
    if (described != null && !identical(described.screen, target)) {
      return _withScreens(
        .refused('The context $context is of another screen.'),
      );
    }
    if (described != null && !identical(described.session, target.session)) {
      return _withScreens(
        .refused(
          'The context $context is of an earlier session of this screen. '
          'Describe the screen again and pass its new context.',
        ),
      );
    }
    final seen =
        described?.seen ??
        AgentListing.of(target.session.surface).unseen(_noContext(context));
    final answer = await target.session.callFor(
      .codingAgent,
      tool,
      arguments,
      autoApprove: _autoApprove,
      seen: seen,
    );
    return _withScreens(switch (answer) {
      // The session cannot say how a coding agent gets approval.
      ToolAnswer.noApprovals => .refused(
        "$tool needs the user's approval, but this screen has approvals: "
        '.none(). TandemBridge.enable(autoApprove: true) approves the calls '
        'of a coding agent.',
      ),
      _ => answer,
    });
  }

  static void _register() {
    if (_registered) {
      return;
    }
    _registered = true;
    developer.registerExtension(
      'ext.tandem.describe',
      (_, _) async => _respond(describe()),
    );
    developer.registerExtension(
      'ext.tandem.call',
      (_, parameters) async => _respond(await _callWith(parameters)),
    );
  }

  static Future<JsonObject> _callWith(Map<String, String> parameters) async {
    final tool = parameters['tool'];
    final arguments = decodeJsonObject(parameters['arguments'] ?? '{}');
    if (tool == null) {
      return _withScreens(.refused('Pass the tool to call.'));
    }
    if (arguments == null) {
      return _withScreens(ToolAnswer.argumentsNotAnObject);
    }
    return await call(
      tool,
      arguments: arguments,
      screen: parameters['screen'],
      context: parameters['context'],
    );
  }

  static String _noContext(String? context) => switch (context) {
    null =>
      'The arguments point at values with "path". Pass the context that '
          'ext.tandem.describe gave for this screen, so that the paths read '
          'what you saw.',
    final context =>
      'The context $context is unknown or too old. Describe the screen again '
          'and pass its new context.',
  };

  static JsonObject _describe(OpenScreen screen, {required bool front}) {
    final session = screen.session;
    final listing = AgentListing.of(session.surface);
    final lastApproval = session.lastAsked(.codingAgent);
    final context = 'context-${++_lastContext}';
    _contexts[context] = (screen: screen, session: session, seen: listing);
    if (_contexts.length > _keptContexts) {
      _contexts.remove(_contexts.keys.first);
    }
    return {
      'id': screen.id,
      'front': front,
      'context': context,
      'sees': listing.context,
      'tools': listing.tools,
      'needsApproval': [
        for (final tool in listing.toolNames)
          if (listing.needsApproval(tool)) tool,
      ],
      if (lastApproval != null) 'lastApproval': _lastApproval(lastApproval),
    };
  }

  static JsonObject _lastApproval(ToolCall call) => {
    'tool': call.tool,
    'arguments': jsonDecode(call.argumentsJson),
    ...call.answer?.json ??
        {'status': call.approved ? ToolStatus.approved : ToolStatus.pending},
  };

  static JsonObject _withScreens(ToolAnswer answer) => {
    ...answer.json,
    ...describe(),
  };

  static developer.ServiceExtensionResponse _respond(JsonObject answer) =>
      .result(jsonEncode(answer));
}

/// What `describe` showed of a screen, from the session it read.
typedef _Described = ({
  OpenScreen screen,
  TandemSession session,
  AgentListing seen,
});
