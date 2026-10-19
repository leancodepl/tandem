#if canImport(FoundationModels)
import FoundationModels

@available(iOS 26.0, macOS 26.0, *)
struct AppleToolSelection: Sendable {
  let name: String
  let arguments: String

  var dictionary: [String: Any] { ["kind": "tool", "name": name, "arguments": arguments] }
}

@available(iOS 26.0, macOS 26.0, *)
actor AppleToolSelectionRecorder {
  private(set) var first: AppleToolSelection?

  func record(_ selection: AppleToolSelection) {
    if first == nil { first = selection }
  }
}

@available(iOS 26.0, macOS 26.0, *)
struct AppleHandoffTool: Tool {
  let name: String
  let description: String
  let parameters: GenerationSchema
  let recorder: AppleToolSelectionRecorder

  func call(arguments: GeneratedContent) async throws -> String {
    try Task.checkCancellation()
    await recorder.record(.init(name: name, arguments: arguments.jsonString))
    // Tandem must execute this request after its run ends, with fresh state and approval.
    throw Handoff.pending
  }

  private enum Handoff: Error { case pending }
}
#endif
