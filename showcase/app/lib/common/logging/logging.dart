import 'dart:developer' as developer;

import 'package:flutter/foundation.dart';
import 'package:logging/logging.dart';
import 'package:tandem/tandem.dart';

final _flutter = Logger('Flutter');

/// Writes the app's log records to the developer log, with what Flutter and
/// the platform catch: a failure of the agent as a warning, since the
/// screens show it, and any other error as severe.
void setUpLogging() {
  Logger.root.level = kDebugMode ? Level.ALL : Level.INFO;
  Logger.root.onRecord.listen(_write);
  FlutterError.onError = _logFlutterError;
  PlatformDispatcher.instance.onError = (error, stack) {
    Logger('Platform').severe('Uncaught error', error, stack);
    return true;
  };
}

void _write(LogRecord record) => developer.log(
  record.message,
  time: record.time,
  sequenceNumber: record.sequenceNumber,
  level: record.level.value,
  name: record.loggerName,
  error: record.error,
  stackTrace: record.stackTrace,
);

void _logFlutterError(FlutterErrorDetails details) {
  if (details.exception case final Exception exception
      when details.library == 'tandem') {
    _flutter.warning(_agentFailure(exception), null, details.stack);
    return;
  }

  _flutter.severe(
    details.exceptionAsString(),
    details.exception,
    details.stack,
  );
  FlutterError.presentError(details);
}

/// What the log keeps of a failure of the agent. The body of an HTTP answer,
/// the message of a failed run and the source of what could not be read can
/// hold the conversation.
String _agentFailure(Exception exception) => switch (exception) {
  AgentHttpException(:final statusCode) => 'The agent answered $statusCode',
  AgentRunException(:final code) =>
    'The agent run failed: ${code ?? 'no code'}',
  FormatException(:final message) =>
    'The agent sent what the app could not read: $message',
  _ => '${exception.runtimeType}',
};
