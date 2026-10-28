import Foundation

struct SmokeFailure: LocalizedError {
  let errorDescription: String?
  init(_ message: String) { errorDescription = message }
}

@main struct AppleSmoke {
  @MainActor static func main() async throws {
    guard CommandLine.arguments.contains("--generate") else {
      print("Manual native adapter smoke. Pass --generate to use the real model. No app methods execute.")
      return
    }
    func output(_ object: [String: Any]) throws {
      print(String(decoding: try JSONSerialization.data(withJSONObject: object, options: [.sortedKeys]), as: UTF8.self))
    }
    func output(_ object: [String: Any], response: AppleAnswer) throws {
      let answer: [String: Any] = switch response {
      case .text(let text): ["kind": "text", "text": text]
      case .calls(let calls): ["kind": "tools", "calls": calls.map { ["id": $0.id, "name": $0.name, "arguments": $0.arguments] }]
      }
      var result = object
      result["response"] = answer
      try output(result)
    }
    func input(messages: [[String: Any]], tools: [[String: Any]]) -> [String: Any] {
      ["threadId": "manual", "runId": UUID().uuidString, "messages": messages, "tools": tools]
    }
    // Tandem's real instructions come from Dart; the smoke checks the native handoff.
    let instructions = "Use only the current tools. Use actual tool results for returned values; never invent them."
    func run(_ input: [String: Any]) async throws -> AppleAnswer {
      try await AppleModel.run(input, instructions: instructions)
    }
    let user: [String: Any] = ["id": "user", "role": "user", "content": "Use lookup exactly once for A and exactly once for B. Then report both returned opaque IDs."]
    let lookup: [String: Any] = ["name": "lookup", "description": "Read the opaque ID for a key. Use the exact returned value.", "parameters": [
      "type": "object", "properties": ["key": ["type": "string", "enum": ["A", "B"]]], "required": ["key"]
    ]]
    let first = try await run(input(messages: [user], tools: [lookup]))
    try output(["case": "batch-selection"], response: first)
    guard case .calls(let calls) = first, calls.count == 2 else {
      throw SmokeFailure("The model did not select the requested two calls.")
    }
    var history = [user]
    var answers: [[String: Any]] = []
    var opaqueIDs: [String] = []
    var keys = Set<String>()
    for call in calls {
      guard let args = try JSONSerialization.jsonObject(with: Data(call.arguments.utf8)) as? [String: String],
            let key = args["key"] else { throw SmokeFailure("Invalid call.") }
      keys.insert(key)
      history.append(["id": "asst-\(call.id)", "role": "assistant", "toolCalls": [["id": call.id, "type": "function", "function": ["name": call.name, "arguments": call.arguments]]]])
      let value = "opaque_" + UUID().uuidString.prefix(8)
      opaqueIDs.append(value)
      answers.append(["id": "tool-\(call.id)", "role": "tool", "toolCallId": call.id, "content": "{\"id\":\"\(value)\"}"])
    }
    guard keys == ["A", "B"] else { throw SmokeFailure("Wrong lookup keys.") }
    let resumed = try await run(input(messages: history + answers, tools: []))
    try output(["case": "results-only-with-removed-tool", "actualResults": answers], response: resumed)
    guard case .text(let text) = resumed, opaqueIDs.allSatisfy(text.contains) else {
      throw SmokeFailure("The model did not report the actual results.")
    }
    let nullable: [String: Any] = ["name": "set_note", "description": "Set a note or explicitly clear it with null.", "parameters": [
      "type": "object", "properties": ["note": ["anyOf": [["type": "string"], ["type": "null"]]]], "required": ["note"]
    ]]
    let nullResult = try await run(input(messages: [["id": "null-user", "role": "user", "content": "Call set_note once with note explicitly set to null."]], tools: [nullable]))
    try output(["case": "explicit-null-schema"], response: nullResult)
    guard case .calls(let nullableCalls) = nullResult, nullableCalls.count == 1,
          let call = nullableCalls.first,
          let object = try JSONSerialization.jsonObject(with: Data(call.arguments.utf8)) as? [String: Any], object["note"] is NSNull else {
      throw SmokeFailure("Explicit nullable arguments did not work.")
    }
    try output(["passed": true, "scope": "Native production runner only; no Flutter UI or application method execution."])
  }
}
