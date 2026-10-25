import 'package:flutter/foundation.dart';

/// Reports an error that Tandem caught, so the app sees it as Flutter's
/// own.
void report(Object error, StackTrace stack) => FlutterError.reportError(
  FlutterErrorDetails(exception: error, stack: stack, library: 'tandem'),
);
