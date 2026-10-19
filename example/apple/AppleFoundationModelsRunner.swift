import Foundation
#if canImport(FoundationModels)
import FoundationModels
#endif

struct AppleFoundationModelsFailure: LocalizedError {
  let code: String
  let message: String

  var errorDescription: String? { message }
}

struct AppleFoundationModelsAvailability {
  let available: Bool
  let reason: String

  var dictionary: [String: Any] { ["available": available, "reason": reason] }
}

enum AppleFoundationModelsRunner {
  static func availability() -> AppleFoundationModelsAvailability {
    #if canImport(FoundationModels)
    if #available(iOS 26.0, macOS 26.0, *) {
      switch SystemLanguageModel.default.availability {
      case .available:
        return .init(available: true, reason: "The on-device Apple model is ready.")
      case .unavailable(.deviceNotEligible):
        return .init(available: false, reason: "This device does not support Apple Intelligence.")
      case .unavailable(.appleIntelligenceNotEnabled):
        return .init(available: false, reason: "Enable Apple Intelligence in Settings first.")
      case .unavailable(.modelNotReady):
        return .init(available: false, reason: "The on-device Apple model is still downloading or preparing.")
      case .unavailable:
        return .init(available: false, reason: "The on-device Apple model is unavailable.")
      }
    }
    #endif
    return .init(available: false, reason: "This pilot requires iOS 26 or macOS 26 and an Apple Intelligence device.")
  }

  @MainActor
  static func run(_ input: [String: Any]) async throws -> [String: Any] {
    let status = availability()
    guard status.available else {
      throw AppleFoundationModelsFailure(code: "MODEL_UNAVAILABLE", message: status.reason)
    }
    #if canImport(FoundationModels)
    if #available(iOS 26.0, macOS 26.0, *) {
      return try await respond(input)
    }
    #endif
    throw AppleFoundationModelsFailure(code: "MODEL_UNAVAILABLE", message: status.reason)
  }

  #if canImport(FoundationModels)
  @available(iOS 26.0, macOS 26.0, *)
  @MainActor
  private static func respond(_ input: [String: Any]) async throws -> [String: Any] {
    guard let definitions = input["tools"] as? [[String: Any]],
          let messages = input["messages"] as? [[String: Any]],
          let context = input["context"] as? [[String: Any]] else {
      throw AppleFoundationModelsFailure(code: "INVALID_INPUT", message: "The run needs tools, messages and context arrays.")
    }
    let recorder = AppleToolSelectionRecorder()
    var names = Set<String>()
    let tools: [any Tool] = try definitions.map { definition in
      guard let name = definition["name"] as? String, !name.isEmpty,
            let description = definition["description"] as? String,
            let schema = definition["parameters"] as? [String: Any],
            names.insert(name).inserted else {
        throw AppleFoundationModelsFailure(code: "INVALID_INPUT", message: "Every tool needs a unique name, description and parameter schema.")
      }
      return AppleHandoffTool(
        name: name,
        description: description,
        parameters: try AppleToolSchema.make(schema, name: name),
        recorder: recorder
      )
    }
    let conversation = try AppleConversation.make(messages: messages, context: context, tools: tools)
    try Task.checkCancellation()
    if let acknowledgment = conversation.acknowledgment {
      // Ending after the actual result prevents unsolicited follow-up operations in this pilot.
      return ["kind": "text", "text": acknowledgment]
    }
    let session = LanguageModelSession(model: .default, tools: tools, transcript: conversation.transcript)
    try Task.checkCancellation()
    do {
      let response = try await session.respond(to: conversation.prompt, options: GenerationOptions(sampling: .greedy))
      try Task.checkCancellation()
      if let selection = await recorder.first {
        return selection.dictionary
      }
      return ["kind": "text", "text": response.content]
    } catch {
      try Task.checkCancellation()
      if let selection = await recorder.first {
        return selection.dictionary
      }
      throw error
    }
  }
  #endif
}
