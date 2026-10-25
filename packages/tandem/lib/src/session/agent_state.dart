import 'dart:convert';

import 'package:rfc_6902/rfc_6902.dart';
import 'package:tandem/src/protocol/ag_ui.dart';

/// The state that the agent's backend keeps of a thread, as it streams it
/// with `STATE_SNAPSHOT` and `STATE_DELTA`. Every run sends it back, as
/// `@ag-ui/client` does, so a backend that keeps no state has it again.
final class AgentState() {
  JsonObject _value = const {};

  /// True from a delta that did not apply, or a snapshot that is not an
  /// object, until the next snapshot or run: the deltas in between were made
  /// for a state the app does not have.
  var _waitsForSnapshot = false;

  JsonObject get value => _value;

  /// Replaces the state with [snapshot]. Throws a [FormatException] when it
  /// is not a JSON object, and keeps the state.
  void replace(Object? snapshot) {
    if (snapshot is! JsonObject) {
      _waitsForSnapshot = true;
      throw const FormatException(
        'The agent sent a STATE_SNAPSHOT that is not a JSON object.',
      );
    }
    _value = snapshot;
    _waitsForSnapshot = false;
  }

  /// Applies [delta], JSON Patch operations, unless an earlier delta did
  /// not apply. Throws a [FormatException] when it does not apply or leaves
  /// no JSON object, and keeps the state.
  void patch(Object? delta) {
    if (_waitsForSnapshot) {
      return;
    }
    try {
      _value = _patched(delta);
    } on FormatException {
      _waitsForSnapshot = true;
      rethrow;
    }
  }

  /// A run starts from the state the app sends it, so its deltas apply
  /// again.
  void startRun() => _waitsForSnapshot = false;

  /// The empty state of a new thread.
  void clear() {
    _value = const {};
    _waitsForSnapshot = false;
  }

  JsonObject _patched(Object? delta) {
    if (delta is! List<Object?> || delta.any((op) => op is! JsonObject)) {
      throw const FormatException(
        'The agent sent a STATE_DELTA that is not a list of operations.',
      );
    }
    final Object? patched;
    try {
      patched = JsonPatch(delta).applyTo(_value);
    } on OperationFailure catch (failure) {
      throw FormatException(
        'The agent sent a STATE_DELTA that fails: $failure',
      );
    }
    // The patch copies maps untyped; the app reads what jsonDecode gives.
    if (jsonDecode(jsonEncode(patched)) case final JsonObject value) {
      return value;
    }
    throw const FormatException(
      'The agent sent a STATE_DELTA that leaves no JSON object.',
    );
  }
}
