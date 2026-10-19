import Foundation
#if os(iOS)
@preconcurrency import Flutter
#elseif os(macOS)
@preconcurrency import FlutterMacOS
#endif

@MainActor
final class AppleFoundationModelsChannel {
  private struct ActiveRun {
    let token: UUID
    let task: Task<Void, Never>
  }

  private let channel: FlutterMethodChannel
  private var runs: [String: ActiveRun] = [:]

  init(messenger: FlutterBinaryMessenger) {
    channel = FlutterMethodChannel(name: "tandem/apple_foundation_models", binaryMessenger: messenger)
    channel.setMethodCallHandler { [weak self] call, result in
      Task { @MainActor in self?.handle(call, result: result) }
    }
  }

  private func handle(_ call: FlutterMethodCall, result: @escaping FlutterResult) {
    switch call.method {
    case "availability":
      result(AppleFoundationModelsRunner.availability().dictionary)
    case "cancel":
      guard let input = call.arguments as? [String: Any], let runId = input["runId"] as? String else {
        result(FlutterError(code: "INVALID_INPUT", message: "Cancel needs a runId.", details: nil))
        return
      }
      runs.removeValue(forKey: runId)?.task.cancel()
      result(nil)
    case "run":
      guard let input = call.arguments as? [String: Any], let runId = input["runId"] as? String, !runId.isEmpty else {
        result(FlutterError(code: "INVALID_INPUT", message: "The run needs a nonempty runId.", details: nil))
        return
      }
      guard runs[runId] == nil else {
        result(FlutterError(code: "RUN_ALREADY_ACTIVE", message: "This run is already active.", details: nil))
        return
      }
      let token = UUID()
      let task = Task { @MainActor in
        defer {
          if self.runs[runId]?.token == token { self.runs.removeValue(forKey: runId) }
        }
        do {
          result(try await AppleFoundationModelsRunner.run(input))
        } catch is CancellationError {
          result(FlutterError(code: "CANCELLED", message: "The run was cancelled.", details: nil))
        } catch let error as AppleFoundationModelsFailure {
          result(FlutterError(code: error.code, message: error.message, details: nil))
        } catch {
          result(FlutterError(code: "GENERATION_FAILED", message: error.localizedDescription, details: nil))
        }
      }
      runs[runId] = ActiveRun(token: token, task: task)
    default:
      result(FlutterMethodNotImplemented)
    }
  }
}
