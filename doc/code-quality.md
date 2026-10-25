# Code quality

Keep the main decisions visible and details easy to skip. Dense expressions and
excessive indirection both add reading work.

## Principles

1. **KISS: prefer less code.** Reuse project code, framework APIs and suitable
   libraries before implementing an equivalent. Keep only what current
   requirements need. Each abstraction must save more work than it adds. Apply
   this discipline to documentation and tooling too.
2. **Keep a flow at one level of detail.** An entry point coordinates meaningful
   steps. Give parsing, rendering and diagnostics their own place when their
   detail obscures those steps. Keep an obvious operation inline.
3. **Make decisions easy to follow.** Prefer early returns for stepwise checks.
   A short guard fits on one line, such as `if (mixins.isEmpty) return null;`,
   and often reads better than a ternary or a `switch` with a guard. Give a
   coherent condition a precise name when that removes work from the caller.
   Keep distinct failures visible when they need different handling. Prefer
   positive predicates and clear branches over a leading `!condition`, which is
   easy to miss. Keep logical negation only when it makes the condition
   substantially clearer. Rephrase the decision rather than adding `== false`.
4. **Make names and call sites explain intent.** Name an operation for what it
   does and a predicate for what it actually guarantees. Use named arguments
   where roles would otherwise be ambiguous. Compute complex inputs before the
   call, with names that explain their purpose.
5. **Keep detail with its owner.** Put related data and behavior together, and
   peer steps next to each other. Use types for real domain alternatives and
   translate boundary strings once. A value with meaning gets a narrow type,
   not `Object`, a raw `List` or a `Map`. An app never types a protocol
   string: a code is a constant on its type, next to what produces it. An
   identity comes from one constructor, not from each caller. A constant
   belongs where its meaning is owned; a top-level declaration can be
   appropriate too.

For top-down reading, start a file with imports and its main declaration, then
private supporting types and local extensions. Within a class, start with
constructors, constants and state, then public behavior and private details.
Lifecycle grouping can make a better reading order than a strict public/private
split.

Use Dart 3.13 primary constructors and dot shorthands. Prefer switch expressions
for compact alternatives. Let the configured lints and formatter own whitespace,
with blank lines between meaningful steps where they permit. Simple `??`
fallbacks and natural positional arguments can be the clearest expression of
an operation.

## Examples of decisions

The generator snippets below are design sketches, with helper responsibilities
explained alongside them. The UI and session examples link to live code. The
alternatives illustrate tradeoffs rather than syntax bans.

### One qualification, one failure

This condition combines type discovery with the rules for an eligible method:

```dart
final method = item is SimpleIdentifier ? item.element : null;
if (method is! MethodElement ||
    method.isStatic ||
    method.typeParameters.isNotEmpty) {
  throw AgentGenerationError.invalidMethod(item, type);
}
```

Splitting every condition makes one qualification look like three decisions:

```dart
if (method is! MethodElement) {
  throw AgentGenerationError.invalidMethod(item, type);
}

if (method.isStatic) {
  throw AgentGenerationError.invalidMethod(item, type);
}

if (method.typeParameters.isNotEmpty) {
  throw AgentGenerationError.invalidMethod(item, type);
}
```

After checking that `item` is a `SimpleIdentifier`, the caller reads the intent:

```dart
final method = item.element;

if (method is! MethodElement || !method.isNonGenericInstanceMethod) {
  throw AgentGenerationError.invalidMethod(item, type);
}
```

The local extension names exactly the qualification it checks:

```dart
extension on MethodElement {
  bool get isNonGenericInstanceMethod => !isStatic && typeParameters.isEmpty;
}
```

`validate` would overstate this check: documentation and supported parameter
types are checked elsewhere. Separate guards remain useful when each failure
has its own diagnosis or recovery. A small condition needs no helper if its
meaning is already apparent.

### Prepare inputs, then name their roles

This call makes the reader infer the argument roles while following conversions:

```dart
return AgentMixin(
  type.displayName,
  [for (final item in visitor.sees) _readView(item, type)],
  {for (final item in visitor.calls) _readMethod(item, type)},
).generate();
```

With reading owned by `_CapabilityReader`, construction shows the result:

```dart
final reader = _CapabilityReader(type);
final capabilities = await reader.read(buildStep);

final mixin = AgentMixin(
  className: type.displayName,
  views: capabilities.views,
  methods: capabilities.methods,
);

return mixin.generate();
```

The reader owns source traversal and validation; the mixin owns rendering. For a
simple conversion, local collections can be enough. A single natural dependency
such as `_CapabilityReader(type)` stays positional. An extra local variable is
useful when it explains a step or input.

### Keep diagnostics and rendering out of decisions

A large `?? (throw InvalidGenerationSource(...))` embeds diagnostic prose in the
expression that discovers a value. A named error keeps the failure readable:

```dart
final getter = _findCapabilitiesGetter();

if (getter == null) {
  throw AgentGenerationError.missingCapabilities(_type);
}
```

In this sketch, `AgentGenerationError` owns the diagnostic and its source
location. An obvious fallback such as `accepted ?? false` belongs at its use site.

For rendering, prepare the values before inserting them into generated source:

```dart
final viewCode = _list(views.map(_view));
final toolCode = _list(methods.map(_tool));

return '''
AgentSchema(
  sees: $viewCode,
  calls: $toolCode,
)
''';
```

A reader can inspect the output shape separately from the decisions that produce
it. Simple interpolation can stay inline.

### Follow the responsibility in UI code

In [order_desk_screen.dart](../example/lib/desk/ui/order_desk_screen.dart),
`OrderDeskScreen` composes the Cubit and the scope, and `_OrderDeskView` the
workspace with the chat. `OrderForm` reads the order and renders it.
`OrderSummary` owns what the approval card shows. These widgets give each part a
name a reader can use to skip its detail.

`OrderForm` keeps its empty view next to the filled one. Flutter composition
naturally nests widgets; an extra wrapper earns its place through a cohesive
responsibility, rather than nesting depth alone.

### Give a concept its own type

In [turn.dart](../packages/tandem/lib/src/session/turn.dart), `Turn` holds the
calls of one agent turn and the rules for approving them. `TandemSession` drives
the runs and leaves those rules to `Turn`. When a class gathers conditions about
one concept, that concept is the next type to extract.

## Readability review

Before handoff, review the changed flow separately from correctness. Agent
findings are advisory.

1. Establish the change's scope and intended behavior. Read the diff and the
   surrounding functions, types and direct callers needed to understand it.
2. Apply the principles to the changed flow. Use the relevant generator, UI or
   session example to resolve a tradeoff.
3. Look for inferred meaning, unnecessary jumps, misleading names, repeated
   decisions and misplaced responsibility. Check whether a proposed
   simplification moves the difficulty elsewhere.
4. For each finding, give the file and symbol, reading cost and a proportionate
   suggestion. Account for valid exceptions; an empty result is valid. Keep
   unrelated cleanup outside the change.
5. Resolve justified findings within scope. Run checks appropriate to resulting
   edits and report remaining tradeoffs.

For a read-only review, use this request with an explicit diff or base commit:

> Review `<diff or base commit>` using the readability review in
> `doc/code-quality.md`. Leave files unchanged.

Formatting, analyzer diagnostics and behavior stay with the existing checks in
[AGENTS.md](../AGENTS.md#commands). Readability findings need contextual judgment;
an agent's score is not a merge gate.

## Keep the guidance useful

When feedback repeats, first improve the relevant principle or example. Add a
new rule only for a distinct, durable concern. Keep design sketches sufficient
to explain the decision. Update live examples when their referenced code changes.

Check a guidance change against a known problem, a valid exception and a fresh
change. Compare recurring human corrections and rejected review suggestions
across subsequent changes. A few successful reviews are a local pilot, not proof
of reliability across models or tasks. Recheck after changing the agent or model.

Automate observed, recurring gaps: a lint for precise checks; a wrapper or skill
when running the review becomes cumbersome. Keep this guide as the source of
truth.
