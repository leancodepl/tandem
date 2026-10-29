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
