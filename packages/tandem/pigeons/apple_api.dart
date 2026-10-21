// The typed boundary between OnDeviceAgent and its Swift plugin. Regenerate
// with the pigeon command in AGENTS.md.
import 'package:pigeon/pigeon.dart';

@ConfigurePigeon(
  PigeonOptions(
    dartOut: 'lib/src/protocol/apple_api.g.dart',
    dartTestOut: 'test/protocol/apple_api_test.g.dart',
    swiftOut: 'darwin/tandem/Sources/tandem/AppleApi.g.swift',
    dartPackageName: 'tandem',
  ),
)
enum AppleAvailability {
  available,
  unsupportedSystem,
  deviceNotEligible,
  intelligenceDisabled,
  modelNotReady,
  unavailable,
}

enum AppleFailureCode {
  contextWindowExceeded,
  unsupportedSchema,
  unsupportedArguments,
  modelUnavailable,
  invalidInput,
  handoffFailed,
  generationFailed,
  cancelled,
}

class AppleCall {
  AppleCall({required this.id, required this.name, required this.arguments});

  String id;
  String name;
  String arguments;
}

/// One run's answer: its text, its whole batch of calls, or why it failed.
class AppleReply {
  AppleReply({this.text, this.calls, this.failure, this.message});

  String? text;
  List<AppleCall>? calls;
  AppleFailureCode? failure;
  String? message;
}

@HostApi(dartHostTestHandler: 'TestAppleHostApi')
abstract class AppleHostApi {
  AppleAvailability availability();

  /// [inputJson] is the AG-UI body of the run.
  @async
  AppleReply run(String requestId, String inputJson, String instructions);

  /// Completes once the native task of [requestId] has ended.
  @async
  void cancel(String requestId);
}
