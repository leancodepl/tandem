import Foundation

@main
@MainActor
struct AppleFoundationModelsSmoke {
  static func main() async {
    if CommandLine.arguments.contains("--check") {
      do {
        try check()
        print("Checks passed: native history and truthful outcomes. No model was invoked.")
      } catch {
        print("Checks failed: \(error.localizedDescription)")
        exit(1)
      }
      return
    }
    let status = AppleFoundationModelsRunner.availability()
    if CommandLine.arguments.contains("--availability") {
      write(status.dictionary)
      return
    }
    let flow = CommandLine.arguments.contains("--flow")
    guard flow || CommandLine.arguments.contains("--smoke") else {
      print("Use --check without inference, --availability to check the model, --smoke for one real tool selection, or --flow for three real selections with result acknowledgments.")
      return
    }
    guard status.available else {
      write(status.dictionary)
      exit(1)
    }
    do {
      if flow {
        try await runFlow()
        return
      }
      let result = try await AppleFoundationModelsRunner.run([
        "runId": "manual-smoke",
        "tools": [[
          "name": "add",
          "description": "Adds an item to the shopping list.",
          "parameters": [
            "type": "object",
            "properties": ["item": ["type": "string"]],
            "required": ["item"],
          ],
        ]],
        "context": [["description": "items: What is on the shopping list now.", "value": "[]"]],
        "messages": [["id": "smoke-user", "role": "user", "content": "Add milk to my shopping list."]],
      ])
      write(result)
      guard result["kind"] as? String == "tool", result["name"] as? String == "add",
            let arguments = result["arguments"] as? String,
            let data = arguments.data(using: .utf8),
            let object = try JSONSerialization.jsonObject(with: data) as? [String: Any],
            (object["item"] as? String)?.lowercased() == "milk" else {
        print("Smoke failed: expected add(item: milk). No application operation was executed.")
        exit(1)
      }
    } catch {
      print("Smoke failed: \(error.localizedDescription)")
      exit(1)
    }
  }

  private static func runFlow() async throws {
    print("Flow uses real on-device inference with simulated successful tool results. No application method is invoked.")
    var messages: [[String: Any]] = [user("milk", "Add milk.")]
    let milk = try await run(step: "milk", items: [], messages: messages)
    let milkArguments = try expectTool(milk, name: "add", arguments: ["item": "milk"])
    messages += completedTool(id: "milk", name: "add", arguments: milkArguments)
    let milkReply = try await run(step: "milk-result", items: ["milk"], messages: messages)
    messages.append(try assistantText(id: "milk-result", response: milkReply))

    messages.append(user("bread", "Add bread."))
    let bread = try await run(step: "bread", items: ["milk"], messages: messages)
    let breadArguments = try expectTool(bread, name: "add", arguments: ["item": "bread"])
    messages += completedTool(id: "bread", name: "add", arguments: breadArguments)
    let breadReply = try await run(step: "bread-result", items: ["milk", "bread"], messages: messages)
    messages.append(try assistantText(id: "bread-result", response: breadReply))

    messages.append(user("clear", "Empty the list."))
    let clear = try await run(step: "clear", items: ["milk", "bread"], messages: messages)
    let clearArguments = try expectTool(clear, name: "clear", arguments: [:])
    messages += completedTool(id: "clear", name: "clear", arguments: clearArguments)
    let clearReply = try await run(step: "clear-result", items: [], messages: messages)
    _ = try assistantText(id: "clear-result", response: clearReply)
    print("Flow passed: add milk, acknowledge, add bread, acknowledge, clear, acknowledge.")
  }

  private static func run(step: String, items: [String], messages: [[String: Any]]) async throws -> [String: Any] {
    let itemsData = try JSONSerialization.data(withJSONObject: items)
    guard let itemsJSON = String(data: itemsData, encoding: .utf8) else {
      throw failed("Cannot encode the current list.")
    }
    var tools = [itemTool("add", "Adds an item to the list."), itemTool("remove", "Removes an item from the list.")]
    if !items.isEmpty {
      tools.append(["name": "clear", "description": "Empties the list.", "parameters": ["type": "object", "properties": [String: Any]()]])
    }
    let result = try await AppleFoundationModelsRunner.run([
      "threadId": "manual-flow",
      "runId": "manual-flow-\(step)",
      "state": [String: Any](),
      "messages": messages,
      "tools": tools,
      "context": [["description": "items: What is on the shopping list now.", "value": itemsJSON]],
      "forwardedProps": [String: Any](),
    ])
    write(["step": step, "response": result])
    return result
  }

  private static func itemTool(_ name: String, _ description: String) -> [String: Any] {
    [
      "name": name,
      "description": description,
      "parameters": ["type": "object", "properties": ["item": ["type": "string"]], "required": ["item"]],
    ]
  }

  private static func user(_ id: String, _ content: String) -> [String: Any] {
    ["id": "user-\(id)", "role": "user", "content": content]
  }

  private static func completedTool(id: String, name: String, arguments: String) -> [[String: Any]] {
    [
      ["id": "asst-\(id)", "role": "assistant", "toolCalls": [["id": id, "type": "function", "function": ["name": name, "arguments": arguments]]]],
      ["id": "tool-\(id)", "role": "tool", "toolCallId": id, "content": "null"],
    ]
  }

  private static func expectTool(_ result: [String: Any], name: String, arguments: [String: String]) throws -> String {
    guard result["kind"] as? String == "tool", result["name"] as? String == name,
          let json = result["arguments"] as? String, let data = json.data(using: .utf8),
          let object = try JSONSerialization.jsonObject(with: data) as? [String: String],
          object.mapValues({ $0.lowercased() }) == arguments else {
      throw failed("Expected \(name) with arguments \(arguments).")
    }
    return json
  }

  private static func assistantText(id: String, response: [String: Any]) throws -> [String: Any] {
    guard response["kind"] as? String == "text", let text = response["text"] as? String, text == "The action completed." else {
      throw failed("Expected an acknowledgment after the successful tool result, without repeating an operation.")
    }
    return ["id": "asst-text-\(id)", "role": "assistant", "content": text]
  }

  private static func failed(_ message: String) -> AppleFoundationModelsFailure {
    .init(code: "SMOKE_FAILED", message: message)
  }

  private static func check() throws {
    let outcomes = [
      ("null", "The action completed."),
      ("{\"value\":1}", "The action completed."),
      ("{\"status\":\"rejected_by_user\"}", "You rejected the action."),
      ("{\"status\":\"invalidated\"}", "The screen changed. The action was not run."),
      ("{\"status\":\"cancelled\"}", "The action was cancelled and did not run."),
      ("{\"status\":\"refused\"}", "The action was refused and did not run."),
      ("{\"status\":\"failed\"}", "The action failed and may have changed the screen. Check it before retrying."),
      ("{\"status\":\"result_unavailable\"}", "The action ran, but its result could not be read. Do not repeat it."),
      ("{\"status\":\"unknown\"}", "The action's outcome is unknown. Check the screen before retrying."),
    ]
    for (content, expected) in outcomes {
      guard try AppleToolOutcome.acknowledgment(content) == expected else {
        throw failed("Incorrect acknowledgment for \(content).")
      }
    }
    #if canImport(FoundationModels)
    if #available(iOS 26.0, macOS 26.0, *) {
      let messages = [user("milk", "Add milk.")] + completedTool(id: "milk", name: "add", arguments: "{\"item\":\"milk\"}")
      let conversation = try AppleConversation.make(messages: messages, context: [], tools: [])
      let roles = conversation.transcript.map { entry in
        switch entry {
        case .instructions: "instructions"
        case .prompt: "prompt"
        case .response: "response"
        case .toolCalls: "toolCalls"
        case .toolOutput: "toolOutput"
        @unknown default: "unknown"
        }
      }
      guard roles == ["instructions", "prompt", "toolCalls", "toolOutput"],
            conversation.acknowledgment == "The action completed." else {
        throw failed("Completed tool history must preserve native roles and end without inference.")
      }
      let next = try AppleConversation.make(messages: messages + [user("bread", "Add bread.")], context: [], tools: [])
      guard next.prompt == "Add bread.", next.acknowledgment == nil else {
        throw failed("Only a new user message should request generation.")
      }
      do {
        _ = try AppleConversation.make(messages: Array(messages.dropLast()), context: [], tools: [])
        throw failed("History without its tool result was accepted.")
      } catch let error as AppleFoundationModelsFailure where error.code == "INVALID_INPUT" {}
    }
    #endif
  }

  private static func write(_ value: [String: Any]) {
    if let data = try? JSONSerialization.data(withJSONObject: value, options: [.sortedKeys]),
       let json = String(data: data, encoding: .utf8) {
      print(json)
    }
  }
}
