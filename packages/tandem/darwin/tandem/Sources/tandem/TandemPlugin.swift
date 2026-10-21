import Foundation
#if os(iOS) && canImport(Flutter)
import Flutter
#elseif os(macOS) && canImport(FlutterMacOS)
import FlutterMacOS
#endif
#if canImport(FoundationModels)
import FoundationModels
#endif

#if canImport(Flutter) || canImport(FlutterMacOS)
public final class TandemPlugin: NSObject, FlutterPlugin, AppleHostApi {
  /// The native tasks of the open runs, one per request ID. Pigeon starts
  /// every call on the main actor in order, so a cancel never overtakes its run.
  @MainActor private var tasks: [String: Task<AppleAnswer, Error>] = [:]

  public static func register(with registrar: FlutterPluginRegistrar) {
    #if os(iOS)
    let messenger = registrar.messenger()
    #else
    let messenger = registrar.messenger
    #endif
    AppleHostApiSetup.setUp(binaryMessenger: messenger, api: TandemPlugin())
  }

  func availability() throws -> AppleAvailability {
    #if canImport(FoundationModels)
    if #available(iOS 26.0, macOS 26.0, *) {
      switch SystemLanguageModel.default.availability {
      case .available: return .available
      case .unavailable(.deviceNotEligible): return .deviceNotEligible
      case .unavailable(.appleIntelligenceNotEnabled): return .intelligenceDisabled
      case .unavailable(.modelNotReady): return .modelNotReady
      case .unavailable: return .unavailable
      }
    }
    #endif
    return .unsupportedSystem
  }

  @MainActor func run(requestId: String, inputJson: String, instructions: String) async throws -> AppleReply {
    guard let input = try? JSONSerialization.jsonObject(with: Data(inputJson.utf8)) as? [String: Any] else {
      return AppleReply(failure: AppleFailure(.invalidInput, "A run needs a JSON object input."))
    }
    let task = Task { try await AppleModel.run(input, instructions: instructions) }
    tasks[requestId] = task
    defer { tasks[requestId] = nil }
    do {
      return AppleReply(answer: try await task.value)
    } catch {
      return AppleReply(failure: AppleFailure.from(error))
    }
  }

  @MainActor func cancel(requestId: String) async throws {
    guard let task = tasks[requestId] else { return }
    task.cancel()
    _ = await task.result
  }

  public func detachFromEngine(for registrar: FlutterPluginRegistrar) {
    MainActor.assumeIsolated {
      for task in tasks.values { task.cancel() }
    }
  }
}

private extension AppleReply {
  init(answer: AppleAnswer) {
    switch answer {
    case .text(let text): self.init(text: text)
    case .calls(let calls):
      self.init(calls: calls.map { AppleCall(id: $0.id, name: $0.name, arguments: $0.arguments) })
    }
  }

  init(failure: AppleFailure) {
    let code: AppleFailureCode = switch failure.code {
    case .contextWindowExceeded: .contextWindowExceeded
    case .unsupportedSchema: .unsupportedSchema
    case .unsupportedArguments: .unsupportedArguments
    case .modelUnavailable: .modelUnavailable
    case .invalidInput: .invalidInput
    case .handoffFailed: .handoffFailed
    case .generationFailed: .generationFailed
    case .cancelled: .cancelled
    }
    self.init(failure: code, message: failure.message)
  }
}
#endif
