import 'package:firebase_ai/firebase_ai.dart';
import 'package:tandem/tandem.dart';
import 'package:tandem_firebase_ai/src/firebase_failure.dart';
import 'package:tandem_firebase_ai/src/firebase_request.dart';
import 'package:tandem_firebase_ai/src/firebase_runs.dart';

/// Runs a Tandem agent through Firebase AI Logic without an agent server.
///
/// Initialize Firebase and activate App Check before sending messages. Keep this
/// connection for the lifetime of its threads. Start over before replacing it.
/// Tools and approvals run in Tandem; Firebase only proposes calls.
final class FirebaseConnection({
  /// The app owns Firebase initialization, App Check and authentication.
  required FirebaseAI firebase,
  required String model,

  /// Application guidance included in the system instruction.
  String instructions = '',

  /// Native model settings. Multiple candidates, images and audio are rejected.
  GenerationConfig? generationConfig,
  List<SafetySetting>? safetySettings,

  /// How long credentials, response headers or the next bytes may take.
  Duration idleTimeout = const Duration(seconds: 60),
}) implements StoppableAgentConnection {
  this {
    if (model.trim().isEmpty) {
      throw ArgumentError.value(model, 'model', 'Must not be empty.');
    }
    if (idleTimeout <= Duration.zero) {
      throw ArgumentError.value(
        idleTimeout,
        'idleTimeout',
        'Must be positive.',
      );
    }
    if (_unsupportedConfig(generationConfig) case final reason?) {
      throw ArgumentError(reason);
    }
    final safety = safetySettings == null
        ? null
        : List<SafetySetting>.unmodifiable(safetySettings);
    _runs = FirebaseRuns(
      instructions: instructions,
      idleTimeout: idleTimeout,
      generate: (request, client) {
        // The SDK retains the caller's mutable list of response modalities.
        if (_unsupportedConfig(generationConfig) case final reason?) {
          throw FirebaseFailure(FirebaseErrorCode.invalidInput, reason);
        }
        return firebase
            .generativeModel(
              model: model,
              generationConfig: generationConfig,
              safetySettings: safety,
              systemInstruction: request.systemInstruction,
              tools: request.tools,
              httpClient: client,
            )
            .generateContentStream(request.contents);
      },
    );
  }

  late final FirebaseRuns _runs;

  @override
  Stream<JsonObject> run(JsonObject input) => _runs.run(input);

  /// Ends local delivery and aborts the HTTP request. Firebase may already have
  /// generated content; cancellation does not guarantee zero further charges.
  @override
  Future<void> stop(JsonObject input) => _runs.stop(input);
}

String? _unsupportedConfig(GenerationConfig? config) {
  if (config == null) return null;
  // Older models still accept candidateCount.
  // ignore: deprecated_member_use
  final count = config.candidateCount;
  if (count != null && count != 1) {
    return 'FirebaseConnection supports one candidate.';
  }
  if (config.responseModalities case final modalities?
      when modalities.any((modality) => modality != ResponseModalities.text)) {
    return 'FirebaseConnection supports text responses only.';
  }
  if (config.imageConfig != null || config.speechConfig != null) {
    return 'Image and speech generation are not supported.';
  }
  return null;
}
