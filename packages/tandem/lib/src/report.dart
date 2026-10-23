import 'package:flutter/foundation.dart';

/// Reports an error Tandem caught to the app, never to the chat.
void report(Object error, StackTrace stack) => FlutterError.reportError(
  FlutterErrorDetails(exception: error, stack: stack, library: 'tandem'),
);
