import Foundation
#if canImport(FoundationModels)
import FoundationModels

@available(iOS 26.0, macOS 26.0, *)
enum AppleToolSchema {
  static func make(_ schema: [String: Any], name: String) throws -> GenerationSchema {
    let schema = try normalized(schema, name: name)
    do {
      return try decode(schema)
    } catch {
      throw rejected(name, error)
    }
  }

  /// The tool's argument schema in the shape the Codable `GenerationSchema` reads.
  static func normalized(_ schema: [String: Any], name: String) throws -> [String: Any] {
    guard schema["type"] as? String == "object" else { throw unsupported(name, "Tool arguments must be an object.") }
    return try normalize(schema, name: name)
  }

  // The Codable schema supports explicit null unions that the 26 SDK's dynamic builder lacks.
  static func decode(_ schema: [String: Any]) throws -> GenerationSchema {
    try JSONDecoder().decode(GenerationSchema.self, from: JSONSerialization.data(withJSONObject: schema))
  }

  private static func rejected(_ name: String, _ error: Error) -> AppleFailure {
    unsupported(name, "The system rejected this schema: \(error)")
  }

  private static func normalize(_ schema: [String: Any], name: String) throws -> [String: Any] {
    let type = schema["type"] as? String
    var allowed: Set<String> = ["type", "description"]
    if schema["anyOf"] != nil { allowed.insert("anyOf") }
    switch type {
    case "object": allowed.formUnion(["properties", "required"])
    case "array": allowed.insert("items")
    case "string": allowed.insert("enum")
    default: break
    }
    if let key = Set(schema.keys).subtracting(allowed).sorted().first {
      throw unsupported(name, "Unsupported keyword: \(key).")
    }
    var result = schema
    if let choices = schema["anyOf"] {
      guard type == nil, let choices = choices as? [[String: Any]] else {
        throw unsupported(name, "anyOf must contain schemas and cannot also declare a type.")
      }
      result["title"] = name
      result["anyOf"] = try choices.enumerated().map { index, value in try normalize(value, name: "\(name)_c\(index)") }
      return result
    }
    switch type {
    case "object":
      guard let properties = schema["properties"] as? [String: [String: Any]] else {
        throw unsupported(name, "Objects need explicit properties.")
      }
      let keys = properties.keys.sorted()
      let required = schema["required"] as? [String] ?? []
      var normalized: [String: Any] = [:]
      for (index, key) in keys.enumerated() {
        if let property = properties[key] { normalized[key] = try normalize(property, name: "\(name)_p\(index)") }
      }
      result["title"] = name
      result["properties"] = normalized
      result["required"] = required
      result["additionalProperties"] = false
      result["x-order"] = keys
    case "array":
      guard let items = schema["items"] as? [String: Any] else { throw unsupported(name, "An array needs an item schema.") }
      result["items"] = try normalize(items, name: "\(name)_item")
    case "string", "integer", "number", "boolean", "null": break
    default: throw unsupported(name, "Unsupported or missing type.")
    }
    return result
  }

  private static func unsupported(_ name: String, _ message: String) -> AppleFailure {
    .init(.unsupportedSchema, "Cannot expose \(name): \(message)")
  }
}
#endif
