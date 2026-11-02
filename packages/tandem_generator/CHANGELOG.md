## 0.3.0

- **Breaking:** Upgrade `tandem` to 0.3.0 and run `dart run build_runner build` again.
- **Breaking:** Mark an object parameter with `@TandemInput()` when the agent should create it; otherwise list the objects it chooses from with `.sees`.
- **Breaking:** Keep `agentCapabilities` free of `super`, and write each `.sees` in that getter.
- **Breaking:** Match constructor parameter and getter types in classes Tandem reads from their constructors.
- **Breaking:** Supply a `JsonConverter` for Flutter values without a built-in form instead of relying on constructor and getter serialization.
- `@TandemCatalog([...])` generates a catalog from the app's widget constructors, including children, actions and fields. Its doc comment supplies guidelines and an example whose component and property names are checked during the build.
- `converters:` on `@TandemAgent` and `@TandemCatalog` accepts `JsonConverter<T, S>` values for types the app wants to describe differently.
- `.sees` may stand inside an `if`, a `switch` or a spread, so the agent list can follow the route.
- Supported types include `Uri`, `Set<T>`, token classes and classes with concrete generic type arguments.
- List parameters accept nullable elements and nested lists.
- A parameter's default may be a `static const` member of its class.
- Dependency bounds accept analyzer 13.3 and source_gen 4.2.4, allowing apps using auto_route_generator 10.6 to resolve.

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
