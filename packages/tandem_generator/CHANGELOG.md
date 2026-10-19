## 0.1.0

- Generates the `_$Name` mixin of a class with `@TandemAgent()`: the names, doc comments and JSON Schemas of what its `agentCapabilities` list.
- Parameters, results and `.sees` values can be `String`, `bool`, `int`, `double`, `num`, `DateTime`, enums, extension types over `String`, `int`, `double`, `num` or `bool`, `List<T>` and plain classes. Any other type fails the build, which names the type and where it is.
- The schema of a nullable parameter is `anyOf` the schema of its type and `{"type": "null"}`.
