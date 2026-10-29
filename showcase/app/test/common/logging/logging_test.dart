import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:logging/logging.dart';
import 'package:tandem/tandem.dart';
import 'package:waypoint/common/logging/logging.dart';

void main() {
  test(
    'a failure of the agent is a warning without its body, a bug severe',
    () {
      final flutterOnError = FlutterError.onError;
      final platformOnError = PlatformDispatcher.instance.onError;
      final presentError = FlutterError.presentError;
      addTearDown(() {
        FlutterError.onError = flutterOnError;
        PlatformDispatcher.instance.onError = platformOnError;
        FlutterError.presentError = presentError;
      });
      FlutterError.presentError = (_) {};
      final records = <LogRecord>[];
      final subscription = Logger.root.onRecord.listen(records.add);
      addTearDown(subscription.cancel);

      setUpLogging();
      FlutterError.reportError(
        const FlutterErrorDetails(
          exception: AgentHttpException(500, 'The conversation.'),
          library: 'tandem',
        ),
      );
      FlutterError.reportError(
        const FlutterErrorDetails(
          exception: AgentRunException(
            RunErrorCode('MODEL_ERROR'),
            'The conversation.',
          ),
          library: 'tandem',
        ),
      );
      FlutterError.reportError(
        const FlutterErrorDetails(
          exception: FormatException(
            'Unexpected character',
            '{"text": "The conversation." x}',
          ),
          library: 'tandem',
        ),
      );
      FlutterError.reportError(
        const FlutterErrorDetails(exception: _Offline(), library: 'tandem'),
      );
      FlutterError.reportError(
        FlutterErrorDetails(
          exception: StateError('No trip.'),
          library: 'tandem',
        ),
      );
      PlatformDispatcher.instance.onError?.call(
        StateError('No flight.'),
        StackTrace.empty,
      );

      expect(
        records.map(
          (record) => (record.level, record.loggerName, record.message),
        ),
        [
          (Level.WARNING, 'Flutter', 'The agent answered 500'),
          (Level.WARNING, 'Flutter', 'The agent run failed: MODEL_ERROR'),
          (
            Level.WARNING,
            'Flutter',
            'The agent sent what the app could not read: Unexpected character',
          ),
          (Level.WARNING, 'Flutter', '_Offline'),
          (Level.SEVERE, 'Flutter', 'Bad state: No trip.'),
          (Level.SEVERE, 'Platform', 'Uncaught error'),
        ],
      );
    },
  );
}

final class const _Offline() implements Exception;
