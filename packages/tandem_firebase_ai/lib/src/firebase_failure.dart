import 'package:tandem/tandem.dart';

/// Codes reported through Tandem's `RunFailed` event.
extension type const FirebaseErrorCode._(String value) implements RunErrorCode {
  /// The input or generation settings cannot form a supported Firebase request.
  static const invalidInput = FirebaseErrorCode._('FIREBASE_INVALID_INPUT');

  /// Start a new thread before changing connection or editing native history.
  static const incompatibleHistory = FirebaseErrorCode._(
    'FIREBASE_INCOMPATIBLE_HISTORY',
  );

  /// No tool from an invalid batch is handed to Tandem.
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

final class FirebaseFailure(final FirebaseErrorCode code, final String message)
    implements Exception {
  @override
  String toString() => message;
}
