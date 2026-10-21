import Foundation
#if canImport(FoundationModels)
import FoundationModels

/// The native transcript of one run, rebuilt from its AG-UI history. The
/// last user message becomes the prompt; a history that ends with tool
/// results continues without one.
@available(iOS 26.0, macOS 26.0, *)
struct AppleConversation {
  let transcript: Transcript
  let prompt: String?

  init(messages: [[String: Any]], instructions: String, tools: [AppleHandoffTool]) throws {
    var builder = AppleTranscriptBuilder(instructions: instructions, tools: tools)
    for message in messages.dropLast() {
      try builder.add(message)
    }
    guard let last = messages.last else { throw invalidInput("A run needs a user message or tool results.") }
    switch last["role"] as? String {
    case "user": prompt = try builder.prompt(last)
    case "tool":
      try builder.add(last)
      prompt = nil
    default: throw invalidInput("A run must follow a user message or completed tool results.")
    }
    transcript = try builder.finish()
  }
}

/// Adds the messages in order and keeps AG-UI's rules: the calls of one
/// assistant turn form one native batch, the batch closes at its first
/// result, and nothing else comes between a call and its result.
@available(iOS 26.0, macOS 26.0, *)
private struct AppleTranscriptBuilder {
  private var entries: [Transcript.Entry]
  private var messageIDs = Set<String>()
  private var toolNames: [String: String] = [:]
  private var unanswered = Set<String>()
  private var batch: [Transcript.ToolCall] = []

  /// The batch closed at its first result, and more results are due.
  private var answering: Bool { batch.isEmpty && !unanswered.isEmpty }

  init(instructions: String, tools: [AppleHandoffTool]) {
    entries = [.instructions(.init(segments: text(instructions), toolDefinitions: tools.map { .init(tool: $0) }))]
  }

  mutating func add(_ message: [String: Any]) throws {
    let id = try newID(message)
    switch message["role"] as? String {
    case "user": entries.append(.prompt(.init(id: id, segments: text(try userText(message)))))
    case "assistant": try addAssistant(message, id: id)
    case "tool": try addResult(message)
    default: throw invalidInput("Unsupported conversation role: \(message["role"] ?? "none").")
    }
  }

  mutating func prompt(_ message: [String: Any]) throws -> String {
    _ = try newID(message)
    return try userText(message)
  }

  func finish() throws -> Transcript {
    guard unanswered.isEmpty else { throw invalidInput("Every historical call needs its result.") }
    return .init(entries: entries)
  }

  private mutating func newID(_ message: [String: Any]) throws -> String {
    guard let id = message["id"] as? String, !id.isEmpty, messageIDs.insert(id).inserted else {
      throw invalidInput("Every message needs a unique nonempty ID.")
    }
    return id
  }

  private func userText(_ message: [String: Any]) throws -> String {
    guard unanswered.isEmpty, let content = message["content"] as? String else {
      throw invalidInput("User text cannot interrupt unresolved tool calls.")
    }
    return content
  }

  private mutating func addAssistant(_ message: [String: Any], id: String) throws {
    // An empty reply of the model stays in the AG-UI history but adds nothing here.
    if let content = message["content"] as? String, content != "" {
      guard unanswered.isEmpty else { throw invalidInput("Assistant text cannot interrupt unresolved tool calls.") }
      entries.append(.response(.init(id: id, assetIDs: [], segments: text(content))))
    }
    for call in message["toolCalls"] as? [[String: Any]] ?? [] {
      try addCall(call)
    }
  }

  private mutating func addCall(_ call: [String: Any]) throws {
    guard !answering,
          let id = call["id"] as? String, !id.isEmpty, toolNames[id] == nil,
          call["type"] as? String == "function", let function = call["function"] as? [String: Any],
          let name = function["name"] as? String, !name.isEmpty,
          let arguments = function["arguments"] as? String else {
      throw invalidInput("Historical calls need unique IDs and function names, before the results of their turn.")
    }
    batch.append(.init(id: id, toolName: name, arguments: try AppleArguments.decode(arguments)))
    unanswered.insert(id)
    toolNames[id] = name
  }

  private mutating func addResult(_ message: [String: Any]) throws {
    if let first = batch.first {
      entries.append(.toolCalls(.init(id: "calls-\(first.id)", batch)))
      batch.removeAll()
    }
    guard let id = message["toolCallId"] as? String, let name = toolNames[id],
          unanswered.remove(id) != nil, let content = message["content"] as? String else {
      throw invalidInput("A tool result needs text and a matching unresolved call ID.")
    }
    entries.append(.toolOutput(.init(id: id, toolName: name, segments: text(content))))
  }
}

@available(iOS 26.0, macOS 26.0, *)
private func text(_ value: String) -> [Transcript.Segment] { [.text(.init(content: value))] }

private func invalidInput(_ message: String) -> AppleFailure { .init(.invalidInput, message) }
#endif
