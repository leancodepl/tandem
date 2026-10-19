import Foundation

enum AppleToolOutcome {
  static func acknowledgment(_ content: String) throws -> String {
    guard let data = content.data(using: .utf8),
          let result = try? JSONSerialization.jsonObject(with: data, options: [.fragmentsAllowed]) else {
      throw AppleFoundationModelsFailure(code: "INVALID_INPUT", message: "The tool result must be valid JSON.")
    }
    guard let object = result as? [String: Any], let status = object["status"] else {
      return "The action completed."
    }
    switch status as? String {
    case "rejected_by_user": return "You rejected the action."
    case "invalidated": return "The screen changed. The action was not run."
    case "cancelled": return "The action was cancelled and did not run."
    case "refused": return "The action was refused and did not run."
    case "failed": return "The action failed and may have changed the screen. Check it before retrying."
    case "result_unavailable": return "The action ran, but its result could not be read. Do not repeat it."
    default: return "The action's outcome is unknown. Check the screen before retrying."
    }
  }
}
