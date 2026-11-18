## 0.3.3

- The README, `example/example.md` and the skills show how to connect a screen to Firebase AI Logic with `FirebaseConnection` from `tandem_firebase_ai`, without an agent backend. They also name it as a replacement for `OnDeviceAgent`.
- AG-UI `metadata` on text messages, tool calls and backend tool results stays in the conversation history and goes back to the backend with them. Before, Tandem dropped it.
- An event whose `metadata` is not a JSON object fails the run with a `FormatException`.
- A `TEXT_MESSAGE_CONTENT` event with an empty `delta` adds no chat message. Before, the chat showed an empty one.
- After a failed run, the agent's texts go back to the backend in the order their messages started, as after a finished run. Before, they followed the order of their first text.

## 0.3.2

### Connections and history

- `OnDeviceAgent`, `OnDeviceAvailability` and `OnDeviceErrorCode` are deprecated ahead of their removal in 0.4.0. Use an AG-UI backend through `HttpAgentConnection`.
- `HttpAgentConnection(idleTimeout: ...)` sets how long a run waits for response headers or the next bytes, including SSE comments. The default is 60 seconds.
- AG-UI tool results sent as a list of content parts stay in the conversation history and go back to the backend unchanged. Before, Tandem dropped them.
- Each tool answer and each call without a parent message gets its own message ID. Before, reusing a tool call ID in a later run could make the backend skip the second answer.
- A response with no AG-UI events reports that the endpoint returned no events. An event whose JSON is not an object fails with a `FormatException`.

### Values and tool schemas

- Tandem writes local `DateTime` values with their UTC offset and reads date-time arguments as local time. Before, local values went out without an offset, and arguments with an offset or `Z` came back as UTC.
- A `Uri` argument must include a scheme, as its schema promises. Before, a relative URI was accepted.
- A parameter or field with a doc comment keeps its type's instructions in the schema, including converter formats and how to point to an object by path.
- A view property of type `double` rejects a path to an extension type over `int`. Before, a property such as a price could display a value expressed in cents as an ordinary number.
- The inset converters refuse a value that names the same side twice.
- When the agent list cannot encode a `.sees` value, its `StateError` names the getter.
- The agent list throws a `StateError` when an app method's tool name starts with the reserved `tandem_` prefix.
- The `AgentCall.arguments` delivered to `onEvent` are read-only, including nested maps and lists. Before, changing them could change the view action note sent to the agent.

### Drawn views

- A rebuilt `TandemView` keeps the drawn view when it receives another instance of the same catalog class. A different catalog class starts an empty view.
- A required field in a drawn view keeps the latest entry made while another action runs and submits it when that action finishes. Before, those edits were lost.
- When the screen's agent list throws while drawing, the view call answers `failed` and the run continues. A converter that throws unexpectedly gets a separate answer asking the agent to draw without the unreadable value.
- View refusals name the template item's fields, explain list indices and report binding errors even alongside an unknown component. They omit repeated and empty hints and say when the next message will turn drawing back on.
- Before the first view is drawn, screen changes no longer make the view read and encode the agent list. A catalog conflict is reported when a run offers the view tool, once until the conflict changes.

### Coding agents and scripts

- A bridge call returns its method's answer even when another screen's agent list throws. The bridge reports the error through Flutter and includes it on that screen in `ext.tandem.describe`.
- A bridge call with only a known `context` selects the screen it describes. Repeated descriptions reuse the context while that screen shows the same data, and activity on other screens no longer expires it.
- A repeated coding-agent call joins the pending call even when its JSON object keys arrive in a different order.
- In `testing.dart`, `AgentRequest.userText` reads the user's latest text, `offersView` checks whether the run can draw, and `AgentStep.showView` draws the given components. `AgentRequest.newPressedActions` reads each `PressedAction` with its `tool`, `arguments`, typed `ToolStatus status`, and `answer`.
- A `ScriptedAgent` run that calls an unoffered tool ends with `RUN_ERROR` and `ScriptedErrorCode.notOffered`. Before, the call was silently dropped.

### Sessions and package guidance

- A session closed before it sends a message preserves the screen recorded by the last session that sent one. Closing during an approved coding-agent or view call also preserves the in-app agent's thread.
- A session stops dispatching a method if a listener releases its thread during `Calling`. It also stops notifying listeners if `onEvent` disposes it as a run fails to open.
- All `Idle()` instances compare equal and share a hash code, and so do all `Stopping()` instances.
- Runtime-only members of `AgentType`, `AgentView.write`, `AgentView.checked`, `AgentComponent.property` and `ToolArgs.json` are annotated `@internal`. The analyzer warns when an app uses them.
- The README and skills guide apps to an AG-UI backend and show how to script views in the order desk. The coding-agent skill explains how to identify an unreadable screen and how to check whether a method ran before retrying it.
- The API docs explain how converter IDs distinguish configurations, when catalog actions are required, when approvals end and which arguments a call reports.

## 0.3.1

- `TandemThread(id: ThreadId(conversationId))` sends the backend's own conversation ID with every run. A reset, such as `session.startOver()` or a lost connection, keeps it. `ThreadId('')` throws an `ArgumentError`.
- With such an ID, the next run after `session.startOver()` or reopening on a changed screen first sends the calls whose answers have not gone out, with those answers. The `startedOver`, `connectionLost` and `runFailed` notices then no longer mean a new conversation, because the backend may keep it. A thread without an ID works as before: Tandem picks one and replaces it at a reset.
- `request.key` is an `ApprovalKey` for the widget key of an approval card and for data kept per request. Copies from `withStatus()` keep it, and a later request gets a new one even when the backend repeats a `toolCallId`. Key cards by it instead of `toolCallId`.
- `approve`, `reject` and `isPending` match a request by its `key`. For a card from an earlier run whose `toolCallId` the backend reused, or a request built with `ApprovalRequest()`, `approve` and `reject` throw `ApprovalNotPending` unless the request has that status already. Before, they decided the pending call with the same `toolCallId`, if one waited.
- `agUiRun(input)` turns the decoded events of one request into the requested run, for an `AgentConnection` over another transport, such as a WebSocket. It skips replayed runs, expands text and tool-call chunks and closes at the run's end. It fails with a `FormatException` when the run is missing or mixed with another.
- A connection that implements `StoppableAgentConnection` hears about `session.stop()`. The session calls its `stop` once with the run's input, unless the server ended the run already. A `RUN_ERROR` then ends the stopped run quietly, and the session reports its code and message. After a `stop` that threw, a `RUN_ERROR` fails the run.
- When a response ends before the requested `RUN_STARTED`, a run of `HttpAgentConnection` fails with a `FormatException` that names the cause. The session reports it, and the chat shows a lost connection as before. A second `RUN_STARTED` or an event of another thread inside the run fails it the same way. Before, a repeated `RUN_STARTED` or an event of another thread reached the session, and a `RUN_STARTED` of another run dropped the events after it.
- A `RUN_ERROR` with the requested `runId` that comes after replayed runs fails the run with its code. Before, the run ended as a lost connection.
- CI runs the tests of `tandem` in Chrome, compiled to JavaScript and to WebAssembly, and builds the example for the web.
- The README and the `tandem-in-app-agent` skill cover app-supplied thread IDs, `request.key`, other transports with `agUiRun` and `StoppableAgentConnection`, and that the backend must repeat `threadId` and `runId` in `RUN_STARTED`.

## 0.3.0

- **Breaking:** Run `dart run build_runner build` again after upgrading both packages.
- **Breaking:** Hand-written schemas use `AgentType`, `AgentView.of(() => value).as(...)` and `AgentTool(parameters: [AgentParameter(...)])`. Read JSON with `AgentTool.read`; `ToolArgs` now provides typed `read` and `readOr` instead of JSON constructors and collection readers.
- **Breaking:** Mark an object parameter `@TandemInput()` when the agent creates its value; otherwise, list the objects it may choose with `.sees` and pass a path to one of them.
- **Breaking:** Write every `.sees` inside `agentCapabilities` itself and remove `super` from that getter.
- **Breaking:** Handle `Caller.view` in switches over `Caller`.
- **Breaking:** Pass the screen's `context` from `ext.tandem.describe` to `ext.tandem.call` when its arguments contain object paths.
- `@TandemCatalog([...])` and `TandemView(catalog:)` let the in-app agent draw with the app's own widgets through `tandem_show_view`. Bindings follow the current `.sees` data, and components whose required value or action is missing stay hidden until it returns.
- A drawn view's buttons call listed methods with the session's checks and approvals, and fields pass the user's entry to methods that need none. Their answers reach `app_notes` before `onEvent`.
- Views are checked before drawing, with one line per problem and the previous view kept; after three refusals, `tandem_show_view` stays off until the next message. `whenUnavailable` shows when the expanded view exceeds 500 components.
- `Thinking(drawing: true)` reports that the agent is drawing a view.
- `AgentType` shares one description between reading, writing and JSON Schema, including `Uri`, `Set`, token classes and generic classes.
- `@TandemAgent(converters:)` and `@TandemCatalog(converters:)` take `JsonConverter<T, S>`, with built-in converters for colors, insets and alignments. `tandem` depends on `json_annotation` for it.
- Object paths are checked against what the run saw, and approval requests freeze their resolved arguments so the approved method gets what the request showed.
- `.sees` entries can depend on the state or route through `if`, `switch` and spreads, with getters kept distinct even when their values are equal or null.
- A turn that only draws accepted views ends without another model run; its tool answers go with the next message.
- The README and Agent Skills cover app catalogs, object paths, converters, dynamic agent lists and a coding agent's `context`.

## 0.2.3

- `TandemScope(thread:)` goes on with a `TandemThread` that the app keeps: the chat, the history and the agent state. The newest session goes on with it, and an older one refuses calls.
- `session.agentState` follows the backend's `STATE_SNAPSHOT` and `STATE_DELTA`, and every run sends it back as the AG-UI `state`. `tandem` depends on `rfc_6902` for it.
- `session.note(text)` tells the agent on its next run what happened in the app. `session.wake()` starts that run with a `UserMessage` whose `fromApp` lets a chat hide it.
- `AgentCall.caller` and `ApprovalRequest.caller` say who called the method: `Caller.inAppAgent` or `Caller.codingAgent`.
- `Thinking(backendTool:)` names the tool of the agent's backend that runs now, such as `search_catalog`.
- Every run sends back the history as `@ag-ui/client` builds it, so LangGraph no longer reruns a turn and Pydantic AI keeps the results of its own tools.
- The messages sent during a run go with the next run as one message. Before, each had a run of its own.
- `session.startOver()` keeps the messages that never reached the agent and sends them with the next message. Before, it dropped them.
- A run fails before any method runs when the backend reuses a tool call id under another name. Before, the call ran under the new name.
- The first `TOOL_CALL_CHUNK` of a call keeps its `parentMessageId`, as `TOOL_CALL_START` does.
- `TandemBridge` refuses a call without `screen` while several screens are on the current route, such as tabs, and says so. Before, it said that no screen was in front.
- `OnDeviceAgent` fails a run with `OnDeviceErrorCode.unsupportedSchema` when the system rejects a tool's schema, such as a nullable parameter on some iOS 26 versions. Before, Tandem made nullable parameters optional and tried again.
- `ScriptedAgent.repeating` plays one turn on every run, and `AgentRequest` reads a run's request in a script: its context, tools, app notes and tool results.
- `AgentListing.seen` gives the `.sees` values by name, and `AgentListing.parameters(tool)` a method's JSON Schema.
- The README names Claude Code as the coding agent Tandem is checked with and marks `OnDeviceAgent` experimental. It lists what an AG-UI backend must do, with reference agents on Google ADK, LangGraph and Pydantic AI.
- The Agent Skills say which names reach the agent in snake_case, and keep a headless coding agent's wait for approval in one turn.

## 0.2.2

- When the user sends several messages before a run goes out, the agent gets them as one user message, the texts joined by a blank line: ag-ui-adk passes the model only the last new user message of a run. This covers the messages queued during a run that ends with an `interrupt` or an outcome of the wrong shape, and a message whose run failed before it went out, such as when `agentCapabilities` throws.
- When `tandem-coding-agent` starts the app itself, it picks the host's desktop if the project has a folder for it, such as `-d macos` for `macos/` on a Mac, and asks for a device otherwise.

## 0.2.1

- `TandemBridge` lets a coding agent, such as Claude Code or Cursor, drive the screens of a running debug build. `TandemBridge.enable()` in `main()` registers the VM service extensions `ext.tandem.describe` and `ext.tandem.call`; a profile or release build gets none. The coding agent reaches them with the `vm_service` tool of the Dart MCP server, or over HTTP at the VM service address that `flutter run` prints. It sees what the in-app agent sees and calls only the listed methods. `TandemBridge.describe()` and `TandemBridge.call()` give the same JSON in a test.
- A coding agent's call of a `.callsWithApproval` method waits for the user as an `ApprovalRequest` in `session.items`, after the in-app agent's requests. `TandemBridge.enable(autoApprove: true)` runs it at once instead, for automation. `describe` shows the last one with its answer as `lastApproval`, for a coding agent whose client stopped waiting.
- `agent:` of `TandemScope` is optional. Without it, the screen has no in-app agent, and a run of `session.send` fails with a report that says so.
- Three Agent Skills, installed with `dart run skills@ get --package tandem --all`. `tandem-agent-aware-screen` is the base: it lists what the agent sees and calls, without a chat or a backend. `tandem-coding-agent` sets up `TandemBridge` and fills a running screen. `tandem-in-app-agent` adds a chat or a button for the app's users. `dart run skills@ get` shows an update for them only when there is one.
- The `/tandem` skill sets up Tandem in an app: it checks the packages and hands the work to these skills. Install it from the GitHub repository with `dart run skills@ add leancodepl/tandem --skill tandem`.

## 0.2.0

- **Breaking:** `ChatNoticeKind.startedOver`. A `switch` over `ChatNoticeKind` needs a case for it.
- **Breaking:** `AgentRunException.code` is a `RunErrorCode`. Wrap a string with `RunErrorCode(...)` to build one.
- `session.startOver()` sends the next message to a new AG-UI thread, without the earlier history. The chat keeps its items.
- `RunFailed` has the error's `code`, a `RunErrorCode`: any string a backend sends. Tandem's own codes are constants by source: the session's on `RunErrorCode`, `ScriptedAgent`'s on `ScriptedErrorCode`.
- `OnDeviceAgent.apple()` runs Apple's on-device model with the same session, capabilities and approvals. The model proposes calls and Tandem runs them. Its errors are `OnDeviceErrorCode` constants, such as `contextWindowExceeded`.

## 0.1.0

- `@TandemAgent()` and `agentCapabilities`: the agent sees the values a state class lists with `.sees` and calls only the methods it lists with `.calls` and `.callsWithApproval`.
- `TandemScope`: one session of a screen with an AG-UI agent, for any state library. The state class reports its changes in `changes`.
- `HttpAgentConnection` talks to any AG-UI endpoint, with an `http.Client` of your own for headers such as a token. A custom `AgentConnection` can take its place.
- AG-UI 1.0 run outcomes: a run the backend cancels runs none of its calls, and a run that ends with an interrupt fails and the next message starts a new thread. Earlier runs that a response replays are skipped.
- Approvals with `.callback`, `.fromState()` or `.none()`, one request at a time. A request is invalidated when a value listed with `.sees` changes after the agent's run started, also through the agent's own calls.
- `session.status` and `onEvent` for the app's own chat, buttons and messages. Tandem has no chat widget.
- A method refuses a call with a message for the agent by throwing `ToolCallRefused`. Any other error goes only to the app's reports, and the agent hears that the call failed.
- `ScriptedAgent` and `AgentListing` in `package:tandem/testing.dart`, for tests, and to try a screen without a model.
- An Agent Skill for coding agents, installed with `dart run skills@ get`.
