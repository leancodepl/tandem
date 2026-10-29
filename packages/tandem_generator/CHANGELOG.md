## 0.2.1

- An enum with its own `name` field reaches the agent by the name of its constant. Before, the generated code sent the field's value.
- The example shows the order form of Tandem's example app.

## 0.2.0

- A description joins the wrapped lines of its doc comment and keeps its paragraphs, so the agent reads whole sentences.
- A method can return `Future<T>?` or `FutureOr<T>?`. When it returns null, the agent gets null as the result.

## 0.1.0

- Generates the `_$Name` mixin of a class with `@TandemAgent()`: the names, doc comments and JSON Schemas of what its `agentCapabilities` list.
- Parameters, results and `.sees` values can be `String`, `bool`, `int`, `double`, `num`, `DateTime`, enums, extension types over `String`, `int`, `double`, `num` or `bool`, `List<T>` and plain classes. Any other type fails the build, which names the type and where it is.
- The schema of a nullable parameter is `anyOf` the schema of its type and `{"type": "null"}`.
