import Foundation
#if canImport(FoundationModels)
import FoundationModels

@available(iOS 26.0, macOS 26.0, *)
enum AppleToolSchema {
  static func make(_ schema: [String: Any], name: String) throws -> GenerationSchema {
    guard schema["type"] as? String == "object" else {
      throw unsupported(name, "tool arguments must be an object")
    }
    return try GenerationSchema(root: node(schema, name: name), dependencies: [])
  }

  private static func node(_ schema: [String: Any], name: String) throws -> DynamicGenerationSchema {
    let type = schema["type"] as? String
    var supported = Set(["type", "description", "title"])
    switch type {
    case "string": supported.insert("enum")
    case "object": supported.formUnion(["properties", "required", "additionalProperties"])
    case "array": supported.formUnion(["items", "minItems", "maxItems"])
    default: break
    }
    if let key = schema.keys.sorted().first(where: { !supported.contains($0) }) {
      throw unsupported(name, "unsupported schema keyword \(key)")
    }
    let description = schema["description"] as? String
    if let choices = schema["enum"] {
      guard schema["type"] as? String == "string", let values = choices as? [String], !values.isEmpty else {
        throw unsupported(name, "only nonempty string enums are supported")
      }
      return DynamicGenerationSchema(name: name, description: description, anyOf: values)
    }
    switch type {
    case "string": return DynamicGenerationSchema(type: String.self)
    case "boolean": return DynamicGenerationSchema(type: Bool.self)
    case "integer": return DynamicGenerationSchema(type: Int.self)
    case "number": return DynamicGenerationSchema(type: Double.self)
    case "array":
      guard let items = schema["items"] as? [String: Any] else {
        throw unsupported(name, "array items must have a schema")
      }
      let minimum = try count(schema["minItems"], name: name)
      let maximum = try count(schema["maxItems"], name: name)
      if let minimum, let maximum, minimum > maximum {
        throw unsupported(name, "minItems must not exceed maxItems")
      }
      return try DynamicGenerationSchema(
        arrayOf: node(items, name: "\(name)_item"),
        minimumElements: minimum,
        maximumElements: maximum
      )
    case "object":
      if let extra = schema["additionalProperties"], !(extra as? Bool == false) {
        throw unsupported(name, "open dictionaries are not supported")
      }
      guard let properties = schema["properties"] as? [String: [String: Any]] else {
        throw unsupported(name, "objects need explicit properties")
      }
      let required: Set<String>
      if let values = schema["required"] {
        guard let keys = values as? [String], keys.allSatisfy({ properties[$0] != nil }) else {
          throw unsupported(name, "required must list known properties")
        }
        required = Set(keys)
      } else {
        required = []
      }
      let entries = try properties.keys.sorted().map { key in
        let property = properties[key] ?? [:]
        return try DynamicGenerationSchema.Property(
          name: key,
          description: property["description"] as? String,
          schema: node(property, name: "\(name)_\(key)"),
          isOptional: !required.contains(key)
        )
      }
      return DynamicGenerationSchema(name: name, description: description, properties: entries)
    default:
      throw unsupported(name, "unsupported or missing type")
    }
  }

  private static func count(_ value: Any?, name: String) throws -> Int? {
    guard let value else { return nil }
    guard let integer = value as? Int, integer >= 0 else {
      throw unsupported(name, "array bounds must be nonnegative integers")
    }
    return integer
  }

  private static func unsupported(_ name: String, _ reason: String) -> AppleFoundationModelsFailure {
    .init(code: "UNSUPPORTED_SCHEMA", message: "Cannot expose \(name): \(reason).")
  }
}
#endif
