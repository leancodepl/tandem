## 0.2.3

- `TandemView` shows a view the in-app agent draws for the user: texts, columns, rows, lists, cards, dividers and buttons in A2UI v0.9.1. While it is below a `TandemScope`, every run offers the agent the tool `show_view`. The view shows only what the screen lists with `.sees`, and a view that does not fit the screen is refused with what to fix. A button calls one listed method: at once, or after the user approves it as for the agent. When the method ran, the agent gets what it answered with the user's next message. A button is off while its method is not listed, and, for one with approval, while the session is not idle. It needs a strong model behind an AG-UI backend.
- `tandem` depends on `a2ui_core`. A release build of an app without `TandemView` holds none of its code.

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
