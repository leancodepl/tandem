import Foundation
#if canImport(FoundationModels)
import FoundationModels

@available(iOS 26.0, macOS 26.0, *)
enum AppleArguments {
  static func decode(_ json: String) throws -> GeneratedContent {
    guard let original = try? JSONSerialization.jsonObject(with: Data(json.utf8)) as? [String: Any] else {
      throw AppleFailure(.invalidInput, "Tool arguments must be a JSON object.")
    }
    let content = try GeneratedContent(json: json)
    try checkNumbers(content)
    let decoded = try JSONSerialization.jsonObject(with: Data(content.jsonString.utf8))
    guard try JSONSerialization.data(withJSONObject: original, options: [.sortedKeys]) ==
                JSONSerialization.data(withJSONObject: decoded, options: [.sortedKeys]) else {
      throw precisionFailure()
    }
    return content
  }

  /// Throws when [content] has an integral number beyond ±(2^53 - 1):
  /// GeneratedContent stores numbers as `Double`, which rounds it.
  static func checkNumbers(_ content: GeneratedContent) throws {
    switch content.kind {
    case .number(let value):
      guard value.isFinite, value.rounded() != value || abs(value) <= largestExactInteger else { throw precisionFailure() }
    case .array(let values):
      for value in values { try checkNumbers(value) }
    case .structure(let properties, _):
      for value in properties.values { try checkNumbers(value) }
    default: break
    }
  }

  private static let largestExactInteger = 9_007_199_254_740_991.0

  private static func precisionFailure() -> AppleFailure {
    .init(.unsupportedArguments, "Apple model arguments cannot preserve this numeric value. Integral arguments must be within ±(2^53 - 1).")
  }
}
#endif
