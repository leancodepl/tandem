import Foundation
#if canImport(FoundationModels)
import FoundationModels
#endif

/// Why a native run failed.
struct AppleFailure: LocalizedError {
  /// The plugin sends it to Dart as Pigeon's `AppleFailureCode`.
  enum Code {
    case contextWindowExceeded, unsupportedSchema, unsupportedArguments, modelUnavailable
    case invalidInput, handoffFailed, generationFailed, cancelled
  }

  let code: Code
  let message: String
  var errorDescription: String? { message }

  init(_ code: Code, _ message: String) {
    self.code = code
    self.message = message
  }

  static func from(_ error: Error) -> AppleFailure {
    if let failure = error as? AppleFailure { return failure }
    if error is CancellationError { return .init(.cancelled, "The native run was cancelled.") }
    #if canImport(FoundationModels)
    if #available(iOS 26.0, macOS 26.0, *),
       case .exceededContextWindowSize = error as? LanguageModelSession.GenerationError {
      return .init(.contextWindowExceeded, "The conversation exceeds the model's context window. History was not shortened.")
    }
    #endif
    return .init(.generationFailed, String(describing: error))
  }
}

/// A call the model proposes. Tandem runs it, never the native side.
struct AppleProposedCall: Sendable {
  let id: String
  let name: String
  let arguments: String
}

/// One run's answer: the model's text, or the whole batch of calls it proposes.
enum AppleAnswer: Sendable {
  case text(String)
  case calls([AppleProposedCall])
}

enum AppleModel {
  /// [instructions] come from Dart, which owns Tandem's wording.
  @MainActor static func run(_ input: [String: Any], instructions: String) async throws -> AppleAnswer {
    #if canImport(FoundationModels)
    if #available(iOS 26.0, macOS 26.0, *), SystemLanguageModel.default.isAvailable {
      return try await respond(input, instructions: instructions)
    }
    #endif
    throw AppleFailure(.modelUnavailable, "OnDeviceAgent.availability() says why.")
  }

  #if canImport(FoundationModels)
  @available(iOS 26.0, macOS 26.0, *)
  @MainActor private static func respond(_ input: [String: Any], instructions: String) async throws -> AppleAnswer {
    guard let definitions = input["tools"] as? [[String: Any]],
          let messages = input["messages"] as? [[String: Any]] else {
      throw AppleFailure(.invalidInput, "A run needs tools and messages.")
    }
    let capture = AppleHandoffCapture()
    let tools = try handoffTools(definitions, capture: capture)
    let conversation = try AppleConversation(messages: messages, instructions: instructions, tools: tools)
    let session = LanguageModelSession(tools: tools, transcript: conversation.transcript)
    capture.attach(session)
    try Task.checkCancellation()
    do {
      let response: LanguageModelSession.Response<String>
      if let prompt = conversation.prompt {
        response = try await session.respond(to: prompt, options: .init(sampling: .greedy))
      } else {
        response = try await session.respond(options: .init(sampling: .greedy)) { }
      }
      try Task.checkCancellation()
      if capture.hasBatch {
        throw AppleFailure(.handoffFailed, "Generation succeeded after an intercepted tool request.")
      }
      return .text(response.content)
    } catch let error as LanguageModelSession.ToolCallError {
      try Task.checkCancellation()
      return .calls(try capture.finish(error))
    }
  }

  /// The current tools, each of which hands its calls to Tandem instead of running.
  @available(iOS 26.0, macOS 26.0, *)
  private static func handoffTools(_ definitions: [[String: Any]], capture: AppleHandoffCapture) throws -> [AppleHandoffTool] {
    try definitions.map { definition in
      guard let name = definition["name"] as? String,
            let description = definition["description"] as? String,
            let parameters = definition["parameters"] as? [String: Any] else {
        throw AppleFailure(.invalidInput, "Each current tool needs a name, description and parameter schema.")
      }
      return .init(name: name, description: description,
                   parameters: try AppleToolSchema.make(parameters, name: name), capture: capture)
    }
  }
  #endif
}
