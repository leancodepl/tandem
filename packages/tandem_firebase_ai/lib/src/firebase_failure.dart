import 'dart:async';

import 'package:firebase_ai/firebase_ai.dart';
import 'package:tandem/tandem.dart';

/// Codes reported through Tandem's `RunFailed` event.
extension type const FirebaseErrorCode._(String value) implements RunErrorCode {
  /// The input or generation settings cannot form a supported Firebase request.
  static const invalidInput = FirebaseErrorCode._('FIREBASE_INVALID_INPUT');

  /// The thread is not one this connection can continue: another connection
  /// wrote its tool calls, the app changed them, or Firebase refused them.
  /// A new thread works.
  static const incompatibleHistory = FirebaseErrorCode._(
    'FIREBASE_INCOMPATIBLE_HISTORY',
  );

  /// Firebase answered with something the connection cannot trust: a shape
  /// the SDK cannot read, an unknown tool or no answer at all.
  static const invalidResponse = FirebaseErrorCode._(
    'FIREBASE_INVALID_RESPONSE',
  );

  /// The model returned a kind of content this connection cannot deliver.
  static const unsupportedResponse = FirebaseErrorCode._(
    'FIREBASE_UNSUPPORTED_RESPONSE',
  );

  static const generationFailed = FirebaseErrorCode._(
    'FIREBASE_GENERATION_FAILED',
  );
  static const timedOut = FirebaseErrorCode._('FIREBASE_TIMED_OUT');
  static const blocked = FirebaseErrorCode._('FIREBASE_BLOCKED');
  static const outputLimit = FirebaseErrorCode._('FIREBASE_OUTPUT_LIMIT');
}

/// Why a run failed: the [code] for the app and the [message] for its logs.
final class FirebaseFailure._(
  final FirebaseErrorCode code,
  final String message,
) implements Exception {
  /// What an error of the SDK or its transport means for the run.
  factory of(Object error) => switch (error) {
    final FirebaseFailure failure => failure,
    TimeoutException(:final message) => ._(
      .timedOut,
      message ?? 'Firebase did not respond in time.',
    ),
    // Not every exception of the SDK prints its message.
    FirebaseAIException(:final message) => ._(.generationFailed, message),
    _ => ._(.generationFailed, '$error'),
  };

  factory invalidInput(FormatException error) =>
      ._(.invalidInput, error.message);

  factory unsupportedSettings(String reason) => ._(.invalidInput, reason);

  factory callsWithoutStoredAnswer() => ._(
    .incompatibleHistory,
    'An assistant message has tool calls, but not the answer this connection '
    'stored for them. Start a new thread.',
  );

  factory unpairedToolResults() => ._(
    .incompatibleHistory,
    'The tool calls and tool results of the thread do not pair up. Start a '
    'new thread.',
  );

  factory promptBlocked(String? reason) =>
      ._(.blocked, reason ?? 'Firebase blocked the prompt.');

  /// The answer ended with [reason] instead of `STOP`.
  factory incompleteAnswer(FinishReason reason, String? finishMessage) {
    final FirebaseErrorCode code = switch (reason) {
      .maxTokens => .outputLimit,
      .safety ||
      .recitation ||
      .blocklist ||
      .prohibitedContent ||
      .spii ||
      .imageSafety ||
      .imageProhibitedContent ||
      .imageRecitation => .blocked,
      .malformedFunctionCall || .malformedResponse => .invalidResponse,
      // Firebase refused the thread's thought signatures, so sending the
      // thread again cannot work.
      .missingThoughtSignature => .incompatibleHistory,
      _ => .generationFailed,
    };
    return ._(
      code,
      finishMessage ??
          'Firebase ended without a complete answer (${reason.toJson()}).',
    );
  }

  factory unfinished() => ._(
    .generationFailed,
    'Firebase ended the stream before the answer finished: its last content '
    'has no finish reason.',
  );

  factory unreadableResponse() =>
      ._(.invalidResponse, 'Firebase returned a response the SDK cannot read.');

  factory unusableCalls() => ._(
    .invalidResponse,
    'The model called a tool the run does not offer, or Firebase gave a call '
    'an empty or repeated ID.',
  );

  factory emptyAnswer() =>
      ._(.invalidResponse, 'Firebase returned neither text nor tool calls.');

  factory severalCandidates() =>
      ._(.unsupportedResponse, 'Firebase returned several candidates.');

  factory groundedAnswer() =>
      ._(.unsupportedResponse, 'Firebase returned a grounded answer.');

  factory unsupportedPart() => ._(
    .unsupportedResponse,
    'Firebase returned a part that is neither text nor a function call.',
  );

  @override
  String toString() => '$code: $message';
}
