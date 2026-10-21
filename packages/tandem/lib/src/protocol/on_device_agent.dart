import 'dart:async';
import 'dart:convert';

import 'package:flutter/services.dart';
import 'package:tandem/src/errors.dart';
import 'package:tandem/src/protocol/ag_ui.dart';
import 'package:tandem/src/protocol/agent_connection.dart';
import 'package:tandem/src/protocol/apple_api.g.dart';
import 'package:tandem/src/protocol/on_device_instructions.dart';
import 'package:uuid/uuid.dart';

/// The current readiness of the system model. Check again after Settings change.
enum OnDeviceAvailability() {
  available,
  unsupportedPlatform,
  unsupportedSystem,
  deviceNotEligible,
  intelligenceDisabled,
  modelNotReady,
  unavailable,
}

/// The codes an [OnDeviceAgent] fails its runs with.
extension type const OnDeviceErrorCode._(String value) implements RunErrorCode {
  /// The conversation no longer fits the model. Tandem does not shorten it:
  /// `session.startOver()` sends the next message without the earlier
  /// history.
  static const contextWindowExceeded = OnDeviceErrorCode._(
    'CONTEXT_WINDOW_EXCEEDED',
  );

  /// A tool's parameters use JSON Schema the model cannot express, such as
  /// an open map or a `format`.
  static const unsupportedSchema = OnDeviceErrorCode._('UNSUPPORTED_SCHEMA');

  /// The model's arguments could not be kept exactly, such as an integer
  /// beyond 2^53 - 1.
  static const unsupportedArguments = OnDeviceErrorCode._(
    'UNSUPPORTED_ARGUMENTS',
  );

  /// The model cannot run now: [OnDeviceAgent.availability] says why.
  static const modelUnavailable = OnDeviceErrorCode._('MODEL_UNAVAILABLE');

  /// The history or the tools of the run do not form a native conversation.
  static const invalidInput = OnDeviceErrorCode._('INVALID_INPUT');

  /// The model's tool calls could not be handed to Tandem whole, so none
  /// runs.
  static const handoffFailed = OnDeviceErrorCode._('HANDOFF_FAILED');

  static const generationFailed = OnDeviceErrorCode._('GENERATION_FAILED');

  // Tandem drops a cancelled run, so no session can report this code.
  static const _cancelled = OnDeviceErrorCode._('CANCELLED');

  /// This platform has no on-device model.
  static const unsupportedPlatform = OnDeviceErrorCode._(
    'UNSUPPORTED_PLATFORM',
  );

  /// The native side answered in a shape Tandem does not read.
  static const invalidResponse = OnDeviceErrorCode._('INVALID_RESPONSE');
}

/// An on-device backend of the same AG-UI session used by remote agents.
/// Native callbacks only propose calls; Tandem executes and approves them.
final class OnDeviceAgent._() implements AgentConnection {
  /// Apple's system model on iOS/macOS 26+, with Apple Intelligence enabled.
  /// Returns the same immutable connection on every call, including in build.
  factory apple() => _apple;

  static final _apple = OnDeviceAgent._();
  static final _api = AppleHostApi();

  Future<OnDeviceAvailability> availability() async {
    try {
      return switch (await _api.availability()) {
        .available => .available,
        .unsupportedSystem => .unsupportedSystem,
        .deviceNotEligible => .deviceNotEligible,
        .intelligenceDisabled => .intelligenceDisabled,
        .modelNotReady => .modelNotReady,
        .unavailable => .unavailable,
      };
    } on PlatformException catch (error) {
      if (error.runErrorCode == OnDeviceErrorCode.unsupportedPlatform) {
        return .unsupportedPlatform;
      }
      rethrow;
    }
  }

  @override
  Stream<JsonObject> run(JsonObject input) => _NativeRun(_api, input).events;
}

/// One run of the native model, with its own request ID, task and model
/// session. The native side answers once, with the whole text or the whole
/// batch of calls.
final class _NativeRun(final AppleHostApi _api, final JsonObject _input) {
  final _requestId = const Uuid().v4();
  late final _controller = StreamController<JsonObject>(
    onListen: () => unawaited(_generate()),
    onCancel: _cancel,
  );
  var _nativeDone = false;

  Stream<JsonObject> get events => _controller.stream;

  Future<void> _generate() async {
    _controller.add(_event(AgUiEventTypes.runStarted));
    try {
      (await _answer()).forEach(_controller.add);
    } on Object catch (err, st) {
      // An answer Tandem cannot read breaks the run, as a stream error does.
      _controller.addError(err, st);
    } finally {
      _nativeDone = true;
    }
    await _controller.close();
  }

  /// The rest of the run, ending with `RUN_FINISHED` or `RUN_ERROR`.
  Future<List<JsonObject>> _answer() async {
    try {
      final input = _RunInput(_input);
      final reply = await _api.run(
        _requestId,
        jsonEncode(_input),
        onDeviceInstructions(
          toolNames: input.toolNames,
          context: _input[AgUiFields.context],
        ),
      );
      if (reply.failure case final failure?) {
        return [_runError(failure.runErrorCode, reply.message)];
      }

      return [
        ...switch (reply) {
          AppleReply(:final calls?) when calls.isNotEmpty => [
            for (final call in input.wholeBatch(calls)) ...call.events,
          ],
          AppleReply(:final text?) => _textEvents(text),
          _ => throw const FormatException(
            'The native model returned neither text nor calls.',
          ),
        },
        _event(AgUiEventTypes.runFinished),
      ];
    } on PlatformException catch (error) {
      return [_runError(error.runErrorCode, error.message)];
    } on FormatException catch (error) {
      return [_runError(OnDeviceErrorCode.invalidResponse, error.message)];
    }
  }

  Future<void> _cancel() async {
    if (_nativeDone) {
      return;
    }
    try {
      await _api.cancel(_requestId);
    } on PlatformException {
      // No plugin, or the engine has detached: no native task is left.
    }
  }

  JsonObject _event(String type) => {
    AgUiFields.type: type,
    AgUiFields.threadId: _input[AgUiFields.threadId],
    AgUiFields.runId: _input[AgUiFields.runId],
  };

  JsonObject _runError(RunErrorCode code, String? message) => {
    ..._event(AgUiEventTypes.runError),
    AgUiFields.code: code,
    AgUiFields.message: message ?? code,
  };

  List<JsonObject> _textEvents(String text) {
    final messageId = 'apple-text-$_requestId';
    return [
      {
        AgUiFields.type: AgUiEventTypes.textMessageStart,
        AgUiFields.messageId: messageId,
        AgUiFields.role: AgUiMessageRoles.assistant,
      },
      {
        AgUiFields.type: AgUiEventTypes.textMessageContent,
        AgUiFields.messageId: messageId,
        AgUiFields.delta: text,
      },
      {
        AgUiFields.type: AgUiEventTypes.textMessageEnd,
        AgUiFields.messageId: messageId,
      },
    ];
  }
}

extension on AppleCall {
  bool get hasObjectArguments => jsonDecode(arguments) is Map<String, Object?>;

  List<JsonObject> get events => [
    {
      AgUiFields.type: AgUiEventTypes.toolCallStart,
      AgUiFields.toolCallId: id,
      AgUiFields.toolCallName: name,
    },
    {
      AgUiFields.type: AgUiEventTypes.toolCallArgs,
      AgUiFields.toolCallId: id,
      AgUiFields.delta: arguments,
    },
    {AgUiFields.type: AgUiEventTypes.toolCallEnd, AgUiFields.toolCallId: id},
  ];
}

extension on AppleFailureCode {
  OnDeviceErrorCode get runErrorCode => switch (this) {
    .contextWindowExceeded => .contextWindowExceeded,
    .unsupportedSchema => .unsupportedSchema,
    .unsupportedArguments => .unsupportedArguments,
    .modelUnavailable => .modelUnavailable,
    .invalidInput => .invalidInput,
    .handoffFailed => .handoffFailed,
    .generationFailed => .generationFailed,
    .cancelled => ._cancelled,
  };
}

extension on PlatformException {
  // Pigeon's `channel-error` means no plugin answered, as on Android or the web.
  RunErrorCode get runErrorCode => switch (code) {
    'channel-error' => OnDeviceErrorCode.unsupportedPlatform,
    _ => RunErrorCode(code),
  };
}

extension type const _RunInput(JsonObject json) {
  Set<String> get toolNames => {
    if (json[AgUiFields.tools] case final List<Object?> tools)
      for (final tool in tools)
        if (tool case {AgUiFields.name: final String name}) name,
  };

  Set<String> get callIds => {
    if (json[AgUiFields.messages] case final List<Object?> messages)
      for (final message in messages)
        if (message case {AgUiFields.toolCalls: final List<Object?> calls})
          for (final call in calls)
            if (call case {AgUiFields.id: final String id}) id,
  };

  /// Returns [calls] when each is a current tool with object arguments and
  /// an ID unused in the batch and the history. Otherwise throws a
  /// [FormatException]: one such call means the batch was read wrong, so
  /// none of it can be trusted. The session would skip an unknown name as a
  /// server tool.
  List<AppleCall> wholeBatch(List<AppleCall> calls) {
    final ids = {for (final call in calls) call.id};
    final fits =
        ids.length == calls.length &&
        ids.intersection(callIds).isEmpty &&
        calls.every(
          (call) =>
              call.id.isNotEmpty &&
              toolNames.contains(call.name) &&
              call.hasObjectArguments,
        );
    if (fits) {
      return calls;
    }
    throw const FormatException('Invalid, duplicate or unavailable tool call.');
  }
}
