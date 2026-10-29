# The app defines the catalog of the views the agent draws

## Context

An agent that draws a view needs components. A catalog that Tandem ships, such as seven Material components, fits no app with its own design system, so no real app would use it. The app's widgets already have constructors, doc comments and callbacks, and its screens already hold DTOs from the backend, design tokens and colors. Whatever the agent writes in a view must reach those widgets as the types they take, and an action must reach a method with the checks of [ADR 0002](0002-agent-acts-only-through-listed-methods.md).

## Decision

The app lists the widget classes the agent may draw with, in `@TandemCatalog([...])`, and `tandem_generator` reads their constructors and doc comments. Tandem has no catalog of its own. Control stays in one place, the surface's `agentCapabilities`: a path can point only at a value it lists with `.sees`, and an action can call only a method it lists. A widget enters the catalog whole; there is no list of properties to hide.

Every type is described once. The generated code writes one `AgentType` expression for each place a type stands, which writes values for the agent, reads what the agent wrote, gives the JSON Schema, and gives the type and value at each path. The expression names no type: Dart infers it from the getter or parameter it stands at, so a library needs no import for the types inside the ones it declares. A type's id is its library and name, with the type arguments of a generic class, so two builds, such as a design system and an app, name it the same. Its fingerprint says how it is read and written. When a catalog and a screen describe one type with two fingerprints, such as `Color` with two converters, the view reports a configuration error and the agent is not offered the tool, in release too. Equal fingerprints do not prove that two converters of one class and configuration behave the same.

A class is read from its constructor and getters, never through `toJson`, so a backend's `@JsonValue` and `@JsonKey` do not change what the agent writes. A `JsonConverter<T, S>` of `json_annotation`, listed in `converters:`, gives a form to a type that cannot be read that way, or replaces the form of one that can. Tandem ships converters for `Color`, insets and alignments, which keep the alpha and the reading direction; an app's converter for the same type replaces them. `json_serializable` is not used: its helpers read numbers leniently and fail with a `TypeError` where Tandem refuses with the argument's path, and they let backend annotations decide the form.

An object of a class is passed by reference. A parameter of a class, of a method or of a widget, takes `{"path": ...}` to a value the screen lists, so the agent cannot make one up; `@TandemInput()` marks the parameter whose object the agent writes. A converter gives a form, never an origin: a class of the app that Tandem reads from its public unnamed constructor and getters is passed by reference with a converter too, and the agent writes the converter's form only with `@TandemInput()`. Any other type with a converter, such as `Color` or a `Version(major, minor)` with two positional parameters, is a value that the agent writes in the converter's form. A path is read at one of three times:

- **Run.** A call of the agent reads its paths against what its run sent. Before the method runs, the JSON at the path now must equal the JSON the run sent, so an earlier call of the run that reorders a list cannot point a later call at another object. The method gets the object at the path now.
- **Render.** A view reads its paths against the screen's data on every change, and its widgets get the screen's own objects. An action reads its paths against the data it was drawn with, and is refused when that changed since, so a tap drawn before a reorder calls nothing.
- **Approval.** A call that needs approval resolves its paths before it asks, and the request holds the arguments as JSON. The approved method gets objects built from that JSON, not the screen's, so a mutable object changed in place cannot change what runs. A change to `.sees` invalidates the request for good, as before.

The list of capabilities may depend on the route. The generated code copies `agentCapabilities` into an extension in which every `.sees` carries its getter's name, and Tandem reads the list through that copy, once, so the values, the getters they come from and the methods come from one read.

The views are read and drawn by Tandem, without `a2ui_core`. The components follow A2UI 0.9.1, but a binding gives the widget the screen's Dart object, which a JSON data model cannot.

## Consequences

- A widget the agent should use needs a doc comment, and the catalog a doc comment with guidelines and an example, which `TandemView` checks in debug against every value and method the screen may list.
- A catalog belongs to one screen, because its guidelines and example name that screen's data and methods. Another screen that draws with the same widgets declares its own catalog from the same list, as `@TandemCatalog([...DesignSystem.components])`, with its own guidelines and example. The debug check in `TandemView` reports an example that does not fit the screen it is on. A later `TandemView(example:)` could let screens share one catalog without breaking this.
- A required parameter of a type without a form, such as an app's `Version`, stops the build. An optional one keeps the widget's default. A value that the app should supply and the agent should not choose has no mechanism yet.
- Sealed classes, `Map`, `Duration` and `BigInt` have no form without a converter.
- Tool schemas are inline: a class the agent writes with `@TandemInput()` is defined in each tool that takes it.
- Code of `agentCapabilities` is copied into the generated file, so a getter that uses `super` fails the build.
- The model reads a description generated for each run from the catalog and the list, so a change of a doc comment changes what the model reads and needs a check on a real model.
