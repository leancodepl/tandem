import Foundation
#if canImport(FoundationModels)
import FoundationModels

private struct HandoffPending: Error {}

/// The batch of calls the model proposes, read from the transcript by the
/// first tool callback. Its sibling callbacks check that they belong to it.
@available(iOS 26.0, macOS 26.0, *)
final class AppleHandoffCapture: @unchecked Sendable {
  private let lock = NSLock()
  // Weak, because the session holds the tools, which hold this capture.
  private weak var session: LanguageModelSession?
  private var historicalBatches = Set<String>()
  private var batch: Transcript.ToolCalls?

  var hasBatch: Bool { lock.withLock { batch != nil } }

  func attach(_ session: LanguageModelSession) {
    lock.withLock {
      self.session = session
      for entry in session.transcript {
        if case .toolCalls(let batch) = entry { historicalBatches.insert(batch.id) }
      }
    }
  }

  func record(name: String, arguments: GeneratedContent) throws {
    try lock.withLock {
      if batch == nil {
        guard let session else { throw failure("The native session is no longer attached.") }
        let current = session.transcript.compactMap { entry -> Transcript.ToolCalls? in
          guard case .toolCalls(let batch) = entry else { return nil }
          return historicalBatches.contains(batch.id) ? nil : batch
        }
        guard current.count == 1, let only = current.first else {
          throw failure("No unambiguous current native tool batch is visible.")
        }
        // Sibling callbacks check against this retained value after Apple's rollback.
        batch = only
      }
      guard try batch?.contains(name: name, arguments: arguments) == true else {
        throw failure("The callback does not belong to the captured batch.")
      }
    }
  }

  /// The captured calls, when [error] is the handoff rather than a real failure.
  func finish(_ error: LanguageModelSession.ToolCallError) throws -> [AppleProposedCall] {
    guard error.underlyingError is HandoffPending else { throw error.underlyingError }
    guard let batch = lock.withLock({ batch }) else { throw failure("The handoff contained no captured calls.") }
    return try batch.map { call in
      try AppleArguments.checkNumbers(call.arguments)
      return .init(id: call.id, name: call.toolName, arguments: call.arguments.jsonString)
    }
  }

  private func failure(_ message: String) -> AppleFailure { .init(.handoffFailed, message) }
}

@available(iOS 26.0, macOS 26.0, *)
extension Transcript.ToolCalls {
  /// Whether a call of this batch has [name] and the same JSON [arguments].
  func contains(name: String, arguments: GeneratedContent) throws -> Bool {
    let expected = try canonical(arguments.jsonString)
    return try contains { call in try call.toolName == name && canonical(call.arguments.jsonString) == expected }
  }
}

private func canonical(_ json: String) throws -> Data {
  try JSONSerialization.data(withJSONObject: JSONSerialization.jsonObject(with: Data(json.utf8)), options: [.sortedKeys])
}

@available(iOS 26.0, macOS 26.0, *)
struct AppleHandoffTool: Tool {
  let name: String
  let description: String
  let parameters: GenerationSchema
  let capture: AppleHandoffCapture

  func call(arguments: GeneratedContent) async throws -> String {
    try Task.checkCancellation()
    try capture.record(name: name, arguments: arguments)
    throw HandoffPending()
  }
}
#endif
