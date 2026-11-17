import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';

/// The errors reported to `FlutterError.onError` until the test ends, which
/// then no longer print.
List<FlutterErrorDetails> collectReports() {
  final reported = <FlutterErrorDetails>[];
  final onError = FlutterError.onError;
  FlutterError.onError = reported.add;
  addTearDown(() => FlutterError.onError = onError);
  return reported;
}
