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
