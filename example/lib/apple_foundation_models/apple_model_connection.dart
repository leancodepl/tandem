import 'dart:async';
import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:tandem/tandem.dart';

class const AppleModelAvailability({
  required final bool available,
  required final String reason,
});

/// The local model selects one action per user message. Tandem executes and
/// approves it; the native host acknowledges the actual result without inference.
final class AppleModelConnection({
  final MethodChannel channel = const MethodChannel(
    'tandem/apple_foundation_models',
  ),
}) implements AgentConnection {
  final _error = ValueNotifier<String?>(null);

  ValueListenable<String?> get error => _error;

  Future<AppleModelAvailability> availability() async {
    try {
      final response = await channel.invokeMapMethod<String, Object?>(
        'availability',
      );
      return switch (response) {
        {'available': final bool available, 'reason': final String reason} =>
          .new(available: available, reason: reason),
        _ => const .new(
          available: false,
          reason: 'The native model returned an invalid availability status.',
        ),
      };
    } on MissingPluginException {
      return const .new(
        available: false,
        reason: 'This pilot needs its iOS or macOS native host.',
      );
    } on PlatformException catch (error) {
      return .new(
        available: false,
        reason: error.message ?? 'Could not check the local model.',
      );
    }
  }

  @override
  Stream<Map<String, Object?>> run(Map<String, Object?> input) {
    var cancelled = false;
    var finished = false;
    var invoked = false;
    late final StreamController<Map<String, Object?>> controller;

    Future<void> generate() async {
      _error.value = null;
      final ids = {'threadId': input['threadId'], 'runId': input['runId']};
      controller.add({'type': 'RUN_STARTED', ...ids});
      try {
        final runId = input['runId'];
        if (runId is! String || runId.isEmpty) {
          throw const FormatException('A local run needs a runId.');
        }
        if (_callsSinceUserMessage(input) >= 12) {
          throw PlatformException(
            code: 'TOOL_LIMIT',
            message: 'The local model reached 12 actions. Send a new message.',
          );
        }
        invoked = true;
        final response = await channel.invokeMapMethod<String, Object?>(
          'run',
          input,
        );
        if (cancelled) {
          return;
        }
        final events = _responseEvents(input, response);
        finished = true;
        events.forEach(controller.add);
        controller.add({'type': 'RUN_FINISHED', ...ids});
      } on Object catch (error) {
        if (!cancelled) {
          finished = true;
          final message = switch (error) {
            PlatformException(:final message?) => message,
            MissingPluginException() =>
              'This pilot needs its iOS or macOS native host.',
            _ => error.toString(),
          };
          _error.value = message;
          controller.add({
            'type': 'RUN_ERROR',
            ...ids,
            'code': error is PlatformException
                ? error.code
                : 'INVALID_RESPONSE',
            'message': message,
          });
        }
      } finally {
        if (!cancelled) {
          await controller.close();
        }
      }
    }

    controller = StreamController(
      onListen: () => unawaited(generate()),
      onCancel: () async {
        cancelled = true;
        if (!finished && invoked) {
          try {
            await channel.invokeMethod<void>('cancel', {
              'runId': input['runId'],
            });
          } on PlatformException {
            // Disposing the screen has no remaining listener for this error.
          } on MissingPluginException {
            // A non-Apple host has no native request to release.
          }
        }
      },
    );
    return controller.stream;
  }
}

List<Map<String, Object?>> _responseEvents(
  Map<String, Object?> input,
  Map<String, Object?>? response,
) => switch (response) {
  {'kind': 'text', 'text': final String text} when text.trim().isNotEmpty => [
    {
      'type': 'TEXT_MESSAGE_START',
      'messageId': 'apple-text-${input['runId']}',
      'role': 'assistant',
    },
    {
      'type': 'TEXT_MESSAGE_CONTENT',
      'messageId': 'apple-text-${input['runId']}',
      'delta': text,
    },
    {'type': 'TEXT_MESSAGE_END', 'messageId': 'apple-text-${input['runId']}'},
  ],
  {
    'kind': 'tool',
    'name': final String name,
    'arguments': final String arguments,
  } =>
    _toolEvents(input, name, arguments),
  _ => throw const FormatException('The local model returned no text or call.'),
};

List<Map<String, Object?>> _toolEvents(
  Map<String, Object?> input,
  String name,
  String arguments,
) {
  final tools = input['tools'];
  if (tools is! List<Object?> ||
      !tools.any((tool) => tool is Map && tool['name'] == name)) {
    throw FormatException('The local model selected an unlisted tool: $name.');
  }
  if (jsonDecode(arguments) is! Map<String, Object?>) {
    throw const FormatException('Tool arguments must be a JSON object.');
  }
  final toolCallId = 'apple-call-${input['runId']}';
  return [
    {'type': 'TOOL_CALL_START', 'toolCallId': toolCallId, 'toolCallName': name},
    {'type': 'TOOL_CALL_ARGS', 'toolCallId': toolCallId, 'delta': arguments},
    {'type': 'TOOL_CALL_END', 'toolCallId': toolCallId},
  ];
}

int _callsSinceUserMessage(Map<String, Object?> input) {
  var calls = 0;
  if (input['messages'] case final List<Object?> messages) {
    for (final message in messages.reversed) {
      if (message is Map) {
        if (message['role'] == 'user') {
          break;
        }
        if (message['role'] == 'tool') {
          calls++;
        }
      }
    }
  }
  return calls;
}
