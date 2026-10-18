# RFC 0001: a core without UI, and how it meets state libraries

Status: accepted for pre-v1. Date: 2026-10-18.

## Context

Tandem ships no UI: the chat moved from the package into the example ([#8](https://github.com/leancodepl/tandem/pull/8)). This RFC settles how the core meets a state library, how an app handles approvals and events, and how much the app writes itself. It rests on three prototypes of the order desk demo: today's `tandem_bloc` (v1), Riverpod on today's core (v2), and the core without `tandem_bloc` (v3). The prototypes are not in the repo. Their numbers are below.

The goal: what an app builds on Tandem is limited by its developer, not by Tandem. Before v1, with restraint.

## Decisions

### The package

1. **No UI in the package, as a restraint rather than a rule.** `TandemChat` was too much. A small, deliberate piece may come back when it is worth its cost. For now the README shows an approval dialog to copy, and the example has a chat.
2. **`tandem_bloc` goes away.** The session lifecycle moves into a `TandemScope` in `tandem`: one session per surface, a new one when the agent or the connection changes, disposal before the state object closes.
3. **One state object per screen.**
4. **A conversation ends with its screen**, as it does today.

### The surface

5. **The screen passes its state object as a closure**, as in `TandemScope(surface: (context) => context.read<OrderDeskCubit>(), ...)`. The scope calls it when it opens a session. A provider that swaps the object under the same scope is not handled.
6. **The state class reports its changes.** A class with `@TandemAgent()` has `Stream<Object?> get changes`. For a Cubit it is `stream`. Every such class needs the getter, also in tests.
7. **A snapshot of `.sees` decides.** Each approval request keeps a snapshot of `.sees` from when the agent asked. A change signal means "check now": the request is invalidated when `.sees` differs from its snapshot. A late signal does no harm, and changes outside `.sees` leave the request alone.
8. **Whatever a method with approval depends on is listed with `.sees`.** The doc comment of `.callsWithApproval`, the README and a "Done when" in SKILL.md say so.
9. **The change signal is required.** A request is invalidated while the user looks at it. Finding out only on Approve is not good enough for real apps.

### Approvals

10. **`approvals:` on the scope is required**, so every screen says how it handles approvals:
    - `.callback((context, request, session) async { ... })` for a dialog, a bottom sheet or anything imperative,
    - `.fromState()` when the UI draws requests itself, from `session.items` or from the status,
    - `.none()` for a screen that never asks. A request then reports an error in debug and is refused to the agent.

    The callback gets the session as an argument because the scope's context is above the `TandemSessionScope` it builds.
11. **One request at a time.** When the agent asks for several approvals in one turn, Tandem asks for them in order. An approved method that changes `.sees` invalidates the rest. A rejection cancels the rest, and the agent plans again.
12. **`approve` and `reject` either decide or throw.** The same decision twice does nothing, so a double tap is harmless. A decision that cannot happen, such as approving a rejected or invalidated request, throws an exception that the app can catch. `session.isPending(request)` tells the UI whether a request still waits.

### Events and status

13. **`onEvent: (context, event, session)` on the scope**, with a public sealed `TandemEvent`. It covers what is today a `ChatNotice` or `onAgentCall`: the run failed, the connection was lost, the run was stopped, the agent called a method. `onAgentCall` goes away. A `session.events` stream with the same types can come later without breaking apps.
14. **One status instead of flags.** `session.status` is sealed: `Idle`, `Thinking`, `Calling(tool, approved:)`, `AwaitingApproval(request)`, `Stopping`. It replaces `isRunning`, `isStopping` and `canStop`. Whether Stop is available follows from the status: it is while `Thinking` or `Calling(approved: false)`, and a method the user approved runs to its end.
15. **"The app asked" versus "the user wrote" shows only in logs** for now.

## Lessons from the prototypes

- The core and the generator do not depend on bloc. `@TandemAgent()` works on a Riverpod `Notifier` unchanged.
- Without `tandem_bloc`, the Riverpod app wrote 88 lines of scope and 117 lines of tests. About 60 of the 88 repeat the session lifecycle of `tandem_bloc`. The lifecycle belongs in the core.
- Without `tandem_bloc`, the bloc screen needs about 20 lines of wiring instead of 10. Decision 5 brings it back to one line.
- "Every signal invalidates the card" hid a timing contract: the signal had to arrive before the next event-loop turn. The natural Riverpod adapter (`ref.watch`) broke it, and every card was invalidated as it showed. Decision 7 removes the contract.
- Dart generics cannot tie `surface` to `changes`. `f<S>(Cubit<S> surface, Stream<S> changes)` called with two different state types infers `S = Object` and compiles. Only the shape of the API ties them (decision 6).
- `riverpod_generator` clashes with Tandem: both write `_$ClassName` into the same `.g.dart`.
- `.sees` needs public getters on the state class, and `riverpod_lint` has a rule against public getters on a notifier. This comes from the rule's source; the lint was not run.
- `avoid_context_read_in_build` from leancode_lint (since 26.0.0) flags `context.read` in `build`, also when it only takes a reference to a cubit. A closure that takes a `BuildContext` and returns no widget is exempt, which decision 5 relies on.

## Later, not in pre-v1

- **Several state objects per screen.** Options: a facade class with `@TandemAgent()` as a recipe, `surfaces: [...]` on the scope, a generator that accepts `.calls(_order.setQuantity)`, or registration with a `TandemSurface` widget. Each has to handle clashing method names and a snapshot of every `.sees`.
- **A conversation across screens.** Saving and restoring it, along the lines of [AG-UI serialization](https://docs.ag-ui.com/concepts/serialization). Today a `threadId` never comes back after its session ends, because an orphaned ADK run mixes up the history.
- **`session.events` and a `TandemListener` widget**, for listening below the scope or outside widgets.
