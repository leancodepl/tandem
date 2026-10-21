import Foundation
import FoundationModels

struct ContractFailure: Error { let message: String }

func require(_ condition: @autoclosure () throws -> Bool, _ message: String) throws {
  guard try condition() else { throw ContractFailure(message: message) }
}

@available(macOS 26.0, *)
func nativeContracts() throws {
  let valueSchema: [String: Any] = ["type": "object", "properties": [
    "value": ["anyOf": [["type": "string", "enum": ["low", "high"]], ["type": "null"]]],
    "items": ["type": "array", "items": ["type": "integer"]]
  ], "required": ["items"]]
  let schema = try AppleToolSchema.make(valueSchema, name: "example")
  let schemaJSON = String(decoding: try JSONEncoder().encode(schema), as: UTF8.self)
  let schemaObject = try JSONSerialization.jsonObject(with: Data(schemaJSON.utf8)) as? [String: Any]
  try require(schemaObject?["required"] as? [String] == ["items"], "Optional fields became required.")
  try require(schemaJSON.contains("\"null\"") && schemaJSON.contains("\"enum\""), "Nullable enum lost its shape.")
  for unsupported: [String: Any] in [
    ["type": "object", "properties": [:], "additionalProperties": true],
    ["type": "object", "properties": ["at": ["type": "string", "format": "date-time"]]],
  ] {
    do {
      _ = try AppleToolSchema.make(unsupported, name: "bad")
      throw ContractFailure(message: "Unsupported schema silently accepted.")
    } catch let error as AppleFailure { try require(error.code == .unsupportedSchema, "Wrong schema error.") }
  }
  guard let fallback = try AppleToolSchema.optionalNulls(AppleToolSchema.normalized(valueSchema, name: "example")) else {
    throw ContractFailure(message: "A nullable property gave no fallback.")
  }
  let fallbackJSON = String(decoding: try JSONEncoder().encode(AppleToolSchema.decode(fallback)), as: UTF8.self)
  let fallbackObject = try JSONSerialization.jsonObject(with: Data(fallbackJSON.utf8)) as? [String: Any]
  try require(fallbackObject?["required"] as? [String] == ["items"], "A nullable property stayed required.")
  try require(!fallbackJSON.contains("\"null\"") && fallbackJSON.contains("\"enum\""), "The null choice stayed or the enum was lost.")
  try require(AppleToolSchema.optionalNulls(AppleToolSchema.normalized(["type": "object", "properties": [:]], name: "plain")) == nil, "A schema without nulls changed.")
  print("PASS schema fidelity, optional nulls for older systems and explicit unsupported errors")

  let exact = try AppleArguments.decode("{\"n\":9007199254740991}")
  try require(exact.jsonString.contains("9007199254740991"), "Safe integer changed.")
  for json in ["{\"n\":9007199254740993}", "{\"nested\":[{\"n\":9223372036854775807}]}"] {
    do {
      _ = try AppleArguments.decode(json)
      throw ContractFailure(message: "Lossy native numeric arguments accepted.")
    } catch let error as AppleFailure { try require(error.code == .unsupportedArguments, "Wrong precision error.") }
  }
  print("PASS exact numeric arguments and rejection before silent rounding")

  func call(_ id: String, _ name: String = "old") -> [String: Any] {
    ["id": "assistant-\(id)", "role": "assistant", "toolCalls": [["id": id, "type": "function",
      "function": ["name": name, "arguments": "{\"sku\":\"X\"}"]]]]
  }
  func result(_ id: String, _ content: String) -> [String: Any] {
    ["id": "result-\(id)", "role": "tool", "toolCallId": id, "content": content]
  }
  let messages: [[String: Any]] = [
    ["id": "user", "role": "user", "content": "Read both."], call("a"), call("b"),
    result("a", "{\"id\":\"opaque_a\"}"), result("b", "{\"status\":\"rejected_by_user\"}")
  ]
  let conversation = try AppleConversation(messages: messages, instructions: "Contracts only.", tools: [])
  let batches = conversation.transcript.compactMap { entry -> Transcript.ToolCalls? in
    if case .toolCalls(let batch) = entry { return batch }; return nil
  }
  try require(batches.count == 1 && batches.first?.map(\.id) == ["a", "b"], "Separate AG-UI calls were not grouped in order.")
  try require(conversation.prompt == nil, "Results-only continuation added a user prompt.")
  let outputs = conversation.transcript.compactMap { entry -> String? in
    if case .toolOutput(let output) = entry, case .text(let text) = output.segments.first { return text.content }; return nil
  }
  try require(outputs == ["{\"id\":\"opaque_a\"}", "{\"status\":\"rejected_by_user\"}"], "Actual result or rejection was changed.")
  let followed = try AppleConversation(messages: messages + [["id": "follow", "role": "user", "content": "Now proceed."]], instructions: "Contracts only.", tools: [])
  try require(followed.prompt == "Now proceed.", "Final user message was lost.")
  let afterEmpty = try AppleConversation(messages: [
    ["id": "first", "role": "user", "content": "Hi."], ["id": "empty", "role": "assistant", "content": ""],
    ["id": "again", "role": "user", "content": "Again."]
  ], instructions: "Contracts only.", tools: [])
  try require(afterEmpty.prompt == "Again.", "An empty model reply broke the conversation.")
  do {
    _ = try AppleConversation(messages: Array(messages.dropLast()), instructions: "Contracts only.", tools: [])
    throw ContractFailure(message: "Unanswered historical call accepted.")
  } catch let error as AppleFailure { try require(error.code == .invalidInput, "Wrong history error.") }
  print("PASS AG-UI batching, exact results, removal and results-only continuation")

  let calls: [Transcript.ToolCall] = try ["a", "b"].map { id in
    .init(id: id, toolName: "lookup", arguments: try GeneratedContent(json: "{\"sku\":\"X\"}"))
  }
  let batch = Transcript.ToolCalls(id: "new", calls)
  let callbacks = try ["{ \"sku\" : \"X\" }", "{\"sku\":\"Y\"}"].map { try GeneratedContent(json: $0) }
  try require(try callbacks.map { try batch.contains(name: "lookup", arguments: $0) } == [true, false],
              "Callback membership ignored or misread the arguments.")
  let capture = AppleHandoffCapture()
  let tool = AppleHandoffTool(name: "lookup", description: "Test only", parameters: schema, capture: capture)
  struct RealError: Error {}
  do {
    _ = try capture.finish(.init(tool: tool, underlyingError: RealError()))
    throw ContractFailure(message: "Genuine tool failure was swallowed.")
  } catch is RealError {}
  let overflow = LanguageModelSession.GenerationError.exceededContextWindowSize(.init(debugDescription: "test"))
  try require(AppleFailure.from(overflow).code == .contextWindowExceeded, "Context overflow lost its code.")
  print("PASS callback membership, real-error preservation and context overflow")
}

@main struct Contracts {
  static func main() throws {
    guard #available(macOS 26.0, *) else { print("Requires macOS 26 SDK/runtime; no inference is used."); return }
    try nativeContracts()
  }
}
