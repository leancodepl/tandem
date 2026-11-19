import 'package:firebase_ai/firebase_ai.dart';
import 'package:http/http.dart' as http;
import 'package:tandem/tandem.dart';
import 'package:tandem_firebase_ai/src/ag_ui_events.dart';
import 'package:tandem_firebase_ai/src/ag_ui_input.dart';
import 'package:tandem_firebase_ai/src/firebase_answer.dart';
import 'package:tandem_firebase_ai/src/firebase_failure.dart';
import 'package:tandem_firebase_ai/src/firebase_request.dart';
import 'package:tandem_firebase_ai/src/firebase_run.dart';
import 'package:tandem_firebase_ai/src/json_object.dart';

/// Runs a Tandem agent through Firebase AI Logic without an agent server.
///
/// Initialize Firebase and activate App Check before sending messages. Keep this
/// connection for the lifetime of its threads. Start over before replacing it.
/// Tools and approvals run in Tandem; Firebase only proposes calls.
final class FirebaseConnection({
  required final FirebaseAI _firebase,
  required final String _model,

  /// Application guidance included in the system instruction.
  final String _instructions = '',

  /// Native model settings. Multiple candidates, images and audio are rejected.
  final GenerationConfig? _generationConfig,
  List<SafetySetting>? safetySettings,

  /// How long credentials, response headers or the next bytes may take.
  final Duration _idleTimeout = const Duration(seconds: 120),
}) implements StoppableAgentConnection {
  this {
    if (_model.trim().isEmpty) {
      throw ArgumentError.value(_model, 'model', 'Must not be empty.');
    }
    if (_idleTimeout <= Duration.zero) {
      throw ArgumentError.value(
        _idleTimeout,
        'idleTimeout',
        'Must be positive.',
      );
    }
    if (_generationConfig?.unsupportedReason case final reason?) {
      throw ArgumentError(reason);
    }
  }

  final List<SafetySetting>? _safetySettings = safetySettings == null
      ? null
      : List.unmodifiable(safetySettings);
  final _id = ConnectionId.unique();

  /// The runs by the identity of their input: the session passes the same
  /// object to [stop]. An `Expando` holds them weakly, so an ended run needs
  /// no removal.
  final _runs = Expando<FirebaseRun>();

  @override
  Stream<JsonObject> run(JsonObject input) {
    final AgUiInput runInput;
    try {
      runInput = .read(input);
    } on FormatException catch (error) {
      final failure = FirebaseFailure.invalidInput(error);
      return .value(AgUiEvents.runErrorEvent(failure.code, failure.message));
    }

    final run = FirebaseRun(
      runInput,
      generate: _generate,
      connectionId: _id,
      idleTimeout: _idleTimeout,
    );
    _runs[input] = run;
    return run.events;
  }

  /// Ends local delivery and aborts the HTTP request. Firebase may already have
  /// generated content; cancellation does not guarantee zero further charges.
  @override
  Future<void> stop(JsonObject input) async => _runs[input]?.stop();

  Stream<GenerateContentResponse> _generate(
    AgUiInput input,
    http.Client client,
  ) {
    // The SDK keeps the caller's list of response modalities, which the app
    // can still change.
    if (_generationConfig?.unsupportedReason case final reason?) {
      throw FirebaseFailure.unsupportedSettings(reason);
    }

    final request = FirebaseRequest(
      input,
      instructions: _instructions,
      connectionId: _id,
    );
    final model = _firebase.generativeModel(
      model: _model,
      generationConfig: _generationConfig,
      safetySettings: _safetySettings,
      systemInstruction: request.systemInstruction,
      tools: request.tools,
      httpClient: client,
    );
    return model.generateContentStream(request.contents);
  }
}

extension on GenerationConfig {
  /// Why this connection cannot serve the settings, or null when it can.
  String? get unsupportedReason {
    // Older models still accept candidateCount.
    // ignore: deprecated_member_use
    if (candidateCount case final count? when count != 1) {
      return 'FirebaseConnection supports one candidate.';
    }
    if (responseModalities case final modalities?
        when modalities.any((modality) => modality != .text)) {
      return 'FirebaseConnection supports text responses only.';
    }
    if (imageConfig != null || speechConfig != null) {
      return 'Image and speech generation are not supported.';
    }
    return null;
  }
}
