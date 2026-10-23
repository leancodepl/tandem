import 'dart:convert';
import 'dart:developer' as developer;

import 'package:flutter/foundation.dart';
import 'package:tandem/src/agent_list.dart';
import 'package:tandem/src/chat/chat_item.dart';
import 'package:tandem/src/debug/open_screens.dart';
import 'package:tandem/src/protocol/ag_ui.dart';
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
  /// [describe] and [call] throw a [StateError] when an agent list does not
  /// fit the generated code, and the extension answers with it.
  static Future<Map<String, Object?>> call(
    String tool, {
    Map<String, Object?> arguments = const {},
    String? screen,
  }) async {
    final target = OpenScreens.find(screen);
    if (target == null) {
      return _withScreens(.refused(OpenScreens.whyNotFound(screen)));
    }
    return _withScreens(
      await target.session.calls.call(
        _autoApprove ? .automation : .codingAgent,
        tool,
        arguments,
      ),
    );
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
    final arguments = _decodeObject(parameters['arguments'] ?? '{}');
    if (tool == null) {
      return _withScreens(.refused('Pass the tool to call.'));
    }
    if (arguments == null) {
      return _withScreens(.refused('The arguments must be a JSON object.'));
    }
    return await call(tool, arguments: arguments, screen: parameters['screen']);
  }

  static JsonObject _describe(OpenScreen screen, {required bool front}) {
    final listing = AgentListing.of(screen.session.surface);
    final lastApproval = screen.session.calls.lastAsked(.codingAgent);
    return {
      'id': screen.id,
      'front': front,
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
        {'status': (call.request?.status ?? ApprovalStatus.pending).name},
  };

  static JsonObject _withScreens(ToolAnswer answer) => {
    ...answer.json,
    ...describe(),
  };

  static JsonObject? _decodeObject(String json) {
    try {
      return switch (jsonDecode(json)) {
        final JsonObject object => object,
        _ => null,
      };
    } on FormatException {
      return null;
    }
  }

  static developer.ServiceExtensionResponse _respond(JsonObject answer) =>
      .result(jsonEncode(answer));
}
