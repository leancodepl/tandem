## 0.4.0

- **Breaking:** Upgrade `tandem` to 0.4.0 and run `dart run build_runner build` again.
- The builder writes an enum of the methods a class lists next to its mixin, such as `OrderCubitTool`, and each `AgentTool` names its method with it. A value's `value` and `toString()` give the name the agent calls, such as `set_quantity`.
- The build fails, naming both, when two listed methods would be the same member of the enum, or when the class's library already declares the enum's name.
- `example/example.md` shows the enum in the generated `AgentTool` and how an app matches it.
- The description and topics on pub.dev say what the builder writes and name GenUI and A2UI.

## 0.3.1

### Generation

- `@TandemAgent` uses its own `converters:` even when another annotation on the same class also declares converters.
- A catalog widget keeps its constructor default for a child widget or a nonempty list of children. The build names the property and leaves it out of the catalog so the widget supplies its default.
- The build rejects two getters or two methods with the same agent name and names both Dart members. Before, names such as `setUrl` and `setURL` both generated the tool `set_url`.
- The build rejects app methods whose tool names start with `tandem_`, the prefix reserved for Tandem tools.
- A catalog that lists an abstract widget fails at build time. Before, the generated code tried to construct the widget and failed to compile.
- Agent descriptions and catalog guidelines preserve Markdown list items and fenced code blocks from doc comments.
- Generated code preserves a literal `$` in identifiers such as field, getter and parameter names.

### Diagnostics

- An object parameter no longer triggers a build warning when the generator cannot find its type in `.sees`. At runtime its path must still point to a current value of the required type.
- Build errors explain when `agentCapabilities` must be a getter and name a converter whose output type Tandem cannot describe.
- Catalog errors explain how to handle a required `Key`, `FocusNode` or `ChangeNotifier` that the agent cannot set.
- Catalog example errors identify a non-string `id` or `component` and numbers too large for a `double`.

### Package documentation

- The README describes how Tandem 0.3.2 writes local date-times with their offset and reads a time with an offset or `Z` as the same instant in local time.
- The README explains that a `Uri` argument must have a scheme.
- The README describes how ag-ui-adk converts nullable schemas for Gemini without tying the explanation to version 0.9.0.
- The package page on pub.dev links to the Tandem website.

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
